import SwiftUI
import AppKit

/// Общее форматирование числовых подписей редактора
public enum AnnotationFormatting {
    public static func zoomLabel(_ factor: Double) -> String {
        let clamped = factor > 0 ? factor : 2.0
        let roundedTenths = (clamped * 10.0).rounded() / 10.0
        if abs(roundedTenths - roundedTenths.rounded()) < 0.01 {
            return "\(Int(roundedTenths.rounded()))×"
        }
        return String(format: "%.1f×", roundedTenths)
    }
}

/// Единые спецификации заголовка окна macOS для живого предпросмотра и рендера
enum WindowTitlebarSpec {
    static let height: CGFloat = 30
    static let buttonDiameter: CGFloat = 12
    static let buttonSpacing: CGFloat = 8
    static let leadingInset: CGFloat = 13
    static let backgroundWhite: CGFloat = 0.18
    static let borderWhiteAlpha: CGFloat = 0.18
    static let trafficLightRGB: [(r: Double, g: Double, b: Double)] = [
        (255.0 / 255.0, 95.0 / 255.0, 86.0 / 255.0),
        (255.0 / 255.0, 189.0 / 255.0, 46.0 / 255.0),
        (39.0 / 255.0, 201.0 / 255.0, 63.0 / 255.0)
    ]
}

/// Общая геометрия фигур для SwiftUI Canvas и CoreGraphics-рендерера
enum AnnotationGeometry {
    static func itemRect(_ item: AnnotationItem) -> CGRect {
        CGRect(
            x: min(item.startPoint.x, item.endPoint.x),
            y: min(item.startPoint.y, item.endPoint.y),
            width: abs(item.startPoint.x - item.endPoint.x),
            height: abs(item.startPoint.y - item.endPoint.y)
        )
    }

    static func clampedCornerRadius(_ desired: CGFloat, in rect: CGRect) -> CGFloat {
        max(0, min(desired, min(rect.width, rect.height) / 2.0))
    }

    static func magnifierCircleRect(for rect: CGRect) -> CGRect {
        let radius = max(min(rect.width, rect.height) / 2.0, 16.0)
        return CGRect(
            x: rect.midX - radius,
            y: rect.midY - radius,
            width: radius * 2.0,
            height: radius * 2.0
        )
    }

    static func arrowHeadEndpoints(
        tip: CGPoint,
        from controlOrStart: CGPoint,
        headLength: CGFloat,
        spread: CGFloat = .pi / 6
    ) -> (CGPoint, CGPoint) {
        let angle = atan2(tip.y - controlOrStart.y, tip.x - controlOrStart.x)
        let tip1 = CGPoint(x: tip.x - headLength * cos(angle - spread), y: tip.y - headLength * sin(angle - spread))
        let tip2 = CGPoint(x: tip.x - headLength * cos(angle + spread), y: tip.y - headLength * sin(angle + spread))
        return (tip1, tip2)
    }

    static func curvedControlPoint(start: CGPoint, end: CGPoint, curveOffset: CGFloat) -> CGPoint? {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let len = hypot(dx, dy)
        guard len > 1 else { return nil }
        let normal = CGPoint(x: -dy / len, y: dx / len)
        let mid = CGPoint(x: (start.x + end.x) / 2.0, y: (start.y + end.y) / 2.0)
        return CGPoint(x: mid.x + normal.x * curveOffset, y: mid.y + normal.y * curveOffset)
    }
}
