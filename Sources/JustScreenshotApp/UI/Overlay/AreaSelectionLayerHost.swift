import Cocoa
import QuartzCore

/// Владеет CALayer оверлея выбора: dim / border / crosshair / badge / tip
final class AreaSelectionLayerHost {
    private let dimLayer = CALayer()
    private let maskLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let crosshairLayer = CAShapeLayer()
    private let badgeBackgroundLayer = CAShapeLayer()
    private let badgeTextLayer = CATextLayer()
    private let tipBackgroundLayer = CAShapeLayer()
    private let tipTextLayer = CATextLayer()
    
    private let crosshairArmLength: CGFloat = 48
    private let crosshairGap: CGFloat = 6
    
    struct Snapshot {
        var bounds: CGRect
        var mode: OverlayMode
        var hole: CGRect?
        var borderRect: CGRect?
        var borderColor: CGColor
        var borderWidth: CGFloat
        var badge: String?
        var badgeNear: CGRect?
        var badgeOffset: CGPoint?
        var crosshairPoint: CGPoint?
        var tipText: String
        var scale: CGFloat
    }
    
    func install(in root: CALayer) {
        root.backgroundColor = NSColor.clear.cgColor
        
        dimLayer.backgroundColor = CGColor(gray: 0, alpha: 0.35)
        maskLayer.fillColor = NSColor.white.cgColor
        maskLayer.fillRule = .evenOdd
        dimLayer.mask = maskLayer
        root.addSublayer(dimLayer)
        
        borderLayer.fillColor = nil
        borderLayer.lineWidth = 2
        borderLayer.lineJoin = .round
        root.addSublayer(borderLayer)
        
        crosshairLayer.strokeColor = CGColor(gray: 1, alpha: 0.45)
        crosshairLayer.fillColor = nil
        crosshairLayer.lineWidth = 1
        crosshairLayer.lineDashPattern = [4, 4]
        root.addSublayer(crosshairLayer)
        
        badgeBackgroundLayer.fillColor = CGColor(gray: 0.08, alpha: 0.92)
        root.addSublayer(badgeBackgroundLayer)
        configureTextLayer(badgeTextLayer, font: .monospacedSystemFont(ofSize: 11, weight: .bold), size: 11, scale: 2)
        root.addSublayer(badgeTextLayer)
        
        tipBackgroundLayer.fillColor = CGColor(gray: 0.1, alpha: 0.88)
        root.addSublayer(tipBackgroundLayer)
        configureTextLayer(tipTextLayer, font: .systemFont(ofSize: 13, weight: .medium), size: 13, scale: 2)
        root.addSublayer(tipTextLayer)
    }
    
    func apply(snapshot: Snapshot) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        
        applyContentsScale(snapshot.scale)
        dimLayer.frame = snapshot.bounds
        updateDimMask(hole: snapshot.hole, bounds: snapshot.bounds)
        
        borderLayer.strokeColor = snapshot.borderColor
        borderLayer.lineWidth = snapshot.borderWidth
        updateBorder(rect: snapshot.borderRect, rounded: snapshot.mode == .windowOnly)
        updateCrosshair(at: snapshot.crosshairPoint)
        
        if let badge = snapshot.badge, let near = snapshot.badgeNear {
            showBadge(text: badge, near: near, offset: snapshot.badgeOffset, bounds: snapshot.bounds)
        } else {
            badgeBackgroundLayer.isHidden = true
            badgeTextLayer.isHidden = true
        }
        
        refreshTip(text: snapshot.tipText, bounds: snapshot.bounds)
    }
    
    private func configureTextLayer(_ layer: CATextLayer, font: NSFont, size: CGFloat, scale: CGFloat) {
        layer.contentsScale = scale
        layer.foregroundColor = NSColor.white.cgColor
        layer.font = font
        layer.fontSize = size
        layer.alignmentMode = .left
        layer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
    }
    
    private func applyContentsScale(_ scale: CGFloat) {
        for layer in [dimLayer, maskLayer, borderLayer, crosshairLayer, badgeBackgroundLayer, tipBackgroundLayer] {
            layer.contentsScale = scale
            layer.actions = [
                "bounds": NSNull(),
                "position": NSNull(),
                "path": NSNull(),
                "opacity": NSNull(),
                "hidden": NSNull()
            ]
        }
        badgeTextLayer.contentsScale = scale
        tipTextLayer.contentsScale = scale
    }
    
    private func refreshTip(text: String, bounds: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium)
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let tipRect = CGRect(
            x: bounds.midX - size.width / 2 - 16,
            y: bounds.height - 56,
            width: size.width + 32,
            height: size.height + 12
        )
        tipBackgroundLayer.path = CGPath(roundedRect: tipRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
        tipTextLayer.string = text
        tipTextLayer.frame = CGRect(
            x: tipRect.origin.x + 16,
            y: tipRect.origin.y + 6,
            width: size.width,
            height: size.height
        )
    }
    
    private func updateDimMask(hole: CGRect?, bounds: CGRect) {
        let path = CGMutablePath()
        path.addRect(bounds)
        if let hole, hole.width > 0, hole.height > 0 {
            path.addRect(hole)
        }
        maskLayer.path = path
        maskLayer.frame = bounds
    }
    
    private func updateBorder(rect: CGRect?, rounded: Bool) {
        guard let rect, rect.width > 0, rect.height > 0 else {
            borderLayer.path = nil
            borderLayer.isHidden = true
            return
        }
        borderLayer.isHidden = false
        if rounded {
            borderLayer.path = CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        } else {
            borderLayer.path = CGPath(rect: rect, transform: nil)
        }
    }
    
    private func updateCrosshair(at point: CGPoint?) {
        guard let point else {
            crosshairLayer.path = nil
            crosshairLayer.isHidden = true
            return
        }
        
        crosshairLayer.isHidden = false
        let arm = crosshairArmLength
        let gap = crosshairGap
        let path = CGMutablePath()
        path.move(to: CGPoint(x: point.x - arm, y: point.y))
        path.addLine(to: CGPoint(x: point.x - gap, y: point.y))
        path.move(to: CGPoint(x: point.x + gap, y: point.y))
        path.addLine(to: CGPoint(x: point.x + arm, y: point.y))
        path.move(to: CGPoint(x: point.x, y: point.y - arm))
        path.addLine(to: CGPoint(x: point.x, y: point.y - gap))
        path.move(to: CGPoint(x: point.x, y: point.y + gap))
        path.addLine(to: CGPoint(x: point.x, y: point.y + arm))
        crosshairLayer.path = path
    }
    
    private func showBadge(text: String, near rect: CGRect, offset: CGPoint?, bounds: CGRect) {
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attrs)
        
        let badgeRect: CGRect
        if let offset {
            badgeRect = CGRect(
                x: min(max(rect.origin.x + offset.x, 10), bounds.width - size.width - 24),
                y: min(max(rect.origin.y + offset.y, 10), bounds.height - size.height - 18),
                width: size.width + 16,
                height: size.height + 6
            )
        } else {
            badgeRect = CGRect(
                x: rect.midX - size.width / 2 - 10,
                y: max(rect.minY - 26, 12),
                width: size.width + 20,
                height: size.height + 8
            )
        }
        
        badgeBackgroundLayer.isHidden = false
        badgeTextLayer.isHidden = false
        badgeBackgroundLayer.path = CGPath(
            roundedRect: badgeRect,
            cornerWidth: offset == nil ? 6 : 5,
            cornerHeight: offset == nil ? 6 : 5,
            transform: nil
        )
        badgeTextLayer.string = text
        badgeTextLayer.frame = CGRect(
            x: badgeRect.origin.x + (offset == nil ? 10 : 8),
            y: badgeRect.origin.y + (offset == nil ? 4 : 3),
            width: size.width,
            height: size.height
        )
    }
}
