import SwiftUI
import AppKit

/// Контекстная панель настроек для выбранного наложенного элемента в видеоредакторе
public struct VideoSelectedItemBar: View {
    @ObservedObject var model: VideoEditorModel
    
    public init(model: VideoEditorModel) {
        self.model = model
    }
    
    private var selectedItem: VideoAnnotationItem? {
        guard let id = model.selectedAnnotationID else { return nil }
        return model.annotations.first(where: { $0.id == id })
    }
    
    private func binding<T>(_ keyPath: WritableKeyPath<VideoAnnotationItem, T>, default defaultValue: T) -> Binding<T> {
        Binding(
            get: {
                guard let id = model.selectedAnnotationID,
                      let item = model.annotations.first(where: { $0.id == id }) else {
                    return defaultValue
                }
                return item[keyPath: keyPath]
            },
            set: { newValue in
                guard let id = model.selectedAnnotationID,
                      let idx = model.annotations.firstIndex(where: { $0.id == id }) else {
                    return
                }
                model.annotations[idx][keyPath: keyPath] = newValue
            }
        )
    }
    
    private func mutateSelected(_ update: (inout VideoAnnotationItem) -> Void) {
        guard let id = model.selectedAnnotationID,
              let idx = model.annotations.firstIndex(where: { $0.id == id }) else { return }
        update(&model.annotations[idx])
    }
    
    public var body: some View {
        SelectedAnnotationBarControls.BarChrome(
            isActive: selectedItem != nil,
            activeOpacity: 0.12,
            inactiveColor: Color(NSColor.windowBackgroundColor).opacity(0.7),
            showBottomDivider: true
        ) {
            if let item = selectedItem {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        SelectedAnnotationBarControls.TitleLabel(
                            title: item.type.localizedTitle,
                            systemImage: item.type.icon
                        )
                        
                        Divider().frame(height: 20)
                        
                        if item.type == .text {
                            TextField(
                                L("editor.selected.text_field"),
                                text: binding(\.text, default: "")
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 170)
                            
                            SelectedAnnotationBarControls.FontSizeControls(
                                fontSize: item.fontSize,
                                onSmaller: {
                                    mutateSelected { $0.fontSize = max(10, $0.fontSize - 2) }
                                },
                                onLarger: {
                                    mutateSelected { $0.fontSize = min(96, $0.fontSize + 2) }
                                }
                            )
                            
                            Divider().frame(height: 20)
                        }
                        
                        if item.type != .blur {
                            ColorDropdown(selection: binding(\.color, default: .red))
                        }
                        
                        if item.type == .rect || item.type == .arrow {
                            WidthDropdown(selection: binding(\.lineWidth, default: 3))
                        }
                        
                        Divider().frame(height: 20)
                        
                        SelectedAnnotationBarControls.RotationControls(
                            angle: item.rotationAngle,
                            onSetAngle: { angle in
                                mutateSelected { $0.rotationAngle = angle }
                            },
                            sliderWidth: 100,
                            wrapAngle: true
                        )
                        
                        Divider().frame(height: 20)
                        
                        SelectedAnnotationBarControls.ActionButtons(
                            onDuplicate: { model.duplicateAnnotation(id: item.id) },
                            onDelete: { model.removeAnnotation(id: item.id) },
                            onDeselect: { model.selectedAnnotationID = nil }
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
            } else {
                SelectedAnnotationBarControls.EmptyHint()
            }
        }
    }
}
