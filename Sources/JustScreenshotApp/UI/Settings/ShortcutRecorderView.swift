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
        if event.keyCode == 53 { // ESC
            onCancel?()
            return
        }
        
        // Преобразуем флаги NSEvent.modifierFlags в Carbon modifiers
        var carbonModifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        
        // Если модификаторов нет, требуем хотя бы один (например Command или Control)
        if carbonModifiers == 0 {
            NSSound.beep()
            return
        }
        
        let chars = event.charactersIgnoringModifiers ?? ""
        let keyChar = chars.isEmpty ? "?" : chars
        let newShortcut = ShortcutKey(
            keyCode: UInt32(event.keyCode),
            keyChar: keyChar,
            modifiers: carbonModifiers
        )
        
        onShortcutRecorded?(newShortcut)
    }
}
