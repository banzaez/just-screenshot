import SwiftUI
import AppKit

/// Класс для надежного отслеживания нажатия клавиш (включая Delete / Backspace, Escape, Cmd+Z, Cmd+D)
public struct KeyDownHandlerModifier: ViewModifier {
    let onDelete: () -> Void
    let onEscape: (() -> Void)?
    
    @State private var monitor: Any?
    
    public init(onDelete: @escaping () -> Void, onEscape: (() -> Void)? = nil) {
        self.onDelete = onDelete
        self.onEscape = onEscape
    }
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                setupMonitor()
            }
            .onDisappear {
                removeMonitor()
            }
    }
    
    private func setupMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Не перехватываем ввод, если фокус находится в текстовом поле (NSTextView / NSTextField)
            if let responder = event.window?.firstResponder, responder is NSText || responder is NSTextView || responder is NSTextField {
                return event
            }
            
            // Проверяем клавишу Delete (Backspace - 51) или Forward Delete (117)
            let isDeleteKey = event.keyCode == 51 || event.keyCode == 117
            if isDeleteKey {
                onDelete()
                return nil // Поглощаем событие
            }
            
            // Escape (keyCode 53)
            if event.keyCode == 53, let onEscape = onEscape {
                onEscape()
                return nil
            }
            
            return event
        }
    }
    
    private func removeMonitor() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

public extension View {
    func onEditorDeleteKey(onDelete: @escaping () -> Void, onEscape: (() -> Void)? = nil) -> some View {
        modifier(KeyDownHandlerModifier(onDelete: onDelete, onEscape: onEscape))
    }
}
