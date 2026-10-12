import Cocoa
import Carbon

/// Глобальный менеджер горячих клавиш (Carbon Events API)
/// Работает системно даже когда приложение в фоне / менюбаре
public final class GlobalHotKeyManager: @unchecked Sendable {
    public static let shared = GlobalHotKeyManager()
    
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    
    private init() {
        installCarbonEventHandler()
    }
    
    deinit {
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
    }
    
    /// Регистрация глобального сочетания клавиш
    /// - Parameters:
    ///   - id: Уникальный ID шортката
    ///   - keyCode: Виртуальный код клавиши (Carbon keyCode, например kVK_ANSI_4 = 0x15)
    ///   - modifiers: Модификаторы (cmdKey, shiftKey, optionKey, controlKey)
    ///   - action: Замыкание, вызываемое при нажатии
    public func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        handlers[id] = action
        
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
    
    private func installCarbonEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handlerCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
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
                Task { @MainActor in
                    GlobalHotKeyManager.shared.handlers[hotKeyID.id]?()
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
