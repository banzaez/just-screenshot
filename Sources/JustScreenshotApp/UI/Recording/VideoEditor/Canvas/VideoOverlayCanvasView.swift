import SwiftUI

/// Оверлей поверх плеера для отображения и редактирования blur-аннотаций поверх видео
public struct VideoOverlayCanvasView: View {
    var model: VideoEditorModel

    public init(model: VideoEditorModel) {
        self.model = model
    }

    public var body: some View {
        GeometryReader { geo in
            let containerSize = geo.size
            let videoRect = model.videoContentRect(in: containerSize)

            ZStack(alignment: .topLeading) {
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
            .coordinateSpace(name: "videoOverlay")
            .frame(width: containerSize.width, height: containerSize.height)
            .contentShape(Rectangle())
            .onTapGesture {
                model.selectedAnnotationID = nil
            }
        }
    }
}
