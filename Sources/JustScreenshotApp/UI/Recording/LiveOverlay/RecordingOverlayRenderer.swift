import Cocoa

/// Отрисовщик визуальных эффектов оверлея записи: круги кликов (ripples) и плашка клавиш (keystrokes)
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

    private static let keystrokeBadgeFont = NSFont.systemFont(ofSize: 18, weight: .bold)

    static func drawRipples(_ ripples: [ClickRipple], now: Date, in context: CGContext) {
        for ripple in ripples {
            let rawProgress = now.timeIntervalSince(ripple.startTime) / 0.45
            let progress = CGFloat(min(1.0, max(0.0, rawProgress)))
            let radius = 8.0 + progress * 24.0
            let alpha = max(0, 1.0 - progress)

            let rect = CGRect(
                x: ripple.center.x - radius,
                y: ripple.center.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            if ripple.isRightClick {
                context.setStrokeColor(CGColor(red: 1.0, green: 0.25, blue: 0.35, alpha: alpha * 0.95))
                context.setFillColor(CGColor(red: 1.0, green: 0.25, blue: 0.35, alpha: alpha * 0.35))
                context.setLineWidth(3.0)
                context.fillEllipse(in: rect)
                context.strokeEllipse(in: rect)

                let innerR = max(2.0, radius * 0.45)
                let innerRect = CGRect(
                    x: ripple.center.x - innerR,
                    y: ripple.center.y - innerR,
                    width: innerR * 2,
                    height: innerR * 2
                )
                context.setStrokeColor(CGColor(gray: 1.0, alpha: alpha * 0.95))
                context.setLineWidth(1.5)
                context.strokeEllipse(in: innerRect)
            } else {
                context.setStrokeColor(CGColor(red: 0.15, green: 0.65, blue: 1.0, alpha: alpha * 0.95))
                context.setFillColor(CGColor(red: 0.15, green: 0.65, blue: 1.0, alpha: alpha * 0.25))
                context.setLineWidth(2.5)
                context.fillEllipse(in: rect)
                context.strokeEllipse(in: rect)
            }
        }
    }

    static func drawKeystrokeBadge(text: String, alpha: CGFloat, bounds: CGRect, in context: CGContext) {
        let clampedAlpha = min(1.0, max(0.0, alpha))
        guard clampedAlpha > 0.001, bounds.width > 12, bounds.height > 12 else { return }

        let nsText = text as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: keystrokeBadgeFont,
            .foregroundColor: NSColor.white.withAlphaComponent(clampedAlpha)
        ]
        let textSize = nsText.size(withAttributes: attrs)
        let horizontalPadding: CGFloat = 20
        let verticalPadding: CGFloat = 12
        let rawBadgeWidth = textSize.width + horizontalPadding * 2
        let rawBadgeHeight = textSize.height + verticalPadding * 2
        let badgeWidth = min(max(24, bounds.width - 16), rawBadgeWidth)
        let badgeHeight = min(max(20, bounds.height - 16), rawBadgeHeight)

        let minX = bounds.minX + 8
        let maxX = max(minX, bounds.maxX - badgeWidth - 8)
        let badgeX = min(max(minX, bounds.midX - badgeWidth / 2), maxX)
        let minY = bounds.minY + 8
        let maxY = max(minY, bounds.maxY - badgeHeight - 8)
        let badgeY = min(max(minY, bounds.minY + 36), maxY)

        let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)
        let cornerRadius = min(10.0, min(badgeRect.width, badgeRect.height) / 2.0)
        let path = CGPath(roundedRect: badgeRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -3), blur: 12, color: CGColor(gray: 0, alpha: 0.65 * clampedAlpha))
        context.setFillColor(CGColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 0.94 * clampedAlpha))
        context.addPath(path)
        context.fillPath()

        context.setStrokeColor(CGColor(gray: 1.0, alpha: 0.35 * clampedAlpha))
        context.setLineWidth(1.5)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()

        let textRect = CGRect(
            x: badgeRect.origin.x + horizontalPadding,
            y: badgeRect.origin.y + max(0, (badgeHeight - textSize.height) / 2) - 1,
            width: max(1, badgeWidth - horizontalPadding * 2),
            height: textSize.height + 2
        )
        nsText.draw(in: textRect, withAttributes: attrs)
    }
}
