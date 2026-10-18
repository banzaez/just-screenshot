import SwiftUI
import AppKit

/// Контекстная панель выбранного элемента (с фиксированной высотой, чтобы не прыгал холст)
public struct EditorSelectedItemBar: View {
    public let item: AnnotationItem?
    public let focusTextField: Bool
    public let onTextChange: (String) -> Void
    public let onFontSizeChange: (CGFloat) -> Void
    public let onLineWidthChange: (CGFloat) -> Void
    public let onCounterChange: (Int) -> Void
    public let onSetAngle: (Double) -> Void
    public let onColorChange: (Color) -> Void
    public let onScaleChange: (Double) -> Void
    public let onDuplicate: () -> Void
    public let onDelete: () -> Void
    public let onDeselect: () -> Void
    public let onTextFocusConsumed: () -> Void
    
    @FocusState private var textFocused: Bool
    
    public init(
        item: AnnotationItem?,
        focusTextField: Bool = false,
        onTextChange: @escaping (String) -> Void,
        onFontSizeChange: @escaping (CGFloat) -> Void,
        onLineWidthChange: @escaping (CGFloat) -> Void,
        onCounterChange: @escaping (Int) -> Void,
        onSetAngle: @escaping (Double) -> Void,
        onColorChange: @escaping (Color) -> Void,
        onScaleChange: @escaping (Double) -> Void = { _ in },
        onDuplicate: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDeselect: @escaping () -> Void,
        onTextFocusConsumed: @escaping () -> Void = {}
    ) {
        self.item = item
        self.focusTextField = focusTextField
        self.onTextChange = onTextChange
        self.onFontSizeChange = onFontSizeChange
        self.onLineWidthChange = onLineWidthChange
        self.onCounterChange = onCounterChange
        self.onSetAngle = onSetAngle
        self.onColorChange = onColorChange
        self.onScaleChange = onScaleChange
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
        self.onDeselect = onDeselect
        self.onTextFocusConsumed = onTextFocusConsumed
    }
    
    public var body: some View {
        SelectedAnnotationBarControls.BarChrome(isActive: item != nil) {
            if let item = item {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        SelectedAnnotationBarControls.TitleLabel(
                            title: item.tool.localizedTitle,
                            systemImage: item.tool.iconName
                        )
                        
                        Divider().frame(height: 20)
                        
                        if item.tool == .text {
                            TextField(L("editor.selected.text_field"), text: Binding(get: { item.text }, set: { onTextChange($0) }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                                .focused($textFocused)
                            SelectedAnnotationBarControls.FontSizeControls(
                                fontSize: item.fontSize,
                                onSmaller: { onFontSizeChange(max(10, item.fontSize - 2)) },
                                onLarger: { onFontSizeChange(min(96, item.fontSize + 2)) }
                            )
                        }
                        
                        if item.tool == .counter {
                            EditorIconButton("minus", title: L("editor.selected.num_minus")) { onCounterChange(max(1, item.counterNumber - 1)) }
                            Text("№ \(item.counterNumber)").font(.callout.monospacedDigit()).frame(width: 44)
                            EditorIconButton("plus", title: L("editor.selected.num_plus")) { onCounterChange(item.counterNumber + 1) }
                        }
                        
                        if item.tool == .magnifier {
                            Text(L("editor.selected.zoom"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(
                                value: Binding(
                                    get: { item.scaleFactor > 0 ? item.scaleFactor : 2.0 },
                                    set: { onScaleChange($0) }
                                ),
                                in: 1.5...4.0,
                                step: 0.5
                            )
                            .frame(width: 110)
                            Text(String(format: "%.1g×", item.scaleFactor > 0 ? item.scaleFactor : 2.0))
                                .font(.callout.monospacedDigit())
                                .frame(width: 36)
                        }
                        
                        if item.tool != .blur && item.tool != .magnifier {
                            ColorDropdown(selection: Binding(get: { item.color }, set: { onColorChange($0) }))
                        }
                        
                        if item.tool != .text && item.tool != .counter && item.tool != .blur && item.tool != .magnifier {
                            WidthDropdown(selection: Binding(get: { item.lineWidth }, set: { onLineWidthChange($0) }))
                        }
                        
                        if item.supportsRotation {
                            Divider().frame(height: 20)
                            SelectedAnnotationBarControls.RotationControls(
                                angle: item.displayAngle,
                                onSetAngle: onSetAngle
                            )
                        }
                        
                        Divider().frame(height: 20)
                        
                        SelectedAnnotationBarControls.ActionButtons(
                            onDuplicate: onDuplicate,
                            onDelete: onDelete,
                            onDeselect: onDeselect
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
            } else {
                SelectedAnnotationBarControls.EmptyHint(showShortcuts: true)
            }
        }
        .onChange(of: focusTextField) { _, needsFocus in
            guard needsFocus, item?.tool == .text else { return }
            textFocused = true
            onTextFocusConsumed()
        }
        .onChange(of: item?.id) { _, _ in
            if focusTextField, item?.tool == .text {
                textFocused = true
                onTextFocusConsumed()
            }
        }
    }
}
