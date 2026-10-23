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
            RoundedRectangle(cornerRadius: 6)
                .fill(.ultraThinMaterial)
                .frame(width: itemWidth, height: itemHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.4), lineWidth: isSelected ? 1.5 : 1)
                )
                .contentShape(Rectangle())
            
            if isSelected {
                selectionControls(width: itemWidth, height: itemHeight)
            }
        }
        .frame(width: itemWidth, height: itemHeight)
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
                .frame(width: width + 8, height: height + 8)
            
            // Кнопка удаления в верхнем правом углу
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white, Color.red)
                    .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            .offset(x: width / 2 + 6, y: -(height / 2 + 6))
            
            resizeHandle(width: width, height: height, isLeft: true, isTop: true)
            resizeHandle(width: width, height: height, isLeft: false, isTop: true)
            resizeHandle(width: width, height: height, isLeft: true, isTop: false)
            resizeHandle(width: width, height: height, isLeft: false, isTop: false)
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
