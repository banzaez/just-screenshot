import SwiftUI
import AppKit

/// Единый keyDown-монитор: Delete / Escape / шорткаты инструментов (когда фокус не в текстовом поле)
public struct EditorKeyHandlerModifier: ViewModifier {
    let onDelete: () -> Void
    let onEscape: (() -> Void)?
    let onSelectTool: ((AnnotationTool) -> Void)?
    
    @State private var monitor: Any?
    
    public init(
        onDelete: @escaping () -> Void,
        onEscape: (() -> Void)? = nil,
        onSelectTool: ((AnnotationTool) -> Void)? = nil
    ) {
        self.onDelete = onDelete
        self.onEscape = onEscape
        self.onSelectTool = onSelectTool
    }
    
    public func body(content: Content) -> some View {
        content
            .onAppear { setupMonitor() }
            .onDisappear { removeMonitor() }
    }
    
    private func setupMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let keyWin = NSApp.keyWindow, event.window === keyWin else {
                return event
            }
            
            if let responder = event.window?.firstResponder {
                if responder is NSText || responder is NSTextView || responder is NSTextField {
                    return event
                }
            }
            
            // Не перехватываем, если есть Cmd/Ctrl (кроме чистых tool keys без модификаторов)
            let mods = event.modifierFlags.intersection([.command, .control, .option])
            
            let isDeleteKey = event.keyCode == 51 || event.keyCode == 117
            if isDeleteKey && mods.isEmpty {
                DispatchQueue.main.async { onDelete() }
                return nil
            }
            
            if event.keyCode == 53, let onEscape {
                DispatchQueue.main.async { onEscape() }
                return nil
            }
            
            if mods.isEmpty, let onSelectTool, let chars = event.charactersIgnoringModifiers?.lowercased(), let tool = Self.tool(for: chars) {
                DispatchQueue.main.async { onSelectTool(tool) }
                return nil
            }
            
            return event
        }
    }
    
    private static func tool(for chars: String) -> AnnotationTool? {
        switch chars {
        case "v": return .select
        case "a": return .arrow
        case "r": return .rectangle
        case "u": return .roundedRect
        case "o": return .ellipse
        case "t": return .text
        case "c": return .counter
        case "b": return .blur
        case "h": return .highlighter
        case "m": return .magnifier
        default: return nil
        }
    }
    
    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

public extension View {
    func editorKeyHandler(
        onDelete: @escaping () -> Void,
        onEscape: (() -> Void)? = nil,
        onSelectTool: ((AnnotationTool) -> Void)? = nil
    ) -> some View {
        modifier(EditorKeyHandlerModifier(onDelete: onDelete, onEscape: onEscape, onSelectTool: onSelectTool))
    }
    
    @available(*, deprecated, renamed: "editorKeyHandler")
    func onEditorDeleteKey(onDelete: @escaping () -> Void, onEscape: (() -> Void)? = nil) -> some View {
        editorKeyHandler(onDelete: onDelete, onEscape: onEscape)
    }
}
