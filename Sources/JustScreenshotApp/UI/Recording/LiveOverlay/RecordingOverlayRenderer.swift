import Cocoa

/// Отрисовщик визуальных эффектов оверлея записи: рамка области, круги кликов (ripples) и плашка клавиш (keystrokes)
@MainActor
enum RecordingOverlayRenderer {
    struct ClickRipple: Sendable {
        let center: CGPoint
        let startTime: Date
    }
    
    struct KeystrokeInfo: Sendable {
        let text: String
        let startTime: Date
    }
    
    static func drawBorder(bounds: CGRect, in context: CGContext) {
        // Красная пульсирующая/яркая рамка вокруг записываемой области
        let insetRect = bounds.insetBy(dx: 1.5, dy: 1.5)
        context.setStrokeColor(CGColor(red: 1.0, green: 0.22, blue: 0.22, alpha: 0.9))
        context.setLineWidth(3.0)
        
        let path = CGPath(roundedRect: insetRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        context.addPath(path)
        context.strokePath()
        
        // Маленькие маркеры по 4 углам для визуального акцента
        let cornerLen: CGFloat = 16.0
        context.setLineWidth(4.0)
        context.setStrokeColor(CGColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0))
        
        // Нижний левый угол
        context.move(to: CGPoint(x: bounds.minX + 1.5, y: bounds.minY + cornerLen))
        context.addLine(to: CGPoint(x: bounds.minX + 1.5, y: bounds.minY + 1.5))
        context.addLine(to: CGPoint(x: bounds.minX + cornerLen, y: bounds.minY + 1.5))
        
        // Нижний правый угол
        context.move(to: CGPoint(x: bounds.maxX - cornerLen, y: bounds.minY + 1.5))
        context.addLine(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.minY + 1.5))
        context.addLine(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.minY + cornerLen))
        
        // Верхний правый угол
        context.move(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.maxY - cornerLen))
        context.addLine(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.maxY - 1.5))
        context.addLine(to: CGPoint(x: bounds.maxX - cornerLen, y: bounds.maxY - 1.5))
        
        // Верхний левый угол
        context.move(to: CGPoint(x: bounds.minX + cornerLen, y: bounds.maxY - 1.5))
        context.addLine(to: CGPoint(x: bounds.minX + 1.5, y: bounds.maxY - 1.5))
        context.addLine(to: CGPoint(x: bounds.minX + 1.5, y: bounds.maxY - cornerLen))
        
        context.strokePath()
    }
    
    static func drawRipples(_ ripples: [ClickRipple], now: Date, in context: CGContext) {
        for ripple in ripples {
            let progress = CGFloat(min(1.0, now.timeIntervalSince(ripple.startTime) / 0.45))
            let radius = 8.0 + progress * 24.0
            let alpha = 1.0 - progress
            
            let rect = CGRect(x: ripple.center.x - radius, y: ripple.center.y - radius, width: radius * 2, height: radius * 2)
            context.setStrokeColor(CGColor(red: 1.0, green: 0.85, blue: 0.2, alpha: alpha * 0.85))
            context.setFillColor(CGColor(red: 1.0, green: 0.85, blue: 0.2, alpha: alpha * 0.25))
            context.setLineWidth(2.5)
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
        }
    }
    
    static func drawKeystrokeBadge(text: String, alpha: CGFloat, bounds: CGRect, in context: CGContext) {
        let nsText = text as NSString
        let font = NSFont.systemFont(ofSize: 15, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(alpha)
        ]
        let textSize = nsText.size(withAttributes: attrs)
        let badgeRect = CGRect(
            x: bounds.midX - textSize.width / 2 - 14,
            y: max(16, bounds.minY + 20),
            width: textSize.width + 28,
            height: textSize.height + 14
        )
        let path = CGPath(roundedRect: badgeRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: CGColor(gray: 0, alpha: 0.5 * alpha))
        context.setFillColor(CGColor(gray: 0.08, alpha: 0.88 * alpha))
        context.addPath(path)
        context.fillPath()
        
        context.setStrokeColor(CGColor(gray: 1.0, alpha: 0.25 * alpha))
        context.setLineWidth(1.0)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
        
        nsText.draw(at: CGPoint(x: badgeRect.origin.x + 14, y: badgeRect.origin.y + 7), withAttributes: attrs)
    }
}
