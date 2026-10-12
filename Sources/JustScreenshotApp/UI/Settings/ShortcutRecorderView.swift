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
        view.onShortcutRecorded = { newShortcut in
            self.shortcut = newShortcut
            self.onEndRecording()
        }
        view.onCancel = {
            self.onEndRecording()
        }
        return view
    }
    
    public func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {}
}

public final class ShortcutRecorderNSView: NSView {
    var onShortcutRecorded: ((ShortcutKey) -> Void)?
    var onCancel: (() -> Void)?
    private var localMonitor: Any?
    
    public override var acceptsFirstResponder: Bool { true }
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            setupLocalMonitor()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        } else {
            removeLocalMonitor()
        }
    }
    
    isolated deinit {
        removeLocalMonitor()
    }
    
    private func setupLocalMonitor() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            // Если событие предназначается окну, в котором мы находимся
            guard event.window == self.window else { return event }
            if self.handleKeyEvent(event) {
                return nil // Поглощаем событие
            }
            return event
        }
    }
    
    private func removeLocalMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    public override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
    
    public override func keyDown(with event: NSEvent) {
        if !handleKeyEvent(event) {
            super.keyDown(with: event)
        }
    }
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 { // ESC для отмены записи
            onCancel?()
            return true
        }
        
        // Преобразуем флаги NSEvent.modifierFlags в Carbon modifiers
        var carbonModifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        
        let keyCode = UInt32(event.keyCode)
        
        // Проверяем, является ли клавиша функциональной (F1-F20)
        let isFunctionKey = (keyCode >= UInt32(kVK_F1) && keyCode <= UInt32(kVK_F12)) ||
                            keyCode == UInt32(kVK_F13) || keyCode == UInt32(kVK_F14) ||
                            keyCode == UInt32(kVK_F15) || keyCode == UInt32(kVK_F16) ||
                            keyCode == UInt32(kVK_F17) || keyCode == UInt32(kVK_F18) ||
                            keyCode == UInt32(kVK_F19) || keyCode == UInt32(kVK_F20)
        
        // Если модификаторов нет и это не функциональная клавиша F1-F20 — отклоняем
        if carbonModifiers == 0 && !isFunctionKey {
            NSSound.beep()
            return true
        }
        
        // Проверка защиты системных шорткатов (⌘Q, ⌘W, ⌘H, ⌘Tab, ⌘Space и т.д.)
        if ShortcutKey.isProtectedSystemShortcut(keyCode: keyCode, modifiers: carbonModifiers) {
            NSSound.beep()
            return true
        }
        
        var keyChar = ""
        if isFunctionKey {
            switch keyCode {
            case UInt32(kVK_F1): keyChar = "F1"
            case UInt32(kVK_F2): keyChar = "F2"
            case UInt32(kVK_F3): keyChar = "F3"
            case UInt32(kVK_F4): keyChar = "F4"
            case UInt32(kVK_F5): keyChar = "F5"
            case UInt32(kVK_F6): keyChar = "F6"
            case UInt32(kVK_F7): keyChar = "F7"
            case UInt32(kVK_F8): keyChar = "F8"
            case UInt32(kVK_F9): keyChar = "F9"
            case UInt32(kVK_F10): keyChar = "F10"
            case UInt32(kVK_F11): keyChar = "F11"
            case UInt32(kVK_F12): keyChar = "F12"
            case UInt32(kVK_F13): keyChar = "F13"
            case UInt32(kVK_F14): keyChar = "F14"
            case UInt32(kVK_F15): keyChar = "F15"
            case UInt32(kVK_F16): keyChar = "F16"
            case UInt32(kVK_F17): keyChar = "F17"
            case UInt32(kVK_F18): keyChar = "F18"
            case UInt32(kVK_F19): keyChar = "F19"
            case UInt32(kVK_F20): keyChar = "F20"
            default: keyChar = "F"
            }
        } else {
            let chars = event.charactersIgnoringModifiers ?? ""
            keyChar = chars.isEmpty ? "?" : chars
        }
        
        let newShortcut = ShortcutKey(
            keyCode: keyCode,
            keyChar: keyChar,
            modifiers: carbonModifiers
        )
        
        onShortcutRecorded?(newShortcut)
        return true
    }
}
