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
    @State private var isHovered = false

    var body: some View {
        let itemWidth = max(24, item.rect.width * videoRect.width)
        let itemHeight = max(24, item.rect.height * videoRect.height)
        let itemCenterX = videoRect.origin.x + (item.rect.origin.x + item.rect.width / 2) * videoRect.width
        let itemCenterY = videoRect.origin.y + (item.rect.origin.y + item.rect.height / 2) * videoRect.height
        let cornerRadius = min(12, min(itemWidth, itemHeight) * 0.22)

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .frame(width: itemWidth, height: itemHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isSelected ? 0.65 : (isHovered ? 0.50 : 0.35)),
                                    Color.white.opacity(isSelected ? 0.20 : 0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
                .shadow(
                    color: .black.opacity(isSelected ? 0.35 : (isHovered ? 0.22 : 0.12)),
                    radius: isSelected ? 10 : (isHovered ? 6 : 3),
                    y: 2
                )
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            if isSelected {
                selectionControls(width: itemWidth, height: itemHeight, cornerRadius: cornerRadius)
            }
        }
        .frame(width: itemWidth, height: itemHeight)
        .rotationEffect(.degrees(item.rotationAngle))
        .position(x: itemCenterX, y: itemCenterY)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .gesture(
            DragGesture(coordinateSpace: .named("videoOverlay"))
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
    private func selectionControls(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius + 3, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 1.5)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 4)
                .frame(width: width + 6, height: height + 6)

            // Кнопка удаления вынесена над рамкой, чтобы не пересекаться с угловыми ручками
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(0.92))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                    )
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .offset(x: 0, y: -(height / 2 + 18))
            .zIndex(2)

            resizeHandle(width: width, height: height, isLeft: true, isTop: true)
            resizeHandle(width: width, height: height, isLeft: false, isTop: true)
            resizeHandle(width: width, height: height, isLeft: true, isTop: false)
            resizeHandle(width: width, height: height, isLeft: false, isTop: false)
        }
        .frame(width: width, height: height)
    }

    @ViewBuilder
    private func resizeHandle(width: CGFloat, height: CGFloat, isLeft: Bool, isTop: Bool) -> some View {
        let xOffset = (isLeft ? -width / 2 : width / 2) + (isLeft ? -3 : 3)
        let yOffset = (isTop ? -height / 2 : height / 2) + (isTop ? -3 : 3)

        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.8))
            .frame(width: 9, height: 9)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .offset(x: xOffset, y: yOffset)
            .gesture(
                DragGesture(coordinateSpace: .named("videoOverlay"))
                    .onChanged { val in
                        if resizeInitialRect == nil {
                            resizeInitialRect = item.rect
                        }
                        guard let initial = resizeInitialRect, videoRect.width > 0, videoRect.height > 0 else { return }
                        let minNorm: CGFloat = 0.03
                        let dx = val.translation.width / videoRect.width
                        let dy = val.translation.height / videoRect.height

                        var newRect = initial
                        if isLeft {
                            let maxRight = initial.maxX
                            let clampedX = max(0, min(maxRight - minNorm, initial.origin.x + dx))
                            newRect.origin.x = clampedX
                            newRect.size.width = maxRight - clampedX
                        } else {
                            let clampedW = max(minNorm, min(1.0 - initial.origin.x, initial.width + dx))
                            newRect.size.width = clampedW
                        }

                        if isTop {
                            let maxBottom = initial.maxY
                            let clampedY = max(0, min(maxBottom - minNorm, initial.origin.y + dy))
                            newRect.origin.y = clampedY
                            newRect.size.height = maxBottom - clampedY
                        } else {
                            let clampedH = max(minNorm, min(1.0 - initial.origin.y, initial.height + dy))
                            newRect.size.height = clampedH
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
