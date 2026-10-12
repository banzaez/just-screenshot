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
    
    public override var acceptsFirstResponder: Bool { true }
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC для отмены записи
            onCancel?()
            return
        }
        
        // Преобразуем флаги NSEvent.modifierFlags в Carbon modifiers
        var carbonModifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        
        let keyCode = UInt32(event.keyCode)
        
        // Проверяем, является ли клавиша функциональной (F1-F12)
        let isFunctionKey = (keyCode >= UInt32(kVK_F1) && keyCode <= UInt32(kVK_F12)) ||
                            keyCode == UInt32(kVK_F13) || keyCode == UInt32(kVK_F14) ||
                            keyCode == UInt32(kVK_F15) || keyCode == UInt32(kVK_F16)
        
        // Если модификаторов нет и это не функциональная клавиша F1-F12 — отклоняем
        if carbonModifiers == 0 && !isFunctionKey {
            NSSound.beep()
            return
        }
        
        // Проверка защиты системных шорткатов (⌘Q, ⌘W, ⌘H, ⌘Tab, ⌘Space и т.д.)
        if ShortcutKey.isProtectedSystemShortcut(keyCode: keyCode, modifiers: carbonModifiers) {
            NSSound.beep()
            return
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
    }
}
