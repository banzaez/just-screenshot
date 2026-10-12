import SwiftUI
import AppKit

/// Контекстная панель настроек для выбранного наложенного элемента в видеоредакторе
public struct VideoSelectedItemBar: View {
    @ObservedObject var model: VideoEditorModel
    
    public init(model: VideoEditorModel) {
        self.model = model
    }
    
    private var selectedIndex: Int? {
        guard let id = model.selectedAnnotationID else { return nil }
        return model.annotations.firstIndex(where: { $0.id == id })
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            if let idx = selectedIndex {
                let item = model.annotations[idx]
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Label(item.type.localizedTitle, systemImage: item.type.icon)
                            .font(.callout.bold())
                            .foregroundStyle(Color.accentColor)
                        
                        Divider().frame(height: 20)
                        
                        // Редактирование текста и размера шрифта
                        if item.type == .text {
                            TextField(
                                L("editor.selected.text_field"),
                                text: Binding(
                                    get: { model.annotations[idx].text },
                                    set: { model.annotations[idx].text = $0 }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 170)
                            
                            EditorIconButton("textformat.size.smaller", title: L("editor.selected.font_smaller")) {
                                model.annotations[idx].fontSize = max(10, model.annotations[idx].fontSize - 2)
                            }
                            Text("\(Int(item.fontSize))")
                                .font(.callout.monospacedDigit())
                                .frame(width: 28)
                            EditorIconButton("textformat.size.larger", title: L("editor.selected.font_larger")) {
                                model.annotations[idx].fontSize = min(96, model.annotations[idx].fontSize + 2)
                            }
                            
                            Divider().frame(height: 20)
                        }
                        
                        // Цвет элемента (если не blur)
                        if item.type != .blur {
                            ColorDropdown(
                                selection: Binding(
                                    get: { model.annotations[idx].color },
                                    set: { model.annotations[idx].color = $0 }
                                )
                            )
                        }
                        
                        // Толщина линии (для рамки и стрелки)
                        if item.type == .rect || item.type == .arrow {
                            WidthDropdown(
                                selection: Binding(
                                    get: { model.annotations[idx].lineWidth },
                                    set: { model.annotations[idx].lineWidth = $0 }
                                )
                            )
                        }
                        
                        Divider().frame(height: 20)
                        
                        // Поворот угла (Slider + кнопки шага + сброс)
                        EditorIconButton("rotate.left", title: L("editor.selected.rotate_left")) {
                            var deg = model.annotations[idx].rotationAngle - 15
                            if deg < -180 { deg += 360 }
                            model.annotations[idx].rotationAngle = deg
                        }
                        
                        Slider(
                            value: Binding(
                                get: { model.annotations[idx].rotationAngle },
                                set: { model.annotations[idx].rotationAngle = $0 }
                            ),
                            in: -180...180
                        )
                        .frame(width: 100)
                        
                        EditorIconButton("rotate.right", title: L("editor.selected.rotate_right")) {
                            var deg = model.annotations[idx].rotationAngle + 15
                            if deg > 180 { deg -= 360 }
                            model.annotations[idx].rotationAngle = deg
                        }
                        
                        Text("\(Int(item.rotationAngle.rounded()))°")
                            .font(.callout.monospacedDigit())
                            .frame(width: 36)
                        
                        EditorIconButton("arrow.counterclockwise", title: L("editor.selected.reset_angle")) {
                            model.annotations[idx].rotationAngle = 0
                        }
                        
                        Divider().frame(height: 20)
                        
                        // Дублирование
                        EditorIconButton("plus.square.on.square", title: L("editor.selected.duplicate")) {
                            model.duplicateAnnotation(id: item.id)
                        }
                        
                        // Удаление
                        EditorIconButton("trash", title: L("editor.selected.delete")) {
                            model.removeAnnotation(id: item.id)
                        }
                        
                        // Снятие выделения
                        EditorIconButton("xmark", title: L("editor.selected.deselect")) {
                            model.selectedAnnotationID = nil
                        }
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
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
        }
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(selectedIndex != nil ? Color.accentColor.opacity(0.12) : Color(NSColor.windowBackgroundColor).opacity(0.7))
        .overlay(Divider(), alignment: .bottom)
    }
}
