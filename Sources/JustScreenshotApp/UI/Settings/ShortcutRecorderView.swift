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
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Преобразуем флаги NSEvent.modifierFlags в Carbon modifiers
        var carbonModifiers: UInt32 = 0
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.shift)   { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.option)  { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        
        let keyCode = UInt32(event.keyCode)
        
        // Одиночный ESC (без модификаторов) отменяет запись шортката
        if Int(keyCode) == kVK_Escape && carbonModifiers == 0 {
            onCancel?()
            return true
        }
        
        let allowsNoModifiers = ShortcutKey.canBeUsedWithoutModifiers(keyCode)
        let hasPrimaryModifier = (carbonModifiers & UInt32(cmdKey | optionKey | controlKey)) != 0
        
        // Специальные клавиши (Space, Return, Tab, Delete, стрелки) можно сочетать даже с одним Shift,
        // а обычные буквы и цифры требуют хотя бы ⌘, ⌥ или ⌃ (чтобы не сломать обычный ввод заглавных букв)
        let isSpecialNavigationOrActionKey: Bool = {
            switch Int(keyCode) {
            case kVK_Space, kVK_Return, kVK_Tab, kVK_Delete,
                 kVK_LeftArrow, kVK_RightArrow, kVK_DownArrow, kVK_UpArrow,
                 kVK_ISO_Section, kVK_ANSI_Grave:
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
            if !hasPrimaryModifier && !isSpecialNavigationOrActionKey {
                NSSound.beep()
                return true
            }
        }
        
        // Проверка защиты системных шорткатов (⌘Q, ⌘W, ⌘H, ⌘Tab, ⌘Space, ⌘⌥Esc)
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
        
        onShortcutRecorded?(newShortcut)
        return true
    }
}
