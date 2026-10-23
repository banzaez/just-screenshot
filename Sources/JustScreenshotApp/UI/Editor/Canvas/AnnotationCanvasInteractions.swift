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
        let ordered = handlePositions(of: item).sorted { a, _ in a.0 == .rotate }
        for (h, pos) in ordered where hypot(local.x - pos.x, local.y - pos.y) <= handleHitRadius {
            return h
        }
        return nil
    }
    
    /// Применяет ручку к копии элемента (без мутации массива модели)
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
            let local = snap.unrotated(loc)
            let minX = min(snap.startPoint.x, snap.endPoint.x), maxX = max(snap.startPoint.x, snap.endPoint.x)
            let minY = min(snap.startPoint.y, snap.endPoint.y), maxY = max(snap.startPoint.y, snap.endPoint.y)
            let x0 = left ? local.x : minX, x1 = left ? maxX : local.x
            let y0 = top ? local.y : minY, y1 = top ? maxY : local.y
            item.startPoint = CGPoint(x: x0, y: y0)
            item.endPoint = CGPoint(x: x1, y: y1)
        }
        return item
    }
}
