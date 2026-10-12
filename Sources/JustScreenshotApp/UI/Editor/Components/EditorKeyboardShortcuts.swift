import SwiftUI

/// Модификатор скрытых горячих клавиш редактора аннотаций
struct EditorKeyboardShortcutsModifier: ViewModifier {
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onDeselect: () -> Void
    let onFit: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    Button("") { onUndo() }.keyboardShortcut("z", modifiers: [.command])
                    Button("") { onRedo() }.keyboardShortcut("z", modifiers: [.command, .shift])
                    Button("") { onDuplicate() }.keyboardShortcut("d", modifiers: [.command])
                    Button("") { onDelete() }.keyboardShortcut(.delete, modifiers: [])
                    Button("") { onDelete() }.keyboardShortcut(.delete, modifiers: [.command])
                    Button("") { onDeselect() }.keyboardShortcut(.escape, modifiers: [])
                    Button("") { onFit() }.keyboardShortcut("0", modifiers: [.command])
                    Button("") { onZoomIn() }.keyboardShortcut("=", modifiers: [.command])
                    Button("") { onZoomOut() }.keyboardShortcut("-", modifiers: [.command])
                }
                .opacity(0)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            )
    }
}

extension View {
    func editorKeyboardShortcuts(
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onDuplicate: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDeselect: @escaping () -> Void,
        onFit: @escaping () -> Void,
        onZoomIn: @escaping () -> Void,
        onZoomOut: @escaping () -> Void
    ) -> some View {
        modifier(EditorKeyboardShortcutsModifier(
            onUndo: onUndo,
            onRedo: onRedo,
            onDuplicate: onDuplicate,
            onDelete: onDelete,
            onDeselect: onDeselect,
            onFit: onFit,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut
        ))
    }
}
