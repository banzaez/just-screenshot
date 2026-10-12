import SwiftUI
import AppKit

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
                // 1. Оверлей кадрирования (Crop) с гарантированным затемнением неактивных областей
                if model.isCropping {
                    CropOverlayView(
                        model: model,
                        containerSize: containerSize,
                        videoRect: videoRect
                    )
                }
                
                // 2. Аннотации поверх видеокадра
                ForEach(model.annotations) { item in
                    VideoAnnotationItemView(
                        item: item,
                        videoRect: videoRect,
                        containerSize: containerSize,
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

// MARK: - Crop Overlay View

private struct CropOverlayView: View {
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
            // Затемнение всей области экрана вокруг вырезанного прямоугольника кадрирования
            Path { path in
                path.addRect(CGRect(origin: .zero, size: containerSize))
                path.addRect(cropPixelRect)
            }
            .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)
            
            // Рамка кадрирования с сеткой третей
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
            // Перетаскивание всей рамки кадрирования
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
            
            // 4 Угловых маркера масштабирования рамки
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

// MARK: - Video Annotation Item View

private struct VideoAnnotationItemView: View {
    let item: VideoAnnotationItem
    let videoRect: CGRect
    let containerSize: CGSize
    let isSelected: Bool
    let onSelect: () -> Void
    let onUpdate: (VideoAnnotationItem) -> Void
    let onDelete: () -> Void
    
    @State private var dragInitialOrigin: CGPoint?
    @State private var resizeInitialRect: CGRect?
    
    var body: some View {
        let itemWidth = max(24, item.rect.width * videoRect.width)
        let itemHeight = max(24, item.rect.height * videoRect.height)
        let itemCenterX = videoRect.origin.x + (item.rect.origin.x + item.rect.width / 2) * videoRect.width
        let itemCenterY = videoRect.origin.y + (item.rect.origin.y + item.rect.height / 2) * videoRect.height
        
        ZStack {
            // Отрисовка контента элемента с четким frame
            Group {
                switch item.type {
                case .text:
                    Text(item.text.isEmpty ? " " : item.text)
                        .font(.system(size: item.fontSize, weight: .bold))
                        .foregroundColor(item.color)
                        .multilineTextAlignment(.center)
                        .frame(width: itemWidth, height: itemHeight)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                case .rect:
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(item.color, lineWidth: item.lineWidth)
                        .frame(width: itemWidth, height: itemHeight)
                    
                case .arrow:
                    Path { p in
                        p.move(to: CGPoint(x: 4, y: itemHeight - 4))
                        p.addLine(to: CGPoint(x: itemWidth - 4, y: 4))
                        let headLength: CGFloat = max(12, item.lineWidth * 3)
                        let angle = atan2(-itemHeight + 8, itemWidth - 8)
                        let arrowP1 = CGPoint(
                            x: (itemWidth - 4) - headLength * cos(angle - .pi / 6),
                            y: 4 - headLength * sin(angle - .pi / 6)
                        )
                        let arrowP2 = CGPoint(
                            x: (itemWidth - 4) - headLength * cos(angle + .pi / 6),
                            y: 4 - headLength * sin(angle + .pi / 6)
                        )
                        p.move(to: CGPoint(x: itemWidth - 4, y: 4))
                        p.addLine(to: arrowP1)
                        p.move(to: CGPoint(x: itemWidth - 4, y: 4))
                        p.addLine(to: arrowP2)
                    }
                    .stroke(item.color, style: StrokeStyle(lineWidth: item.lineWidth, lineCap: .round, lineJoin: .round))
                    .frame(width: itemWidth, height: itemHeight)
                    
                case .blur:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial)
                        .frame(width: itemWidth, height: itemHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                }
            }
            .contentShape(Rectangle())
            
            // Рамка выделения и ручки манипулятора строго по размеру элемента
            if isSelected {
                selectionControls(width: itemWidth, height: itemHeight, centerX: itemCenterX, centerY: itemCenterY)
            }
        }
        .frame(width: itemWidth, height: itemHeight)
        .rotationEffect(.degrees(item.rotationAngle))
        .position(x: itemCenterX, y: itemCenterY)
        // Плавное перетаскивание всего элемента без скачков
        .gesture(
            DragGesture()
                .onChanged { val in
                    onSelect()
                    if dragInitialOrigin == nil {
                        dragInitialOrigin = item.rect.origin
                    }
                    guard let initial = dragInitialOrigin, videoRect.width > 0, videoRect.height > 0 else { return }
                    let dx = val.translation.width / videoRect.width
                    let dy = val.translation.height / videoRect.height
                    
                    var updated = item
                    let newX = max(0, min(1 - item.rect.width, initial.x + dx))
                    let newY = max(0, min(1 - item.rect.height, initial.y + dy))
                    updated.rect.origin = CGPoint(x: newX, y: newY)
                    onUpdate(updated)
                }
                .onEnded { _ in
                    dragInitialOrigin = nil
                }
        )
        .onTapGesture {
            onSelect()
        }
    }
    
    @ViewBuilder
    private func selectionControls(width: CGFloat, height: CGFloat, centerX: CGFloat, centerY: CGFloat) -> some View {
        ZStack {
            // Пунктирная рамка выделения строго вокруг элемента (без расползания)
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: width + 10, height: height + 10)
            
            // Компактная ручка вращения сверху со стеблем
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .shadow(radius: 2)
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .onChanged { val in
                                let loc = val.location
                                let centerInWindow = CGPoint(x: centerX, y: centerY)
                                var deg = atan2(loc.y - centerInWindow.y, loc.x - centerInWindow.x) * 180 / .pi + 90
                                if deg > 180 { deg -= 360 }
                                if deg < -180 { deg += 360 }
                                let snapped = (deg / 15).rounded() * 15
                                if abs(deg - snapped) < 4 { deg = snapped }
                                var updated = item
                                updated.rotationAngle = deg
                                onUpdate(updated)
                            }
                    )
                
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 1.5, height: 16)
            }
            .offset(y: -(height / 2 + 18))
            
            // 4 Угловых маркера масштабирования
            if item.type != .text {
                resizeHandle(width: width, height: height, isLeft: true, isTop: true)
                resizeHandle(width: width, height: height, isLeft: false, isTop: true)
                resizeHandle(width: width, height: height, isLeft: true, isTop: false)
                resizeHandle(width: width, height: height, isLeft: false, isTop: false)
            }
        }
        .frame(width: width, height: height)
    }
    
    @ViewBuilder
    private func resizeHandle(width: CGFloat, height: CGFloat, isLeft: Bool, isTop: Bool) -> some View {
        let xOffset = (isLeft ? -width / 2 : width / 2) + (isLeft ? -5 : 5)
        let yOffset = (isTop ? -height / 2 : height / 2) + (isTop ? -5 : 5)
        
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
            .frame(width: 10, height: 10)
            .shadow(radius: 2)
            .offset(x: xOffset, y: yOffset)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        if resizeInitialRect == nil {
                            resizeInitialRect = item.rect
                        }
                        guard let initial = resizeInitialRect, videoRect.width > 0, videoRect.height > 0 else { return }
                        let dx = val.translation.width / videoRect.width
                        let dy = val.translation.height / videoRect.height
                        
                        var newRect = initial
                        if isLeft {
                            let adjustedW = initial.width - dx
                            if adjustedW > 0.03 {
                                newRect.origin.x = initial.origin.x + dx
                                newRect.size.width = adjustedW
                            }
                        } else {
                            let adjustedW = initial.width + dx
                            if adjustedW > 0.03 {
                                newRect.size.width = adjustedW
                            }
                        }
                        
                        if isTop {
                            let adjustedH = initial.height - dy
                            if adjustedH > 0.03 {
                                newRect.origin.y = initial.origin.y + dy
                                newRect.size.height = adjustedH
                            }
                        } else {
                            let adjustedH = initial.height + dy
                            if adjustedH > 0.03 {
                                newRect.size.height = adjustedH
                            }
                        }
                        
                        var updated = item
                        updated.rect = newRect
                        onUpdate(updated)
                    }
                    .onEnded { _ in
                        resizeInitialRect = nil
                    }
            )
    }
}
