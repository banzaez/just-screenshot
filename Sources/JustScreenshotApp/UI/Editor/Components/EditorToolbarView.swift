import SwiftUI
import AppKit

/// Верхний тулбар: сгруппированные инструменты, цвет/толщина, масштаб, undo
public struct EditorToolbarView: View {
    @Binding public var selectedTool: AnnotationTool
    @Binding public var selectedColor: Color
    @Binding public var lineWidth: CGFloat
    
    public let zoomPercent: Int
    public let isFitMode: Bool
    public let canUndo: Bool
    public let canRedo: Bool
    public let onUndo: () -> Void
    public let onRedo: () -> Void
    public let onZoomIn: () -> Void
    public let onZoomOut: () -> Void
    public let onFit: () -> Void
    public let onActualSize: () -> Void
    public let onAutoRedact: () -> Void
    
    public init(
        selectedTool: Binding<AnnotationTool>,
        selectedColor: Binding<Color>,
        lineWidth: Binding<CGFloat>,
        zoomPercent: Int,
        isFitMode: Bool,
        canUndo: Bool,
        canRedo: Bool,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onZoomIn: @escaping () -> Void,
        onZoomOut: @escaping () -> Void,
        onFit: @escaping () -> Void,
        onActualSize: @escaping () -> Void,
        onAutoRedact: @escaping () -> Void
    ) {
        self._selectedTool = selectedTool
        self._selectedColor = selectedColor
        self._lineWidth = lineWidth
        self.zoomPercent = zoomPercent
        self.isFitMode = isFitMode
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onZoomIn = onZoomIn
        self.onZoomOut = onZoomOut
        self.onFit = onFit
        self.onActualSize = onActualSize
        self.onAutoRedact = onAutoRedact
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            toolGroup(AnnotationTool.selectGroup)
            toolGroup(AnnotationTool.shapesGroup)
            toolGroup(AnnotationTool.annotateGroup)
            toolGroup(AnnotationTool.redactGroup)
            
            styleCapsule
            
            zoomCapsule
            
            Spacer(minLength: 8)
            
            historyCapsule
        }
    }
    
    // MARK: - Groups
    
    private func toolGroup(_ tools: [AnnotationTool]) -> some View {
        HStack(spacing: 2) {
            ForEach(tools) { tool in
                EditorIconButton(
                    tool.iconName,
                    title: tool.localizedTitle,
                    isActive: selectedTool == tool,
                    width: 34
                ) {
                    selectedTool = tool
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
    
    private var styleCapsule: some View {
        HStack(spacing: 8) {
            ColorDropdown(selection: $selectedColor)
            WidthDropdown(selection: $lineWidth)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
    
    private var zoomCapsule: some View {
        HStack(spacing: 2) {
            EditorIconButton("minus.magnifyingglass", title: L("editor.zoom_out"), width: 32, action: onZoomOut)
            Text("\(zoomPercent)%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44)
            EditorIconButton("plus.magnifyingglass", title: L("editor.zoom_in"), width: 32, action: onZoomIn)
            EditorIconButton(
                "arrow.up.left.and.arrow.down.right",
                title: L("editor.fit_window"),
                isActive: isFitMode,
                width: 32,
                action: onFit
            )
            EditorIconButton("1.magnifyingglass", title: L("editor.actual_size"), width: 32, action: onActualSize)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
    
    private var historyCapsule: some View {
        HStack(spacing: 2) {
            EditorIconButton("eye.slash", title: L("editor.auto_redact"), width: 34, action: onAutoRedact)
            EditorIconButton("arrow.uturn.backward", title: L("editor.undo"), width: 34, action: onUndo)
                .opacity(canUndo ? 1 : 0.35)
                .disabled(!canUndo)
            EditorIconButton("arrow.uturn.forward", title: L("editor.redo"), width: 34, action: onRedo)
                .opacity(canRedo ? 1 : 0.35)
                .disabled(!canRedo)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
