import SwiftUI
import AppKit

/// Контекстная панель выбранного элемента
public struct EditorSelectedItemBar: View {
    public let item: AnnotationItem
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
        item: AnnotationItem,
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Label(item.tool.rawValue, systemImage: item.tool.iconName)
                    .font(.callout.bold())
                    .foregroundStyle(Color.accentColor)
                
                Divider().frame(height: 22)
                
                if item.tool == .text {
                    TextField("Текст", text: Binding(get: { item.text }, set: { onTextChange($0) }))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                    EditorIconButton("textformat.size.smaller", title: "Меньше шрифт") { onFontSizeChange(max(10, item.fontSize - 2)) }
                    Text("\(Int(item.fontSize))").font(.callout.monospacedDigit()).frame(width: 28)
                    EditorIconButton("textformat.size.larger", title: "Больше шрифт") { onFontSizeChange(min(96, item.fontSize + 2)) }
                }
                
                if item.tool == .counter {
                    EditorIconButton("minus", title: "Номер −1") { onCounterChange(max(1, item.counterNumber - 1)) }
                    Text("№ \(item.counterNumber)").font(.callout.monospacedDigit()).frame(width: 44)
                    EditorIconButton("plus", title: "Номер +1") { onCounterChange(item.counterNumber + 1) }
                }
                
                ColorDropdown(selection: Binding(get: { item.color }, set: { onColorChange($0) }))
                
                if item.tool != .text && item.tool != .counter {
                    WidthDropdown(selection: Binding(get: { item.lineWidth }, set: { onLineWidthChange($0) }))
                }
                
                Divider().frame(height: 22)
                
                if item.tool != .counter {
                    EditorIconButton("rotate.left", title: "Повернуть −15°") { onSetAngle(item.displayAngle - 15) }
                    Slider(value: Binding(get: { item.displayAngle }, set: { onSetAngle($0) }), in: -180...180)
                        .frame(width: 120)
                    EditorIconButton("rotate.right", title: "Повернуть +15°") { onSetAngle(item.displayAngle + 15) }
                    Text("\(Int(item.displayAngle.rounded()))°").font(.callout.monospacedDigit()).frame(width: 44)
                    EditorIconButton("arrow.counterclockwise", title: "Сбросить угол") { onSetAngle(0) }
                }
                
                Divider().frame(height: 22)
                
                EditorIconButton("plus.square.on.square", title: "Дублировать (⌘D)", action: onDuplicate)
                EditorIconButton("trash", title: "Удалить (⌘⌫)", action: onDelete)
                EditorIconButton("xmark", title: "Снять выделение (Esc)", action: onDeselect)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(Color.accentColor.opacity(0.09))
    }
}
