import Cocoa
import QuartzCore

/// Владеет CALayer оверлея выбора: dim / border / crosshair / badge / tip
@MainActor
final class AreaSelectionLayerHost {
    private let dimLayer = CALayer()
    private let maskLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let crosshairLayer = CAShapeLayer()
    private let badgeBackgroundLayer = CAShapeLayer()
    private let badgeTextLayer = CATextLayer()
    private let badgeColorLayer = CAShapeLayer()
    private let loupeContainerLayer = CALayer()
    private let loupeImageLayer = CALayer()
    private let loupeReticleOuterLayer = CAShapeLayer()
    private let loupeReticleInnerLayer = CAShapeLayer()
    private let tipBackgroundLayer = CAShapeLayer()
    private let tipTextLayer = CATextLayer()

    private let crosshairArmLength: CGFloat = 48
    private let crosshairGap: CGFloat = 6
    private let loupeDiameter: CGFloat = 120
    private let loupeGridSide: CGFloat = 15

    private static let badgeFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
    private static let tipFont = NSFont.systemFont(ofSize: 13, weight: .medium)

    struct Snapshot {
        var bounds: CGRect
        var mode: OverlayMode
        var isRoundedBorder: Bool
        var hole: CGRect?
        var borderRect: CGRect?
        var borderColor: CGColor
        var borderWidth: CGFloat
        var badge: String?
        var badgeColor: CGColor?
        var badgeNear: CGRect?
        var badgeOffset: CGPoint?
        var crosshairPoint: CGPoint?
        var loupePoint: CGPoint?
        var loupeImage: CGImage?
        var tipText: String
        var scale: CGFloat
        var topSafeInset: CGFloat = 0
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

        loupeContainerLayer.bounds = CGRect(x: 0, y: 0, width: loupeDiameter, height: loupeDiameter)
        loupeContainerLayer.cornerRadius = loupeDiameter / 2
        loupeContainerLayer.masksToBounds = true
        loupeContainerLayer.borderWidth = 2.5
        loupeContainerLayer.borderColor = CGColor(gray: 1, alpha: 0.92)
        loupeContainerLayer.backgroundColor = CGColor(gray: 0.1, alpha: 1)
        loupeContainerLayer.isHidden = true

        loupeImageLayer.frame = loupeContainerLayer.bounds
        loupeImageLayer.magnificationFilter = .nearest
        loupeImageLayer.minificationFilter = .nearest
        loupeImageLayer.contentsGravity = .resize
        loupeContainerLayer.addSublayer(loupeImageLayer)

        let cellSize = loupeDiameter / loupeGridSide
        let centerCell = CGRect(
            x: (loupeDiameter - cellSize) / 2,
            y: (loupeDiameter - cellSize) / 2,
            width: cellSize,
            height: cellSize
        )
        loupeReticleOuterLayer.fillColor = nil
        loupeReticleOuterLayer.strokeColor = CGColor(gray: 0, alpha: 0.85)
        loupeReticleOuterLayer.lineWidth = 1.5
        loupeReticleOuterLayer.path = CGPath(rect: centerCell.insetBy(dx: -0.75, dy: -0.75), transform: nil)
        loupeContainerLayer.addSublayer(loupeReticleOuterLayer)

        loupeReticleInnerLayer.fillColor = nil
        loupeReticleInnerLayer.strokeColor = CGColor(gray: 1, alpha: 0.95)
        loupeReticleInnerLayer.lineWidth = 1.0
        loupeReticleInnerLayer.path = CGPath(rect: centerCell, transform: nil)
        loupeContainerLayer.addSublayer(loupeReticleInnerLayer)
        root.addSublayer(loupeContainerLayer)

        badgeBackgroundLayer.fillColor = CGColor(gray: 0.08, alpha: 0.92)
        root.addSublayer(badgeBackgroundLayer)
        configureTextLayer(badgeTextLayer, font: Self.badgeFont, size: 11, scale: 2)
        root.addSublayer(badgeTextLayer)
        badgeColorLayer.strokeColor = CGColor(gray: 1, alpha: 0.55)
        badgeColorLayer.lineWidth = 1
        badgeColorLayer.isHidden = true
        root.addSublayer(badgeColorLayer)

        tipBackgroundLayer.fillColor = CGColor(gray: 0.1, alpha: 0.88)
        root.addSublayer(tipBackgroundLayer)
        configureTextLayer(tipTextLayer, font: Self.tipFont, size: 13, scale: 2)
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
        updateBorder(rect: snapshot.borderRect, rounded: snapshot.isRoundedBorder)
        updateCrosshair(at: snapshot.crosshairPoint)
        updateLoupe(at: snapshot.loupePoint, image: snapshot.loupeImage)

        if let badge = snapshot.badge, let near = snapshot.badgeNear {
            showBadge(
                text: badge,
                color: snapshot.badgeColor,
                near: near,
                offset: snapshot.badgeOffset,
                bounds: snapshot.bounds
            )
        } else {
            badgeBackgroundLayer.isHidden = true
            badgeTextLayer.isHidden = true
            badgeColorLayer.isHidden = true
        }

        refreshTip(text: snapshot.tipText, bounds: snapshot.bounds, topSafeInset: snapshot.topSafeInset)
    }

    private func configureTextLayer(_ layer: CATextLayer, font: NSFont, size: CGFloat, scale: CGFloat) {
        layer.contentsScale = scale
        layer.foregroundColor = NSColor.white.cgColor
        layer.font = font
        layer.fontSize = size
        layer.alignmentMode = .left
        layer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
    }

    private var appliedScale: CGFloat = 0
    private var lastTipText: String?
    private var lastTipBounds: CGRect = .zero
    private var lastTipInset: CGFloat = -1
    private var lastMaskBounds: CGRect = .zero
    private var lastHadHole: Bool = true

    private lazy var disabledLayerActions: [String: CAAction] = [
        "bounds": NSNull(),
        "position": NSNull(),
        "path": NSNull(),
        "opacity": NSNull(),
        "hidden": NSNull()
    ]

    private func applyContentsScale(_ scale: CGFloat) {
        let validScale = max(1, scale)
        guard validScale != appliedScale else { return }
        appliedScale = validScale
        for layer in [
            dimLayer,
            maskLayer,
            borderLayer,
            crosshairLayer,
            badgeBackgroundLayer,
            badgeColorLayer,
            loupeContainerLayer,
            loupeImageLayer,
            loupeReticleOuterLayer,
            loupeReticleInnerLayer,
            tipBackgroundLayer
        ] {
            layer.contentsScale = validScale
            layer.actions = disabledLayerActions
        }
        loupeImageLayer.actions = [
            "contents": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
            "hidden": NSNull()
        ]
        badgeTextLayer.contentsScale = validScale
        tipTextLayer.contentsScale = validScale
    }

    private func safeRoundedRectPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
        let r = max(0, min(radius, rect.width / 2, rect.height / 2))
        return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
    }

    private func refreshTip(text: String, bounds: CGRect, topSafeInset: CGFloat) {
        guard text != lastTipText || bounds != lastTipBounds || topSafeInset != lastTipInset else { return }
        lastTipText = text
        lastTipBounds = bounds
        lastTipInset = topSafeInset

        let attrs: [NSAttributedString.Key: Any] = [.font: Self.tipFont]
        let size = (text as NSString).size(withAttributes: attrs)
        let tipW = min(max(40, size.width + 32), max(40, bounds.width - 20))
        let tipH = size.height + 12
        let topMargin = max(topSafeInset + 16, 48)
        let tipY = max(16, bounds.height - topMargin - tipH)
        let tipRect = CGRect(
            x: max(10, bounds.midX - tipW / 2),
            y: tipY,
            width: tipW,
            height: tipH
        )
        // Зажимаем radius <= height / 2, чтобы не нарушать CGPath precondition в macOS 14+
        tipBackgroundLayer.path = safeRoundedRectPath(tipRect, radius: tipH / 2)
        tipTextLayer.string = text
        tipTextLayer.frame = CGRect(
            x: tipRect.origin.x + 16,
            y: tipRect.origin.y + 6,
            width: max(0, tipW - 32),
            height: size.height
        )
    }

    private func updateDimMask(hole: CGRect?, bounds: CGRect) {
        let hasValidHole = (hole?.width ?? 0) > 0 && (hole?.height ?? 0) > 0
        if !hasValidHole && !lastHadHole && bounds == lastMaskBounds {
            return
        }
        lastHadHole = hasValidHole
        lastMaskBounds = bounds

        let path = CGMutablePath()
        path.addRect(bounds)
        if let hole, hasValidHole {
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
            borderLayer.path = safeRoundedRectPath(rect, radius: 10)
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

    private func updateLoupe(at point: CGPoint?, image: CGImage?) {
        guard let point, let image else {
            loupeContainerLayer.isHidden = true
            loupeImageLayer.contents = nil
            return
        }
        loupeContainerLayer.isHidden = false
        loupeContainerLayer.position = point
        loupeImageLayer.contents = image
    }

    private func showBadge(text: String, color: CGColor?, near rect: CGRect, offset: CGPoint?, bounds: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [.font: Self.badgeFont]
        let size = (text as NSString).size(withAttributes: attrs)
        let padX: CGFloat = offset == nil ? 10 : 8
        let padY: CGFloat = offset == nil ? 4 : 3
        let swatchSize: CGFloat = 12
        let swatchGap: CGFloat = 6
        let extraColorWidth = color != nil ? (swatchGap + swatchSize) : 0
        let badgeW = size.width + extraColorWidth + padX * 2
        let badgeH = max(size.height, color != nil ? swatchSize : 0) + padY * 2

        let rawX: CGFloat
        let rawY: CGFloat
        if let offset {
            rawX = rect.origin.x + offset.x
            rawY = rect.origin.y + offset.y
        } else {
            rawX = rect.midX - badgeW / 2
            rawY = rect.minY - badgeH - 8
        }

        let maxX = max(10, bounds.width - badgeW - 10)
        let maxY = max(10, bounds.height - badgeH - 10)
        let badgeRect = CGRect(
            x: min(max(rawX, 10), maxX),
            y: min(max(rawY, 10), maxY),
            width: badgeW,
            height: badgeH
        )

        badgeBackgroundLayer.isHidden = false
        badgeTextLayer.isHidden = false
        badgeBackgroundLayer.path = safeRoundedRectPath(badgeRect, radius: offset == nil ? 6 : 5)
        badgeTextLayer.string = text
        badgeTextLayer.frame = CGRect(
            x: badgeRect.origin.x + padX,
            y: badgeRect.origin.y + (badgeH - size.height) / 2,
            width: size.width,
            height: size.height
        )

        if let color {
            let swatchRect = CGRect(
                x: badgeTextLayer.frame.maxX + swatchGap,
                y: badgeRect.origin.y + (badgeH - swatchSize) / 2,
                width: swatchSize,
                height: swatchSize
            )
            badgeColorLayer.isHidden = false
            badgeColorLayer.fillColor = color
            badgeColorLayer.path = safeRoundedRectPath(swatchRect, radius: 3)
        } else {
            badgeColorLayer.isHidden = true
        }
    }
}
