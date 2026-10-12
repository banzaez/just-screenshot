import SwiftUI
import AppKit

/// Верхний тулбар: инструменты, цвет и толщина (выпадающие списки), масштаб, отмена
public struct EditorToolbarView: View {
    @Binding public var selectedTool: AnnotationTool
    @Binding public var selectedColor: Color
    @Binding public var lineWidth: CGFloat
    @Binding public var textInputString: String
    
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
    
    public init(
        selectedTool: Binding<AnnotationTool>,
        selectedColor: Binding<Color>,
        lineWidth: Binding<CGFloat>,
        textInputString: Binding<String>,
        zoomPercent: Int,
        isFitMode: Bool,
        canUndo: Bool,
        canRedo: Bool,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onZoomIn: @escaping () -> Void,
        onZoomOut: @escaping () -> Void,
        onFit: @escaping () -> Void,
        onActualSize: @escaping () -> Void
    ) {
        self._selectedTool = selectedTool
        self._selectedColor = selectedColor
        self._lineWidth = lineWidth
        self._textInputString = textInputString
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
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(AnnotationTool.allCases) { tool in
                    EditorIconButton(tool.iconName, title: tool.rawValue, isActive: selectedTool == tool) {
                        selectedTool = tool
                    }
                }
            }
            
            if selectedTool == .text {
                TextField("Текст заметки", text: $textInputString)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }
            
            Divider().frame(height: 24)
            
            ColorDropdown(selection: $selectedColor)
            WidthDropdown(selection: $lineWidth)
            
            Divider().frame(height: 24)
            
            HStack(spacing: 4) {
                EditorIconButton("minus.magnifyingglass", title: "Уменьшить", action: onZoomOut)
                Text("\(zoomPercent)%")
                    .font(.callout.monospacedDigit())
                    .frame(width: 46)
                EditorIconButton("plus.magnifyingglass", title: "Увеличить", action: onZoomIn)
                EditorIconButton("arrow.up.left.and.arrow.down.right", title: "Вписать в окно (авто)", isActive: isFitMode, action: onFit)
                EditorIconButton("1.magnifyingglass", title: "100% (1:1)", action: onActualSize)
            }
            
            Spacer(minLength: 8)
            
            HStack(spacing: 4) {
                EditorIconButton("arrow.uturn.backward", title: "Отменить (⌘Z)", action: onUndo)
                    .opacity(canUndo ? 1 : 0.35).disabled(!canUndo)
                EditorIconButton("arrow.uturn.forward", title: "Повторить (⇧⌘Z)", action: onRedo)
                    .opacity(canRedo ? 1 : 0.35).disabled(!canRedo)
            }
        }
    }
}
