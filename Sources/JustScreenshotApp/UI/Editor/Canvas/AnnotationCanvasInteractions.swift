import SwiftUI

enum AnnotationHandle: Equatable {
    case rotate
    case start
    case end
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
        // Ручка вращения проверяется первой, чтобы не конфликтовать с углами
        let ordered = handlePositions(of: item).sorted { a, _ in a.0 == .rotate }
        for (h, pos) in ordered where hypot(local.x - pos.x, local.y - pos.y) <= handleHitRadius {
            return h
        }
        return nil
    }
    
    func applyHandle(_ h: AnnotationHandle, snap: AnnotationItem, to loc: CGPoint, in items: inout [AnnotationItem], index idx: Int) {
        switch h {
        case .rotate:
            let c = snap.center
            var deg = atan2(loc.y - c.y, loc.x - c.x) * 180 / .pi + 90
            deg = AnnotationItem.normalize(deg)
            let snapped = (deg / 15).rounded() * 15
            if abs(deg - snapped) < 4 { deg = snapped }
            items[idx].rotationAngle = deg
        case .start:
            items[idx].startPoint = loc
        case .end:
            items[idx].endPoint = loc
        case .corner(let left, let top):
            let local = snap.unrotated(loc)
            let minX = min(snap.startPoint.x, snap.endPoint.x), maxX = max(snap.startPoint.x, snap.endPoint.x)
            let minY = min(snap.startPoint.y, snap.endPoint.y), maxY = max(snap.startPoint.y, snap.endPoint.y)
            let x0 = left ? local.x : minX, x1 = left ? maxX : local.x
            let y0 = top ? local.y : minY, y1 = top ? maxY : local.y
            items[idx].startPoint = CGPoint(x: x0, y: y0)
            items[idx].endPoint = CGPoint(x: x1, y: y1)
        }
    }
}
