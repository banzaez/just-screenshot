import SwiftUI

/// Затемнение и интерактивная рамка кадрирования поверх видеокадра
struct CropOverlayView: View {
    @ObservedObject var model: VideoEditorModel
    let containerSize: CGSize
    let videoRect: CGRect
    
    @State private var dragInitialCrop: CGRect?
    @State private var resizeCornerStartCrop: CGRect?
    
    var body: some View {
        let cropPixelRect = CGRect(
            x: videoRect.origin.x + model.cropRect.origin.x * videoRect.width,
            y: videoRect.origin.y + model.cropRect.origin.y * videoRect.height,
            width: max(10, model.cropRect.width * videoRect.width),
            height: max(10, model.cropRect.height * videoRect.height)
        )
        
        ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(CGRect(origin: .zero, size: containerSize))
                path.addRect(cropPixelRect)
            }
            .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)
            
            ZStack {
                VStack(spacing: 0) {
                    Spacer()
                    Divider().background(Color.white.opacity(0.4))
                    Spacer()
                    Divider().background(Color.white.opacity(0.4))
                    Spacer()
                }
                HStack(spacing: 0) {
                    Spacer()
                    Divider().background(Color.white.opacity(0.4))
                    Spacer()
                    Divider().background(Color.white.opacity(0.4))
                    Spacer()
                }
            }
            .frame(width: cropPixelRect.width, height: cropPixelRect.height)
            .overlay(
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .position(x: cropPixelRect.midX, y: cropPixelRect.midY)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        if dragInitialCrop == nil {
                            dragInitialCrop = model.cropRect
                        }
                        guard let initial = dragInitialCrop, videoRect.width > 0, videoRect.height > 0 else { return }
                        let dx = val.translation.width / videoRect.width
                        let dy = val.translation.height / videoRect.height
                        
                        let newX = max(0, min(1 - initial.width, initial.origin.x + dx))
                        let newY = max(0, min(1 - initial.height, initial.origin.y + dy))
                        model.cropRect.origin = CGPoint(x: newX, y: newY)
                    }
                    .onEnded { _ in
                        dragInitialCrop = nil
                    }
            )
            
            cropCornerHandle(cropPixelRect: cropPixelRect, isLeft: true, isTop: true)
            cropCornerHandle(cropPixelRect: cropPixelRect, isLeft: false, isTop: true)
            cropCornerHandle(cropPixelRect: cropPixelRect, isLeft: true, isTop: false)
            cropCornerHandle(cropPixelRect: cropPixelRect, isLeft: false, isTop: false)
        }
    }
    
    @ViewBuilder
    private func cropCornerHandle(cropPixelRect: CGRect, isLeft: Bool, isTop: Bool) -> some View {
        let handleSize: CGFloat = 16
        let x = isLeft ? cropPixelRect.minX : cropPixelRect.maxX
        let y = isTop ? cropPixelRect.minY : cropPixelRect.maxY
        
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1.5))
            .frame(width: handleSize, height: handleSize)
            .shadow(radius: 2)
            .position(x: x, y: y)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        if resizeCornerStartCrop == nil {
                            resizeCornerStartCrop = model.cropRect
                        }
                        guard let initial = resizeCornerStartCrop, videoRect.width > 0, videoRect.height > 0 else { return }
                        let dx = val.translation.width / videoRect.width
                        let dy = val.translation.height / videoRect.height
                        
                        var minX = initial.minX
                        var maxX = initial.maxX
                        var minY = initial.minY
                        var maxY = initial.maxY
                        
                        if isLeft {
                            minX = min(initial.minX + dx, maxX - 0.05)
                        } else {
                            maxX = max(initial.maxX + dx, minX + 0.05)
                        }
                        
                        if isTop {
                            minY = min(initial.minY + dy, maxY - 0.05)
                        } else {
                            maxY = max(initial.maxY + dy, minY + 0.05)
                        }
                        
                        minX = max(0, min(1, minX))
                        maxX = max(0, min(1, maxX))
                        minY = max(0, min(1, minY))
                        maxY = max(0, min(1, maxY))
                        
                        model.cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                    }
                    .onEnded { _ in
                        resizeCornerStartCrop = nil
                    }
            )
    }
}
