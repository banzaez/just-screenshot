import SwiftUI
import AppKit

/// Контекстная панель выбранного элемента (с фиксированной высотой, чтобы не прыгал холст)
public struct EditorSelectedItemBar: View {
    public let item: AnnotationItem?
    public let onTextChange: (String) -> Void
    public let onFontSizeChange: (CGFloat) -> Void
    public let onLineWidthChange: (CGFloat) -> Void
    public let onCounterChange: (Int) -> Void
    public let onSetAngle: (Double) -> Void
    public let onColorChange: (Color) -> Void
    public let onDuplicate: () -> Void
    public let onDelete: () -> Void
    public let onDeselect: () -> Void
    
    public init(
        item: AnnotationItem?,
        onTextChange: @escaping (String) -> Void,
        onFontSizeChange: @escaping (CGFloat) -> Void,
        onLineWidthChange: @escaping (CGFloat) -> Void,
        onCounterChange: @escaping (Int) -> Void,
        onSetAngle: @escaping (Double) -> Void,
        onColorChange: @escaping (Color) -> Void,
        onDuplicate: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDeselect: @escaping () -> Void
    ) {
        self.item = item
        self.onTextChange = onTextChange
        self.onFontSizeChange = onFontSizeChange
        self.onLineWidthChange = onLineWidthChange
        self.onCounterChange = onCounterChange
        self.onSetAngle = onSetAngle
        self.onColorChange = onColorChange
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
        self.onDeselect = onDeselect
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            if let item = item {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Label(item.tool.localizedTitle, systemImage: item.tool.iconName)
                            .font(.callout.bold())
                            .foregroundStyle(Color.accentColor)
                        
                        Divider().frame(height: 20)
                        
                        if item.tool == .text {
                            TextField(L("editor.selected.text_field"), text: Binding(get: { item.text }, set: { onTextChange($0) }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                            EditorIconButton("textformat.size.smaller", title: L("editor.selected.font_smaller")) { onFontSizeChange(max(10, item.fontSize - 2)) }
                            Text("\(Int(item.fontSize))").font(.callout.monospacedDigit()).frame(width: 28)
                            EditorIconButton("textformat.size.larger", title: L("editor.selected.font_larger")) { onFontSizeChange(min(96, item.fontSize + 2)) }
                        }
                        
                        if item.tool == .counter {
                            EditorIconButton("minus", title: L("editor.selected.num_minus")) { onCounterChange(max(1, item.counterNumber - 1)) }
                            Text("№ \(item.counterNumber)").font(.callout.monospacedDigit()).frame(width: 44)
                            EditorIconButton("plus", title: L("editor.selected.num_plus")) { onCounterChange(item.counterNumber + 1) }
                        }
                        
                        ColorDropdown(selection: Binding(get: { item.color }, set: { onColorChange($0) }))
                        
                        if item.tool != .text && item.tool != .counter {
                            WidthDropdown(selection: Binding(get: { item.lineWidth }, set: { onLineWidthChange($0) }))
                        }
                        
                        Divider().frame(height: 20)
                        
                        if item.tool != .counter {
                            EditorIconButton("rotate.left", title: L("editor.selected.rotate_left")) { onSetAngle(item.displayAngle - 15) }
                            Slider(value: Binding(get: { item.displayAngle }, set: { onSetAngle($0) }), in: -180...180)
                                .frame(width: 110)
                            EditorIconButton("rotate.right", title: L("editor.selected.rotate_right")) { onSetAngle(item.displayAngle + 15) }
                            Text("\(Int(item.displayAngle.rounded()))°").font(.callout.monospacedDigit()).frame(width: 40)
                            EditorIconButton("arrow.counterclockwise", title: L("editor.selected.reset_angle")) { onSetAngle(0) }
                        }
                        
                        Divider().frame(height: 20)
                        
                        EditorIconButton("plus.square.on.square", title: L("editor.selected.duplicate"), action: onDuplicate)
                        EditorIconButton("trash", title: L("editor.selected.delete"), action: onDelete)
                        EditorIconButton("xmark", title: L("editor.selected.deselect"), action: onDeselect)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "cursorarrow.click.2")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(L("editor.selected.empty_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(L("editor.selected.shortcuts_hint"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
        }
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(item != nil ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }
}
