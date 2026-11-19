import SwiftUI

enum AnnotationHandle: Equatable {
    case rotate
    case start
    case end
    case curveControl
    case corner(left: Bool, top: Bool)
}

enum AnnotationDragMode: Equatable {
    case idle
    case drawing
    case moving
    case handle(AnnotationHandle)
}

struct AnnotationCanvasInteractions {
    let zoomScale: CGFloat

    private var z: CGFloat { max(zoomScale, 0.05) }
    private var rotateOffset: CGFloat { 26 / z }
    private var handleHitRadius: CGFloat { 11 / z }

    func modelPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x / z, y: p.y / z)
    }

    /// Позиции ручек в локальной (неповернутой) системе элемента
    func handlePositions(of item: AnnotationItem) -> [(AnnotationHandle, CGPoint)] {
        var result: [(AnnotationHandle, CGPoint)] = []
        if item.isLineLike {
            result.append((.start, item.startPoint))
            if item.tool == .curvedArrow {
                result.append((.curveControl, item.curveApex))
            }
            result.append((.end, item.endPoint))
        } else {
            let box = item.boundingBox
            if item.isRectLike {
                result.append((.corner(left: true, top: true), CGPoint(x: box.minX, y: box.minY)))
                result.append((.corner(left: false, top: true), CGPoint(x: box.maxX, y: box.minY)))
                result.append((.corner(left: true, top: false), CGPoint(x: box.minX, y: box.maxY)))
                result.append((.corner(left: false, top: false), CGPoint(x: box.maxX, y: box.maxY)))
            }
            if item.supportsRotation {
                result.append((.rotate, CGPoint(x: box.midX, y: box.minY - rotateOffset)))
            }
        }
        return result
    }

    func hitHandle(of item: AnnotationItem, at point: CGPoint) -> AnnotationHandle? {
        let local = item.unrotated(point)
        let ordered = handlePositions(of: item).sorted { lhs, rhs in
            let lPriority = lhs.0 == .rotate ? 0 : 1
            let rPriority = rhs.0 == .rotate ? 0 : 1
            return lPriority < rPriority
        }
        for (h, pos) in ordered where hypot(local.x - pos.x, local.y - pos.y) <= handleHitRadius {
            return h
        }
        return nil
    }

    /// Применяет ручку к копии элемента, сохраняя противоположный угол неподвижным при ресайзе с поворотом
    func applyingHandle(_ h: AnnotationHandle, snap: AnnotationItem, to loc: CGPoint) -> AnnotationItem {
        var item = snap
        switch h {
        case .rotate:
            let c = snap.center
            var deg = atan2(loc.y - c.y, loc.x - c.x) * 180 / .pi + 90
            deg = AnnotationItem.normalize(deg)
            let snapped = (deg / 15).rounded() * 15
            if abs(deg - snapped) < 4 { deg = snapped }
            item.rotationAngle = deg
        case .start:
            item.startPoint = loc
        case .end:
            item.endPoint = loc
        case .curveControl:
            let dx = snap.endPoint.x - snap.startPoint.x
            let dy = snap.endPoint.y - snap.startPoint.y
            let len = hypot(dx, dy)
            if len > 1 {
                let normal = CGPoint(x: -dy / len, y: dx / len)
                let mid = CGPoint(x: (snap.startPoint.x + snap.endPoint.x) / 2, y: (snap.startPoint.y + snap.endPoint.y) / 2)
                let proj = (loc.x - mid.x) * normal.x + (loc.y - mid.y) * normal.y
                item.curveOffset = proj * 2.0
            }
        case .corner(let left, let top):
            let minX = min(snap.startPoint.x, snap.endPoint.x)
            let maxX = max(snap.startPoint.x, snap.endPoint.x)
            let minY = min(snap.startPoint.y, snap.endPoint.y)
            let maxY = max(snap.startPoint.y, snap.endPoint.y)

            let anchorLocal = CGPoint(x: left ? maxX : minX, y: top ? maxY : minY)
            let anchorWorld = snap.rotated(anchorLocal)

            let rad = snap.rotationAngle * .pi / 180
            let cosA = cos(rad)
            let sinA = sin(rad)
            let vx = loc.x - anchorWorld.x
            let vy = loc.y - anchorWorld.y

            let dirX: CGFloat = left ? -1 : 1
            let dirY: CGFloat = top ? -1 : 1
            let wSigned = max(4.0, (vx * cosA + vy * sinA) * dirX) * dirX
            let hSigned = max(4.0, (-vx * sinA + vy * cosA) * dirY) * dirY

            let newCenterX = anchorWorld.x + (wSigned * cosA - hSigned * sinA) / 2.0
            let newCenterY = anchorWorld.y + (wSigned * sinA + hSigned * cosA) / 2.0
            let halfW = abs(wSigned) / 2.0
            let halfH = abs(hSigned) / 2.0

            item.startPoint = CGPoint(x: newCenterX - halfW, y: newCenterY - halfH)
            item.endPoint = CGPoint(x: newCenterX + halfW, y: newCenterY + halfH)
        }
        return item
    }
}
