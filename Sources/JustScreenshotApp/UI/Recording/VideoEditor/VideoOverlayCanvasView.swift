import SwiftUI
import AVKit

/// Оверлей поверх плеера для добавления аннотаций и настройки кадрирования (Crop)
public struct VideoOverlayCanvasView: View {
    @ObservedObject var model: VideoEditorModel
    
    public init(model: VideoEditorModel) {
        self.model = model
    }
    
    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            
            ZStack(alignment: .topLeading) {
                // 1. Оверлей кадрирования (Crop)
                if model.isCropping {
                    CropOverlayView(model: model, containerSize: size)
                }
                
                // 2. Аннотации поверх видео
                ForEach($model.annotations) { $item in
                    VideoAnnotationItemView(
                        item: $item,
                        containerSize: size,
                        isSelected: model.selectedAnnotationID == item.id,
                        onSelect: { model.selectedAnnotationID = item.id },
                        onDelete: { model.removeAnnotation(id: item.id) }
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                model.selectedAnnotationID = nil
            }
        }
    }
}

private struct CropOverlayView: View {
    @ObservedObject var model: VideoEditorModel
    let containerSize: CGSize
    
    var body: some View {
        let cropPixelRect = CGRect(
            x: model.cropRect.origin.x * containerSize.width,
            y: model.cropRect.origin.y * containerSize.height,
            width: model.cropRect.width * containerSize.width,
            height: model.cropRect.height * containerSize.height
        )
        
        ZStack {
            // Затемнение вокруг области кадрирования
            Color.black.opacity(0.5)
                .mask(
                    Rectangle()
                        .overlay(
                            Rectangle()
                                .frame(width: cropPixelRect.width, height: cropPixelRect.height)
                                .offset(x: cropPixelRect.minX - (containerSize.width - cropPixelRect.width) / 2,
                                        y: cropPixelRect.minY - (containerSize.height - cropPixelRect.height) / 2)
                                .blendMode(.destinationOut)
                        )
                )
            
            // Рамка кадрирования с сеткой Rule of Thirds
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropPixelRect.width, height: cropPixelRect.height)
                .position(x: cropPixelRect.midX, y: cropPixelRect.midY)
                .overlay(
                    // Сетка 3x3
                    VStack {
                        Spacer()
                        Divider().background(Color.white.opacity(0.3))
                        Spacer()
                        Divider().background(Color.white.opacity(0.3))
                        Spacer()
                    }
                    .frame(width: cropPixelRect.width, height: cropPixelRect.height)
                    .position(x: cropPixelRect.midX, y: cropPixelRect.midY)
                )
        }
    }
}

private struct VideoAnnotationItemView: View {
    @Binding var item: VideoAnnotationItem
    let containerSize: CGSize
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        let itemFrame = CGRect(
            x: item.rect.origin.x * containerSize.width,
            y: item.rect.origin.y * containerSize.height,
            width: item.rect.width * containerSize.width,
            height: item.rect.height * containerSize.height
        )
        
        Group {
            switch item.type {
            case .text:
                Text(item.text)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(item.color)
                    .padding(6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
                
            case .rect:
                RoundedRectangle(cornerRadius: 6)
                    .stroke(item.color, lineWidth: item.lineWidth)
                    .frame(width: itemFrame.width, height: itemFrame.height)
                
            case .arrow:
                Path { p in
                    p.move(to: CGPoint(x: 0, y: itemFrame.height))
                    p.addLine(to: CGPoint(x: itemFrame.width, y: 0))
                }
                .stroke(item.color, lineWidth: item.lineWidth)
                .frame(width: itemFrame.width, height: itemFrame.height)
                
            case .blur:
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
                    .frame(width: itemFrame.width, height: itemFrame.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
            }
        }
        .overlay(
            isSelected ?
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.blue, lineWidth: 2)
                .padding(-4)
            : nil
        )
        .position(x: itemFrame.midX, y: itemFrame.midY)
        .gesture(
            DragGesture()
                .onChanged { val in
                    onSelect()
                    let newX = val.location.x / containerSize.width
                    let newY = val.location.y / containerSize.height
                    item.rect.origin = CGPoint(
                        x: max(0, min(1 - item.rect.width, newX - item.rect.width / 2)),
                        y: max(0, min(1 - item.rect.height, newY - item.rect.height / 2))
                    )
                }
        )
        .onTapGesture {
            onSelect()
        }
    }
}
