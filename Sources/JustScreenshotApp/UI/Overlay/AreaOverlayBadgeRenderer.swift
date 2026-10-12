import AppKit

/// Отрисовка бейджей с размерами, перекрестья и подсказок в оверлее захвата
@MainActor
enum AreaOverlayBadgeRenderer {
    static func drawBadge(text: String, at rect: CGRect, in context: CGContext) {
        let nsText = text as NSString
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = nsText.size(withAttributes: attrs)
        let badgeRect = CGRect(
            x: rect.midX - textSize.width / 2 - 10,
            y: max(rect.minY - 26, 12),
            width: textSize.width + 20,
            height: textSize.height + 8
        )
        
        let badgePath = CGPath(roundedRect: badgeRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        context.setFillColor(CGColor(gray: 0.08, alpha: 0.92))
        context.addPath(badgePath)
        context.fillPath()
        
        nsText.draw(at: NSPoint(x: badgeRect.origin.x + 10, y: badgeRect.origin.y + 4), withAttributes: attrs)
    }

    static func drawCrosshairBadge(point: CGPoint, bounds: CGRect, sampler: ScreenPixelSampler, in context: CGContext) {
        let screenHeight = bounds.height
        let screenPoint = CGPoint(x: point.x, y: screenHeight - point.y)
        let hex = sampler.getPixelHex(at: screenPoint, viewBounds: bounds) ?? "#------"
        
        let text = "X: \(Int(point.x))  Y: \(Int(screenPoint.y))  🎨 \(hex)" as NSString
        let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attrs)
        let badgeRect = CGRect(
            x: min(max(point.x + 14, 10), bounds.width - textSize.width - 24),
            y: min(max(point.y + 14, 10), bounds.height - textSize.height - 18),
            width: textSize.width + 16,
            height: textSize.height + 6
        )
        let path = CGPath(roundedRect: badgeRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
        context.setFillColor(CGColor(gray: 0.08, alpha: 0.92))
        context.addPath(path)
        context.fillPath()
        text.draw(at: CGPoint(x: badgeRect.origin.x + 8, y: badgeRect.origin.y + 3), withAttributes: attrs)
    }

    static func drawTopTip(mode: OverlayMode, bounds: CGRect, in context: CGContext) {
        let tipText: NSString
        switch mode {
        case .windowOnly:
            tipText = L("overlay.window_tip") as NSString
        case .areaOnly:
            tipText = L("overlay.area_tip") as NSString
        case .recordingArea:
            tipText = L("overlay.record_tip") as NSString
        }
        
        let tipFont = NSFont.systemFont(ofSize: 13, weight: .medium)
        let tipAttrs: [NSAttributedString.Key: Any] = [
            .font: tipFont,
            .foregroundColor: NSColor.white
        ]
        let tipSize = tipText.size(withAttributes: tipAttrs)
        let tipRect = CGRect(
            x: bounds.midX - tipSize.width / 2 - 16,
            y: bounds.height - 56,
            width: tipSize.width + 32,
            height: tipSize.height + 12
        )
        
        let tipPath = CGPath(roundedRect: tipRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
        context.setFillColor(CGColor(gray: 0.1, alpha: 0.88))
        context.addPath(tipPath)
        context.fillPath()
        
        tipText.draw(at: NSPoint(x: tipRect.origin.x + 16, y: tipRect.origin.y + 6), withAttributes: tipAttrs)
    }
}
