import SwiftUI
import AppKit

/// Отдельный элемент аннотации с поддержкой смещения, поворота и редактирования
public struct AnnotationItem: Identifiable, Sendable {
    public let id: UUID
    public var tool: AnnotationTool
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var color: Color
    public var lineWidth: CGFloat
    public var text: String
    public var counterNumber: Int
    public var fontSize: CGFloat
    public var rotationAngle: Double // в градусах (для не-линейных элементов)
    public var scaleFactor: Double
    public var curveOffset: CGFloat // смещение контрольной точки для изогнутых стрелок
    
    public init(
        id: UUID = UUID(),
        tool: AnnotationTool,
        startPoint: CGPoint,
        endPoint: CGPoint,
        color: Color = .red,
        lineWidth: CGFloat = 4.0,
        text: String = "",
        counterNumber: Int = 1,
        fontSize: CGFloat = 20.0,
        rotationAngle: Double = 0.0,
        scaleFactor: Double = 1.0,
        curveOffset: CGFloat = 0.0
    ) {
        self.id = id
        self.tool = tool
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.color = color
        self.lineWidth = lineWidth
        self.text = text
        self.counterNumber = counterNumber
        self.fontSize = fontSize
        self.rotationAngle = rotationAngle
        self.scaleFactor = scaleFactor
        self.curveOffset = curveOffset
    }
    
    /// Линейные элементы (стрелка, маркер) поворачиваются изменением концов отрезка
    public var isLineLike: Bool { tool == .arrow || tool == .curvedArrow || tool == .highlighter }
    /// Элементы, у которых можно тянуть углы
    public var isRectLike: Bool { tool == .rectangle || tool == .roundedRect || tool == .blur || tool == .spotlight || tool == .ellipse || tool == .magnifier }
    public var supportsRotation: Bool { tool != .counter && tool != .select && tool != .blur && tool != .spotlight && tool != .magnifier }
    
    /// Точка вершины дуги изогнутой стрелки (t = 0.5)
    public var curveApex: CGPoint {
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let len = hypot(dx, dy)
        guard len > 1 else { return center }
        let normal = CGPoint(x: -dy / len, y: dx / len)
        let mid = CGPoint(x: (startPoint.x + endPoint.x) / 2, y: (startPoint.y + endPoint.y) / 2)
        return CGPoint(x: mid.x + normal.x * curveOffset * 0.5, y: mid.y + normal.y * curveOffset * 0.5)
    }
    
    /// Измеренный размер текстового блока (совпадает с рендером)
    public var textSize: CGSize {
        let str = (text.isEmpty ? "Aa" : text) as NSString
        let s = str.size(withAttributes: [.font: NSFont.boldSystemFont(ofSize: fontSize)])
        return CGSize(width: ceil(s.width), height: ceil(s.height))
    }
    
    public var center: CGPoint {
        switch tool {
        case .counter:
            return startPoint
        case .text:
            let s = textSize
            return CGPoint(x: startPoint.x + s.width / 2, y: startPoint.y + s.height / 2)
        case .curvedArrow:
            let apex = curveApex
            let mid = CGPoint(x: (startPoint.x + endPoint.x) / 2, y: (startPoint.y + endPoint.y) / 2)
            return CGPoint(x: (mid.x + apex.x) / 2, y: (mid.y + apex.y) / 2)
        default:
            return CGPoint(x: (startPoint.x + endPoint.x) / 2, y: (startPoint.y + endPoint.y) / 2)
        }
    }
    
    /// Рамка выделения для не-линейных элементов (в системе элемента, без поворота)
    public var boundingBox: CGRect {
        switch tool {
        case .select:
            return .zero
        case .counter:
            return CGRect(x: startPoint.x - 19, y: startPoint.y - 19, width: 38, height: 38)
        case .text:
            let s = textSize
            return CGRect(x: startPoint.x - 4, y: startPoint.y - 2, width: s.width + 8, height: s.height + 4)
        case .arrow, .curvedArrow, .highlighter:
            var minX = min(startPoint.x, endPoint.x), maxX = max(startPoint.x, endPoint.x)
            var minY = min(startPoint.y, endPoint.y), maxY = max(startPoint.y, endPoint.y)
            if tool == .curvedArrow {
                let apex = curveApex
                minX = min(minX, apex.x)
                maxX = max(maxX, apex.x)
                minY = min(minY, apex.y)
                maxY = max(maxY, apex.y)
            }
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        case .rectangle, .roundedRect, .blur, .spotlight, .ellipse, .magnifier:
            let minX = min(startPoint.x, endPoint.x), minY = min(startPoint.y, endPoint.y)
            let w = abs(startPoint.x - endPoint.x), h = abs(startPoint.y - endPoint.y)
            return CGRect(x: minX - 3, y: minY - 3, width: w + 6, height: h + 6)
        }
    }
    
    /// Половина толщины зоны вокруг линии, считающаяся самим элементом
    public var lineHalfThickness: CGFloat {
        tool == .highlighter ? lineWidth * 2 : max(lineWidth / 2, 2)
    }
    
    /// Угол для отображения в интерфейсе (-180...180)
    public var displayAngle: Double {
        if isLineLike {
            return atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x) * 180 / .pi
        }
        return AnnotationItem.normalize(rotationAngle)
    }
    
    public static func normalize(_ deg: Double) -> Double {
        var d = deg.truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d <= -180 { d += 360 }
        return d
    }
    
    /// Установка абсолютного угла поворота
    public mutating func setAngle(_ target: Double) {
        if isLineLike {
            rotate(by: target - displayAngle)
        } else {
            rotationAngle = AnnotationItem.normalize(target)
        }
    }
    
    /// Относительный поворот: линии вращают концы, остальные — угол
    public mutating func rotate(by delta: Double) {
        if isLineLike {
            let c = center
            let rad = delta * .pi / 180
            let cosA = cos(rad), sinA = sin(rad)
            func rot(_ p: CGPoint) -> CGPoint {
                let dx = p.x - c.x, dy = p.y - c.y
                return CGPoint(x: c.x + dx * cosA - dy * sinA, y: c.y + dx * sinA + dy * cosA)
            }
            startPoint = rot(startPoint)
            endPoint = rot(endPoint)
        } else {
            rotationAngle = AnnotationItem.normalize(rotationAngle + delta)
        }
    }
    
    /// Перевод точки в локальную (неповернутую) систему элемента
    public func unrotated(_ point: CGPoint) -> CGPoint {
        guard rotationAngle != 0, !isLineLike else { return point }
        let rad = -rotationAngle * .pi / 180
        let c = center
        let dx = point.x - c.x, dy = point.y - c.y
        return CGPoint(x: c.x + dx * cos(rad) - dy * sin(rad), y: c.y + dx * sin(rad) + dy * cos(rad))
    }
    
    /// Точный хит-тест: расстояние до отрезка для линий, поворот учтён для остальных
    public func contains(point: CGPoint, tolerance: CGFloat = 6) -> Bool {
        if isLineLike {
            return distanceToSegment(point) <= lineHalfThickness + tolerance
        }
        return boundingBox.insetBy(dx: -tolerance, dy: -tolerance).contains(unrotated(point))
    }
    
    private func distanceToSegment(_ p: CGPoint) -> CGFloat {
        if tool == .curvedArrow && curveOffset != 0 {
            let apex = curveApex
            let d1 = distToLine(p: p, a: startPoint, b: apex)
            let d2 = distToLine(p: p, a: apex, b: endPoint)
            return min(d1, d2)
        }
        return distToLine(p: p, a: startPoint, b: endPoint)
    }
    
    private func distToLine(p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}

extension AnnotationItem: Equatable {
    public static func == (l: AnnotationItem, r: AnnotationItem) -> Bool {
        l.id == r.id && l.tool == r.tool && l.startPoint == r.startPoint && l.endPoint == r.endPoint &&
        l.color == r.color && l.lineWidth == r.lineWidth && l.text == r.text &&
        l.counterNumber == r.counterNumber && l.fontSize == r.fontSize &&
        l.rotationAngle == r.rotationAngle && l.scaleFactor == r.scaleFactor &&
        l.curveOffset == r.curveOffset
    }
}
