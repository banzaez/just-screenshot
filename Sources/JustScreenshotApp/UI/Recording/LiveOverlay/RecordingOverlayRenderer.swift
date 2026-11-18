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
