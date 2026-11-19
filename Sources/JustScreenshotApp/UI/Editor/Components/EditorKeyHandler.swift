import SwiftUI
import AppKit
import Carbon

/// Единый keyDown-монитор: Delete / Escape / физические шорткаты инструментов, привязанный строго к окну владельца
public struct EditorKeyHandlerModifier: ViewModifier {
    let onDelete: () -> Void
    let onEscape: (() -> Bool)?
    let onSelectTool: ((AnnotationTool) -> Void)?
    let onCopy: (() -> Void)?

    @State private var monitor: Any?
    @State private var ownerWindow: NSWindow?

    public init(
        onDelete: @escaping () -> Void,
        onEscape: (() -> Bool)? = nil,
        onSelectTool: ((AnnotationTool) -> Void)? = nil,
        onCopy: (() -> Void)? = nil
    ) {
        self.onDelete = onDelete
        self.onEscape = onEscape
        self.onSelectTool = onSelectTool
        self.onCopy = onCopy
    }

    public func body(content: Content) -> some View {
        content
            .background(WindowCaptureView(ownerWindow: $ownerWindow))
            .onAppear { setupMonitor() }
            .onDisappear { removeMonitor() }
    }

    private func setupMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let owner = ownerWindow,
                  event.window === owner,
                  NSApp.keyWindow === owner,
                  owner.attachedSheet == nil else {
                return event
            }

            if let responder = owner.firstResponder,
               responder is NSText || responder is NSTextView || responder is NSTextField {
                return event
            }

            let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])

            let isDeleteKey = Int(event.keyCode) == kVK_Delete || Int(event.keyCode) == kVK_ForwardDelete
            if isDeleteKey && mods.isEmpty {
                DispatchQueue.main.async { onDelete() }
                return nil
            }

            if Int(event.keyCode) == kVK_Escape && mods.isEmpty, let onEscape {
                let handled = MainActor.assumeIsolated { onEscape() }
                return handled ? nil : event
            }

            if mods == .command, let onCopy, Int(event.keyCode) == kVK_ANSI_C {
                DispatchQueue.main.async { onCopy() }
                return nil
            }

            if mods.isEmpty, let onSelectTool, let tool = Self.tool(for: Int(event.keyCode)) {
                DispatchQueue.main.async { onSelectTool(tool) }
                return nil
            }

            return event
        }
    }

    private static func tool(for keyCode: Int) -> AnnotationTool? {
        switch keyCode {
        case kVK_ANSI_V: return .select
        case kVK_ANSI_A: return .arrow
        case kVK_ANSI_R: return .rectangle
        case kVK_ANSI_U: return .roundedRect
        case kVK_ANSI_O: return .ellipse
        case kVK_ANSI_T: return .text
        case kVK_ANSI_C: return .counter
        case kVK_ANSI_B: return .blur
        case kVK_ANSI_H: return .highlighter
        case kVK_ANSI_M: return .magnifier
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

private struct WindowCaptureView: NSViewRepresentable {
    @Binding var ownerWindow: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window, ownerWindow !== window {
                ownerWindow = window
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window, ownerWindow !== window {
            DispatchQueue.main.async {
                self.ownerWindow = window
            }
        }
    }
}

public extension View {
    func editorKeyHandler(
        onDelete: @escaping () -> Void,
        onEscape: (() -> Bool)? = nil,
        onSelectTool: ((AnnotationTool) -> Void)? = nil,
        onCopy: (() -> Void)? = nil
    ) -> some View {
        modifier(EditorKeyHandlerModifier(
            onDelete: onDelete,
            onEscape: onEscape,
            onSelectTool: onSelectTool,
            onCopy: onCopy
        ))
    }
}
