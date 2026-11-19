import Cocoa
import Carbon
import SwiftUI

/// Вью захвата нового сочетания клавиш (как в системных настройках macOS)
public struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: ShortcutKey
    var onEndRecording: () -> Void

    public init(shortcut: Binding<ShortcutKey>, onEndRecording: @escaping () -> Void) {
        self._shortcut = shortcut
        self.onEndRecording = onEndRecording
    }

    public func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        assignCallbacks(to: view)
        return view
    }

    public func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        assignCallbacks(to: nsView)
    }

    private func assignCallbacks(to view: ShortcutRecorderNSView) {
        view.onShortcutRecorded = { newShortcut in
            self.shortcut = newShortcut
            self.onEndRecording()
        }
        view.onCancel = {
            self.onEndRecording()
        }
    }
}

public final class ShortcutRecorderNSView: NSView {
    var onShortcutRecorded: ((ShortcutKey) -> Void)?
    var onCancel: (() -> Void)?
    private var localMonitor: Any?
    private var resignKeyObserver: Any?
    private var isSuspendedHotkeys = false
    private var didFinishRecording = false

    public override var acceptsFirstResponder: Bool { true }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let win = window {
            didFinishRecording = false
            suspendGlobalHotkeys(true)
            setupObservers(for: win)
            DispatchQueue.main.async { [weak self] in
                guard let self, let win = self.window else { return }
                win.makeFirstResponder(self)
            }
        } else {
            cleanUp()
        }
    }

    isolated deinit {
        cleanUp()
    }

    public override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned && !didFinishRecording {
            didFinishRecording = true
            cleanUp()
            onCancel?()
        }
        return resigned
    }

    private func setupObservers(for window: NSWindow) {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }
                guard event.window === self.window else { return event }
                if self.handleKeyEvent(event) {
                    return nil
                }
                return event
            }
        }
        if resignKeyObserver == nil {
            resignKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, !self.didFinishRecording else { return }
                    self.didFinishRecording = true
                    self.cleanUp()
                    self.onCancel?()
                }
            }
        }
    }

    private func suspendGlobalHotkeys(_ suspend: Bool) {
        guard isSuspendedHotkeys != suspend else { return }
        isSuspendedHotkeys = suspend
        GlobalHotKeyManager.shared.setSuspended(suspend)
    }

    private func cleanUp() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let observer = resignKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            resignKeyObserver = nil
        }
        suspendGlobalHotkeys(false)
    }

    public override func cancelOperation(_ sender: Any?) {
        guard !didFinishRecording else { return }
        didFinishRecording = true
        cleanUp()
        onCancel?()
    }

    public override func keyDown(with event: NSEvent) {
        if !handleKeyEvent(event) {
            super.keyDown(with: event)
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        var carbonModifiers: UInt32 = 0
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.shift)   { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.option)  { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }

        let keyCode = UInt32(event.keyCode)

        // Одиночный ESC отменяет запись шортката
        if Int(keyCode) == kVK_Escape && carbonModifiers == 0 {
            didFinishRecording = true
            cleanUp()
            onCancel?()
            return true
        }

        let allowsNoModifiers = ShortcutKey.canBeUsedWithoutModifiers(keyCode)
        let hasPrimaryModifier = (carbonModifiers & UInt32(cmdKey | optionKey | controlKey)) != 0

        // С одним Shift разрешаем только клавиши навигации/табуляции, чтобы не ломать ввод текста и Shift+Space/Return
        let isShiftCompatibleNavigationKey: Bool = {
            switch Int(keyCode) {
            case kVK_Tab, kVK_LeftArrow, kVK_RightArrow, kVK_DownArrow, kVK_UpArrow:
                return true
            default:
                return false
            }
        }()

        if !allowsNoModifiers {
            if carbonModifiers == 0 {
                NSSound.beep()
                return true
            }
            if !hasPrimaryModifier && !isShiftCompatibleNavigationKey {
                NSSound.beep()
                return true
            }
        }

        if ShortcutKey.isProtectedSystemShortcut(keyCode: keyCode, modifiers: carbonModifiers) {
            NSSound.beep()
            return true
        }

        let keyLabel = ShortcutKey.keyName(
            for: keyCode,
            fallback: event.charactersIgnoringModifiers ?? ""
        )

        let newShortcut = ShortcutKey(
            keyCode: keyCode,
            keyChar: keyLabel,
            modifiers: carbonModifiers
        )

        didFinishRecording = true
        cleanUp()
        onShortcutRecorded?(newShortcut)
        return true
    }
}
