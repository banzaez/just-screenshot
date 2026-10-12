import SwiftUI
import AppKit

/// Инструменты аннотаций Just Screenshot
public enum AnnotationTool: String, CaseIterable, Identifiable, Sendable {
    case select = "Выбор / Перемещение"
    case arrow = "Стрелка"
    case rectangle = "Прямоугольник"
    case roundedRect = "Скругленный"
    case ellipse = "Овал"
    case text = "Текст"
    case counter = "Счетчик (1-2-3)"
    case blur = "Размытие"
    case highlighter = "Маркер"
    case magnifier = "Лупа"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "square"
        case .roundedRect: return "square.dashed"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .counter: return "1.circle.fill"
        case .blur: return "checkerboard.rectangle"
        case .highlighter: return "highlighter"
        case .magnifier: return "plus.magnifyingglass"
        }
    }
    
    @MainActor
    public var localizedTitle: String {
        switch self {
        case .select: return L("editor.tool.select")
        case .arrow: return L("editor.tool.arrow")
        case .rectangle: return L("editor.tool.rectangle")
        case .roundedRect: return L("editor.tool.rounded_rect")
        case .ellipse: return L("editor.tool.ellipse")
        case .text: return L("editor.tool.text")
        case .counter: return L("editor.tool.counter")
        case .blur: return L("editor.tool.blur")
        case .highlighter: return L("editor.tool.highlighter")
        case .magnifier: return L("editor.tool.magnifier")
        }
    }
}

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
        scaleFactor: Double = 1.0
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
    }
    
    /// Линейные элементы (стрелка, маркер) поворачиваются изменением концов отрезка
    public var isLineLike: Bool { tool == .arrow || tool == .highlighter }
    /// Элементы, у которых можно тянуть углы
    public var isRectLike: Bool { tool == .rectangle || tool == .roundedRect || tool == .blur || tool == .ellipse || tool == .magnifier }
    public var supportsRotation: Bool { tool != .counter && tool != .select && tool != .blur && tool != .magnifier }
    
    /// Измеренный размер текстового блока (совпадает с рендером)
    public var textSize: CGSize {
        let str = (text.isEmpty ? "Текст" : text) as NSString
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
        case .arrow, .highlighter:
            let minX = min(startPoint.x, endPoint.x), minY = min(startPoint.y, endPoint.y)
            return CGRect(x: minX, y: minY, width: abs(startPoint.x - endPoint.x), height: abs(startPoint.y - endPoint.y))
        case .rectangle, .roundedRect, .blur, .ellipse, .magnifier:
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
        let a = startPoint, b = endPoint
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
        l.rotationAngle == r.rotationAngle && l.scaleFactor == r.scaleFactor
    }
}
