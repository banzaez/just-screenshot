import SwiftUI
import AppKit

/// Модификатор для безопасного отслеживания нажатия клавиш Delete (Backspace / Forward Delete) и Escape
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
            // Срабатывает только для текущего активного ключевого окна
            guard let keyWin = NSApp.keyWindow, event.window === keyWin else {
                return event
            }
            
            // Не перехватываем ввод, если фокус находится в текстовом поле или редакторе текста
            if let responder = event.window?.firstResponder {
                if responder is NSText || responder is NSTextView || responder is NSTextField {
                    return event
                }
            }
            
            // Проверяем клавишу Delete (Backspace: 51, Forward Delete: 117)
            let isDeleteKey = event.keyCode == 51 || event.keyCode == 117
            if isDeleteKey {
                DispatchQueue.main.async {
                    onDelete()
                }
                return nil // Поглощаем событие, чтобы система не издавала системный "бип"
            }
            
            // Escape (keyCode 53)
            if event.keyCode == 53, let onEscape = onEscape {
                DispatchQueue.main.async {
                    onEscape()
                }
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
