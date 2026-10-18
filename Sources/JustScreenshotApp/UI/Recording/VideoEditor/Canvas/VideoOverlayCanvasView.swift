import SwiftUI

/// Оверлей поверх плеера для добавления аннотаций и интерактивного кадрирования (Crop)
public struct VideoOverlayCanvasView: View {
    @ObservedObject var model: VideoEditorModel
    
    public init(model: VideoEditorModel) {
        self.model = model
    }
    
    public var body: some View {
        GeometryReader { geo in
            let containerSize = geo.size
            let videoRect = model.videoContentRect(in: containerSize)
            
            ZStack(alignment: .topLeading) {
                if model.isCropping {
                    CropOverlayView(
                        model: model,
                        containerSize: containerSize,
                        videoRect: videoRect
                    )
                }
                
                ForEach(model.annotations) { item in
                    VideoAnnotationItemView(
                        item: item,
                        videoRect: videoRect,
                        isSelected: model.selectedAnnotationID == item.id,
                        onSelect: {
                            model.selectedAnnotationID = item.id
                        },
                        onUpdate: { updated in
                            model.updateAnnotation(updated)
                        },
                        onDelete: {
                            model.removeAnnotation(id: item.id)
                        }
                    )
                }
            }
            .frame(width: containerSize.width, height: containerSize.height)
            .contentShape(Rectangle())
            .onTapGesture {
                model.selectedAnnotationID = nil
            }
        }
    }
}
