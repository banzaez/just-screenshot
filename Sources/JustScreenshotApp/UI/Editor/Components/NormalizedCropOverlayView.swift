import SwiftUI

/// Универсальная интерактивная рамка кадрирования с нормализованными координатами [0...1]
struct NormalizedCropOverlayView: View {
    @Binding var cropRect: CGRect
    let containerSize: CGSize
    let contentRect: CGRect
    var minPixelSize: CGFloat = 10
    var handleSize: CGFloat = 16
    
    @State private var dragInitialCrop: CGRect?
    @State private var resizeCornerStartCrop: CGRect?
    
    var body: some View {
        let cropPixelRect = CGRect(
            x: contentRect.origin.x + cropRect.origin.x * contentRect.width,
            y: contentRect.origin.y + cropRect.origin.y * contentRect.height,
            width: max(minPixelSize, cropRect.width * contentRect.width),
            height: max(minPixelSize, cropRect.height * contentRect.height)
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
                            dragInitialCrop = cropRect
                        }
                        guard let initial = dragInitialCrop, contentRect.width > 0, contentRect.height > 0 else { return }
                        let dx = val.translation.width / contentRect.width
                        let dy = val.translation.height / contentRect.height
                        
                        let newX = max(0, min(1 - initial.width, initial.origin.x + dx))
                        let newY = max(0, min(1 - initial.height, initial.origin.y + dy))
                        cropRect.origin = CGPoint(x: newX, y: newY)
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
        let x = isLeft ? cropPixelRect.minX : cropPixelRect.maxX
        let y = isTop ? cropPixelRect.minY : cropPixelRect.maxY
        
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.black.opacity(0.55), lineWidth: 1.5))
            .frame(width: handleSize, height: handleSize)
            .shadow(radius: 2)
            .position(x: x, y: y)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        if resizeCornerStartCrop == nil {
                            resizeCornerStartCrop = cropRect
                        }
                        guard let initial = resizeCornerStartCrop, contentRect.width > 0, contentRect.height > 0 else { return }
                        let dx = val.translation.width / contentRect.width
                        let dy = val.translation.height / contentRect.height
                        
                        var minX = initial.minX
                        var maxX = initial.maxX
                        var minY = initial.minY
                        var maxY = initial.maxY
                        let minSize: CGFloat = 0.05
                        
                        if isLeft {
                            minX = max(0, min(maxX - minSize, initial.minX + dx))
                        } else {
                            maxX = min(1.0, max(minX + minSize, initial.maxX + dx))
                        }
                        
                        if isTop {
                            minY = max(0, min(maxY - minSize, initial.minY + dy))
                        } else {
                            maxY = min(1.0, max(minY + minSize, initial.maxY + dy))
                        }
                        
                        cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                    }
                    .onEnded { _ in
                        resizeCornerStartCrop = nil
                    }
            )
    }
}
