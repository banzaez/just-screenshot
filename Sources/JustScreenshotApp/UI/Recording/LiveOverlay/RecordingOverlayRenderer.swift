import Cocoa

/// Отрисовщик визуальных эффектов оверлея записи: рамка области, круги кликов (ripples) и плашка клавиш (keystrokes)
@MainActor
enum RecordingOverlayRenderer {
    struct ClickRipple: Sendable {
        let center: CGPoint
        let startTime: Date
        let isRightClick: Bool
        
        init(center: CGPoint, startTime: Date = Date(), isRightClick: Bool = false) {
            self.center = center
            self.startTime = startTime
            self.isRightClick = isRightClick
        }
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
            
            if ripple.isRightClick {
                // ПКМ: Кораллово-красный двойной импульс
                context.setStrokeColor(CGColor(red: 1.0, green: 0.25, blue: 0.35, alpha: alpha * 0.95))
                context.setFillColor(CGColor(red: 1.0, green: 0.25, blue: 0.35, alpha: alpha * 0.35))
                context.setLineWidth(3.0)
                context.fillEllipse(in: rect)
                context.strokeEllipse(in: rect)
                
                // Внутреннее контрастное кольцо для ПКМ
                let innerR = max(2.0, radius * 0.45)
                let innerRect = CGRect(x: ripple.center.x - innerR, y: ripple.center.y - innerR, width: innerR * 2, height: innerR * 2)
                context.setStrokeColor(CGColor(gray: 1.0, alpha: alpha * 0.95))
                context.setLineWidth(1.5)
                context.strokeEllipse(in: innerRect)
            } else {
                // ЛКМ: Яркий лазурно-синий круговой импульс
                context.setStrokeColor(CGColor(red: 0.15, green: 0.65, blue: 1.0, alpha: alpha * 0.95))
                context.setFillColor(CGColor(red: 0.15, green: 0.65, blue: 1.0, alpha: alpha * 0.25))
                context.setLineWidth(2.5)
                context.fillEllipse(in: rect)
                context.strokeEllipse(in: rect)
            }
        }
    }
    
    static func drawKeystrokeBadge(text: String, alpha: CGFloat, bounds: CGRect, in context: CGContext) {
        let nsText = text as NSString
        let font = NSFont.systemFont(ofSize: 18, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(alpha)
        ]
        let textSize = nsText.size(withAttributes: attrs)
        let horizontalPadding: CGFloat = 20
        let verticalPadding: CGFloat = 12
        let badgeWidth = textSize.width + horizontalPadding * 2
        let badgeHeight = textSize.height + verticalPadding * 2
        let badgeRect = CGRect(
            x: bounds.midX - badgeWidth / 2,
            y: max(20, bounds.minY + 36),
            width: badgeWidth,
            height: badgeHeight
        )
        let path = CGPath(roundedRect: badgeRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -3), blur: 12, color: CGColor(gray: 0, alpha: 0.65 * alpha))
        context.setFillColor(CGColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 0.94 * alpha))
        context.addPath(path)
        context.fillPath()
        
        context.setStrokeColor(CGColor(gray: 1.0, alpha: 0.35 * alpha))
        context.setLineWidth(1.5)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
        
        let textPoint = CGPoint(
            x: badgeRect.origin.x + horizontalPadding,
            y: badgeRect.origin.y + verticalPadding - 1
        )
        nsText.draw(at: textPoint, withAttributes: attrs)
    }
}
