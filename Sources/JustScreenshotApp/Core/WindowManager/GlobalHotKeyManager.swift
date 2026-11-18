import Cocoa
import Carbon
import ApplicationServices

/// Глобальный менеджер горячих клавиш.
/// При наличии разрешения Accessibility использует CGEventTap (`.cghidEventTap`, `.headInsertEventTap`),
/// что позволяет перехватывать даже системные сочетания (⌘⇧3, ⌘⇧4, ⌘⇧5) до их обработки macOS.
/// Без Accessibility автоматически работает через Carbon Events API (`RegisterEventHotKey`).
@MainActor
public final class GlobalHotKeyManager {
    public static let shared = GlobalHotKeyManager()

    private struct HotKeyCombo: Hashable, Sendable {
        let keyCode: UInt32
        let modifiers: UInt32
    }

    private final class TapState: @unchecked Sendable {
        private let lock = NSLock()
        private var comboToID: [HotKeyCombo: UInt32] = [:]
        private var eventTap: CFMachPort?
        private var runLoopSource: CFRunLoopSource?

        var isTapActive: Bool {
            lock.lock()
            defer { lock.unlock() }
            return eventTap != nil
        }

        func setTap(_ tap: CFMachPort, source: CFRunLoopSource) {
            lock.lock()
            eventTap = tap
            runLoopSource = source
            lock.unlock()
        }

        func clearTap() -> (CFMachPort?, CFRunLoopSource?) {
            lock.lock()
            let tap = eventTap
            let source = runLoopSource
            eventTap = nil
            runLoopSource = nil
            lock.unlock()
            return (tap, source)
        }

        func currentTap() -> CFMachPort? {
            lock.lock()
            defer { lock.unlock() }
            return eventTap
        }

        func updateCombos(_ map: [HotKeyCombo: UInt32]) {
            lock.lock()
            comboToID = map
            lock.unlock()
        }

        func hotKeyID(for combo: HotKeyCombo) -> UInt32? {
            lock.lock()
            defer { lock.unlock() }
            return comboToID[combo]
        }
    }

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var registeredConfigs: [UInt32: HotKeyCombo] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private let tapState = TapState()

    private init() {
        installCarbonEventHandler()
        _ = ensureEventTapIfTrusted()
    }

    isolated deinit {
        let (tap, source) = tapState.clearTap()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
    }

    /// Пытается активировать CGEventTap, если выдано разрешение Accessibility.
    /// При успешной активации отключает Carbon-регистрацию, чтобы избежать дублирования и системных конфликтов.
    @discardableResult
    public func ensureEventTapIfTrusted() -> Bool {
        if tapState.isTapActive {
            return true
        }
        guard AXIsProcessTrusted() else {
            return false
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(tapState).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let state = Unmanaged<TapState>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = state.currentTap() {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
            let modifiers = GlobalHotKeyManager.carbonModifiers(from: event.flags)
            let combo = HotKeyCombo(keyCode: keyCode, modifiers: modifiers)

            guard let hotKeyID = state.hotKeyID(for: combo) else {
                return Unmanaged.passUnretained(event)
            }

            let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !isAutorepeat {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        GlobalHotKeyManager.shared.handlers[hotKeyID]?()
                    }
                }
            }

            // Поглощаем событие, чтобы macOS не запускала системный скриншотер
            return nil
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: userInfo
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        tapState.setTap(tap, source: source)

        // Переходим на перехват через Event Tap — снимаем Carbon-хоткеи
        unregisterCarbonHotKeys()
        return true
    }

    /// Регистрация глобального сочетания клавиш
    /// - Parameters:
    ///   - id: Уникальный ID шортката
    ///   - keyCode: Виртуальный код клавиши (Carbon keyCode, например kVK_ANSI_4 = 0x15)
    ///   - modifiers: Модификаторы (cmdKey, shiftKey, optionKey, controlKey)
    ///   - action: Замыкание, вызываемое при нажатии
    public func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        _ = ensureEventTapIfTrusted()

        let normalizedModifiers = Self.normalizedCarbonModifiers(modifiers)
        registeredConfigs[id] = HotKeyCombo(keyCode: keyCode, modifiers: normalizedModifiers)
        handlers[id] = action
        syncTapCombos()

        if !tapState.isTapActive {
            registerCarbonHotKey(id: id, keyCode: keyCode, modifiers: normalizedModifiers)
        }
    }

    public func unregisterAll() {
        unregisterCarbonHotKeys()
        registeredConfigs.removeAll()
        handlers.removeAll()
        syncTapCombos()
    }

    private func syncTapCombos() {
        var map: [HotKeyCombo: UInt32] = [:]
        for (id, combo) in registeredConfigs {
            // При совпадении комбинации сохраняем детерминированный приоритет по меньшему id
            if let existingID = map[combo] {
                map[combo] = min(existingID, id)
            } else {
                map[combo] = id
            }
        }
        tapState.updateCombos(map)
    }

    private func registerCarbonHotKey(id: UInt32, keyCode: UInt32, modifiers: UInt32) {
        if let existingRef = hotKeyRefs.removeValue(forKey: id) {
            UnregisterEventHotKey(existingRef)
        }

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C4E53) // 'CLNS'
        hotKeyID.id = id

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs[id] = ref
        } else {
            print("Failed to register hotkey id \(id), status: \(status)")
        }
    }

    private func unregisterCarbonHotKeys() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }

    nonisolated private static func normalizedCarbonModifiers(_ modifiers: UInt32) -> UInt32 {
        modifiers & UInt32(cmdKey | shiftKey | optionKey | controlKey)
    }

    nonisolated private static func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.maskCommand) { result |= UInt32(cmdKey) }
        if flags.contains(.maskShift) { result |= UInt32(shiftKey) }
        if flags.contains(.maskAlternate) { result |= UInt32(optionKey) }
        if flags.contains(.maskControl) { result |= UInt32(controlKey) }
        return result
    }

    private func installCarbonEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerCallback: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event = event else { return OSStatus(eventNotHandledErr) }

            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if err == noErr {
                let hotKeyNumber = hotKeyID.id
                // Выходим из Carbon-обработчика и ставим действие в очередь главного потока
                // с приоритетом UI. Task { @MainActor } отсюда легко опаздывает на несколько кадров.
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        GlobalHotKeyManager.shared.handlers[hotKeyNumber]?()
                    }
                }
                return noErr
            }
            return OSStatus(eventNotHandledErr)
        }

        InstallEventHandler(
            GetEventDispatcherTarget(),
            handlerCallback,
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }
}
