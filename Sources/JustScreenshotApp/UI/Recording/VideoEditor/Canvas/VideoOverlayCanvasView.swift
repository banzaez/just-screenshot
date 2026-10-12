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
            let size = geo.size
            
            ZStack(alignment: .topLeading) {
                // 1. Оверлей кадрирования (Crop) с гарантированным затемнением неактивных областей
                if model.isCropping {
                    CropOverlayView(model: model, containerSize: size)
                }
                
                // 2. Аннотации поверх видео с перемещением, вращением и растягиванием
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
            .frame(width: size.width, height: size.height)
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
    
    @State private var dragInitialCrop: CGRect?
    
    var body: some View {
        let cropPixelRect = CGRect(
            x: model.cropRect.origin.x * containerSize.width,
            y: model.cropRect.origin.y * containerSize.height,
            width: model.cropRect.width * containerSize.width,
            height: model.cropRect.height * containerSize.height
        )
        
        ZStack(alignment: .topLeading) {
            // Надежное затемнение через Path c even-odd правилом (вырезает прямоугольник кадрирования)
            Path { path in
                path.addRect(CGRect(origin: .zero, size: containerSize))
                path.addRect(cropPixelRect)
            }
            .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)
            
            // Центральная интерактивная рамка кадрирования с сеткой третей
            ZStack {
                // Сетка 3x3
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
            .frame(width: max(1, cropPixelRect.width), height: max(1, cropPixelRect.height))
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
                        guard let initial = dragInitialCrop, containerSize.width > 0, containerSize.height > 0 else { return }
                        let dx = val.translation.width / containerSize.width
                        let dy = val.translation.height / containerSize.height
                        
                        let newX = max(0, min(1 - initial.width, initial.origin.x + dx))
                        let newY = max(0, min(1 - initial.height, initial.origin.y + dy))
                        model.cropRect.origin = CGPoint(x: newX, y: newY)
                    }
                    .onEnded { _ in
                        dragInitialCrop = nil
                    }
            )
            
            // 4 Угловых маркера изменения размера рамки
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
            .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1.5))
            .frame(width: handleSize, height: handleSize)
            .shadow(radius: 2)
            .position(x: x, y: y)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        guard containerSize.width > 0, containerSize.height > 0 else { return }
                        let currentNormalizedX = max(0, min(1, val.location.x / containerSize.width))
                        let currentNormalizedY = max(0, min(1, val.location.y / containerSize.height))
                        
                        var minX = model.cropRect.minX
                        var maxX = model.cropRect.maxX
                        var minY = model.cropRect.minY
                        var maxY = model.cropRect.maxY
                        
                        if isLeft {
                            minX = min(currentNormalizedX, maxX - 0.05)
                        } else {
                            maxX = max(currentNormalizedX, minX + 0.05)
                        }
                        
                        if isTop {
                            minY = min(currentNormalizedY, maxY - 0.05)
                        } else {
                            maxY = max(currentNormalizedY, minY + 0.05)
                        }
                        
                        model.cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                    }
            )
    }
}

// MARK: - Video Annotation Item View

private struct VideoAnnotationItemView: View {
    @Binding var item: VideoAnnotationItem
    let containerSize: CGSize
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var dragInitialOrigin: CGPoint?
    
    var body: some View {
        let itemWidth = max(20, item.rect.width * containerSize.width)
        let itemHeight = max(20, item.rect.height * containerSize.height)
        let itemCenter = CGPoint(
            x: (item.rect.origin.x + item.rect.width / 2) * containerSize.width,
            y: (item.rect.origin.y + item.rect.height / 2) * containerSize.height
        )
        
        ZStack {
            // Отрисовка контента элемента
            Group {
                switch item.type {
                case .text:
                    Text(item.text)
                        .font(.system(size: item.fontSize, weight: .bold))
                        .foregroundColor(item.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
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
                        // Наконечник стрелки
                        let headLength: CGFloat = 14
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
            
            // Рамка выделения и ручки манипулятора
            if isSelected {
                selectionControls(width: itemWidth, height: itemHeight)
            }
        }
        .rotationEffect(.degrees(item.rotationAngle))
        .position(itemCenter)
        // Перемещение самого элемента через drag delta без дерганий
        .gesture(
            DragGesture()
                .onChanged { val in
                    onSelect()
                    if dragInitialOrigin == nil {
                        dragInitialOrigin = item.rect.origin
                    }
                    guard let initial = dragInitialOrigin, containerSize.width > 0, containerSize.height > 0 else { return }
                    let dx = val.translation.width / containerSize.width
                    let dy = val.translation.height / containerSize.height
                    
                    let newX = max(0, min(1 - item.rect.width, initial.x + dx))
                    let newY = max(0, min(1 - item.rect.height, initial.y + dy))
                    item.rect.origin = CGPoint(x: newX, y: newY)
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
    private func selectionControls(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Пунктирная рамка выделения
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .padding(-6)
            
            // Линия и ручка вращения сверху
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .shadow(radius: 2)
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                let center = CGPoint(
                                    x: (item.rect.origin.x + item.rect.width / 2) * containerSize.width,
                                    y: (item.rect.origin.y + item.rect.height / 2) * containerSize.height
                                )
                                let loc = CGPoint(
                                    x: center.x + val.translation.width,
                                    y: center.y - height / 2 - 24 + val.translation.height
                                )
                                var deg = atan2(loc.y - center.y, loc.x - center.x) * 180 / .pi + 90
                                if deg > 180 { deg -= 360 }
                                if deg < -180 { deg += 360 }
                                let snapped = (deg / 15).rounded() * 15
                                if abs(deg - snapped) < 4 { deg = snapped }
                                item.rotationAngle = deg
                            }
                    )
                
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 1.5, height: 18)
                
                Spacer()
            }
            .frame(height: height + 50)
            .offset(y: -25)
            
            // 4 Угловых маркера масштабирования
            if item.type != .text {
                resizeHandle(width: width, height: height, isLeft: true, isTop: true)
                resizeHandle(width: width, height: height, isLeft: false, isTop: true)
                resizeHandle(width: width, height: height, isLeft: true, isTop: false)
                resizeHandle(width: width, height: height, isLeft: false, isTop: false)
            }
        }
    }
    
    @ViewBuilder
    private func resizeHandle(width: CGFloat, height: CGFloat, isLeft: Bool, isTop: Bool) -> some View {
        let xOffset = (isLeft ? -width / 2 : width / 2) + (isLeft ? -6 : 6)
        let yOffset = (isTop ? -height / 2 : height / 2) + (isTop ? -6 : 6)
        
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
            .frame(width: 10, height: 10)
            .shadow(radius: 2)
            .offset(x: xOffset, y: yOffset)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        guard containerSize.width > 0, containerSize.height > 0 else { return }
                        let dx = val.translation.width / containerSize.width
                        let dy = val.translation.height / containerSize.height
                        
                        var newRect = item.rect
                        if isLeft {
                            let adjustedW = newRect.width - dx
                            if adjustedW > 0.03 {
                                newRect.origin.x += dx
                                newRect.size.width = adjustedW
                            }
                        } else {
                            let adjustedW = newRect.width + dx
                            if adjustedW > 0.03 {
                                newRect.size.width = adjustedW
                            }
                        }
                        
                        if isTop {
                            let adjustedH = newRect.height - dy
                            if adjustedH > 0.03 {
                                newRect.origin.y += dy
                                newRect.size.height = adjustedH
                            }
                        } else {
                            let adjustedH = newRect.height + dy
                            if adjustedH > 0.03 {
                                newRect.size.height = adjustedH
                            }
                        }
                        
                        item.rect = newRect
                    }
            )
    }
}
