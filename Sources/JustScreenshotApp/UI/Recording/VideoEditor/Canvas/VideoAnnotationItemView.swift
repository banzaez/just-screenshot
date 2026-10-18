import SwiftUI

/// Интерактивная аннотация поверх видеокадра (drag / resize / rotate)
struct VideoAnnotationItemView: View {
    let item: VideoAnnotationItem
    let videoRect: CGRect
    let isSelected: Bool
    let onSelect: () -> Void
    let onUpdate: (VideoAnnotationItem) -> Void
    let onDelete: () -> Void
    
    @State private var dragInitialOrigin: CGPoint?
    @State private var resizeInitialRect: CGRect?
    @State private var globalCenter: CGPoint = .zero
    
    var body: some View {
        let itemWidth = max(24, item.rect.width * videoRect.width)
        let itemHeight = max(24, item.rect.height * videoRect.height)
        let itemCenterX = videoRect.origin.x + (item.rect.origin.x + item.rect.width / 2) * videoRect.width
        let itemCenterY = videoRect.origin.y + (item.rect.origin.y + item.rect.height / 2) * videoRect.height
        
        ZStack {
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
                        let geometry = AnnotationArrowGeometry.diagonal(in: CGSize(width: itemWidth, height: itemHeight), lineWidth: item.lineWidth)
                        p.move(to: geometry.start)
                        p.addLine(to: geometry.end)
                        p.move(to: geometry.end)
                        p.addLine(to: geometry.headLeft)
                        p.move(to: geometry.end)
                        p.addLine(to: geometry.headRight)
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
            
            if isSelected {
                selectionControls(width: itemWidth, height: itemHeight)
            }
        }
        .frame(width: itemWidth, height: itemHeight)
        .rotationEffect(.degrees(item.rotationAngle))
        .position(x: itemCenterX, y: itemCenterY)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let frame = geo.frame(in: .global)
                        globalCenter = CGPoint(x: frame.midX, y: frame.midY)
                    }
                    .onChange(of: geo.frame(in: .global)) { _, frame in
                        globalCenter = CGPoint(x: frame.midX, y: frame.midY)
                    }
            }
        )
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
    private func selectionControls(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: width + 10, height: height + 10)
            
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
                                var deg = atan2(loc.y - globalCenter.y, loc.x - globalCenter.x) * 180 / .pi + 90
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
