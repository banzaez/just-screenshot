import Cocoa
import ScreenCaptureKit
import QuartzCore

/// Интерактивный оверлей: затемнение статичным слоем, прицел/рамка — отдельными CALayer.
final class AreaSelectionNSView: NSView {
    private var screen: NSScreen
    private var mode: OverlayMode
    private var visibleWindows: [SCWindow]
    private var onCompleteRect: (CGRect) -> Void
    private var onCompleteWindow: (SCWindow) -> Void
    private var onCancel: () -> Void
    private var onNeedBackgroundSample: (() -> Void)?
    
    private var isDragging = false
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var hoveredWindow: SCWindow?
    private var trackingArea: NSTrackingArea?
    
    private var sampler: ScreenPixelSampler
    private var hasSampler = false
    
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
    
    init(
        frame: NSRect,
        screen: NSScreen,
        mode: OverlayMode,
        visibleWindows: [SCWindow],
        backgroundImage: CGImage? = nil,
        onCompleteRect: @escaping (CGRect) -> Void,
        onCompleteWindow: @escaping (SCWindow) -> Void,
        onCancel: @escaping () -> Void,
        onNeedBackgroundSample: (() -> Void)? = nil
    ) {
        self.screen = screen
        self.mode = mode
        self.visibleWindows = Self.sortedFrontToBack(visibleWindows)
        self.sampler = ScreenPixelSampler(image: backgroundImage)
        self.hasSampler = backgroundImage != nil
        self.onCompleteRect = onCompleteRect
        self.onCompleteWindow = onCompleteWindow
        self.onCancel = onCancel
        self.onNeedBackgroundSample = onNeedBackgroundSample
        super.init(frame: frame)
        
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        setupLayers()
        
        let mouseLoc = NSEvent.mouseLocation
        if NSMouseInRect(mouseLoc, screen.frame, false) {
            currentPoint = NSPoint(
                x: mouseLoc.x - screen.frame.origin.x,
                y: mouseLoc.y - screen.frame.origin.y
            )
        }
        refreshTip()
        syncLayers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reconfigure(
        screen: NSScreen,
        mode: OverlayMode,
        visibleWindows: [SCWindow],
        backgroundImage: CGImage? = nil,
        onCompleteRect: @escaping (CGRect) -> Void,
        onCompleteWindow: @escaping (SCWindow) -> Void,
        onCancel: @escaping () -> Void,
        onNeedBackgroundSample: (() -> Void)? = nil
    ) {
        self.screen = screen
        self.mode = mode
        self.visibleWindows = Self.sortedFrontToBack(visibleWindows)
        self.sampler = ScreenPixelSampler(image: backgroundImage)
        self.hasSampler = backgroundImage != nil
        self.onCompleteRect = onCompleteRect
        self.onCompleteWindow = onCompleteWindow
        self.onCancel = onCancel
        self.onNeedBackgroundSample = onNeedBackgroundSample
        isDragging = false
        startPoint = nil
        hoveredWindow = nil
        
        let mouseLoc = NSEvent.mouseLocation
        if NSMouseInRect(mouseLoc, screen.frame, false) {
            currentPoint = NSPoint(
                x: mouseLoc.x - screen.frame.origin.x,
                y: mouseLoc.y - screen.frame.origin.y
            )
            if mode == .windowOnly {
                hoveredWindow = windowUnderCursor(at: currentPoint!)
            }
        } else {
            currentPoint = nil
        }
        
        applyContentsScale()
        refreshTip()
        syncLayers()
        updateTrackingAreas()
        requestSamplerIfNeeded()
    }
    
    func updateSampler(_ sampler: ScreenPixelSampler) {
        self.sampler = sampler
        hasSampler = true
        guard mode != .windowOnly, !isDragging else { return }
        syncLayers()
    }
    
    func updateVisibleWindows(_ windows: [SCWindow]) {
        visibleWindows = Self.sortedFrontToBack(windows)
        guard mode == .windowOnly else { return }
        if let loc = currentPoint {
            hoveredWindow = windowUnderCursor(at: loc)
        }
        syncLayers()
    }
    
    func updateBackgroundImage(_ image: CGImage) {
        updateSampler(ScreenPixelSampler(image: image))
    }
    
    func resetOverlayState() {
        isHidden = false
        isDragging = false
        startPoint = nil
        currentPoint = nil
        hoveredWindow = nil
        sampler = ScreenPixelSampler(image: nil)
        hasSampler = false
        onNeedBackgroundSample = nil
        onCompleteRect = { _ in }
        onCompleteWindow = { _ in }
        onCancel = {}
        syncLayers()
    }
    
    // MARK: - Layer setup
    
    private func setupLayers() {
        guard let root = layer else { return }
        root.backgroundColor = NSColor.clear.cgColor
        
        dimLayer.backgroundColor = CGColor(gray: 0, alpha: 0.35)
        dimLayer.frame = bounds
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
        
        configureTextLayer(badgeTextLayer, font: .monospacedSystemFont(ofSize: 11, weight: .bold), size: 11)
        root.addSublayer(badgeTextLayer)
        
        tipBackgroundLayer.fillColor = CGColor(gray: 0.1, alpha: 0.88)
        root.addSublayer(tipBackgroundLayer)
        
        configureTextLayer(tipTextLayer, font: .systemFont(ofSize: 13, weight: .medium), size: 13)
        root.addSublayer(tipTextLayer)
        
        applyContentsScale()
    }
    
    private func configureTextLayer(_ layer: CATextLayer, font: NSFont, size: CGFloat) {
        layer.contentsScale = screen.backingScaleFactor
        layer.foregroundColor = NSColor.white.cgColor
        layer.font = font
        layer.fontSize = size
        layer.alignmentMode = .left
        layer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
    }
    
    private func applyContentsScale() {
        let scale = screen.backingScaleFactor
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
    
    override func layout() {
        super.layout()
        dimLayer.frame = bounds
        refreshTip()
        syncLayers()
    }
    
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        applyContentsScale()
    }
    
    // MARK: - Tracking
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }
    
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        requestSamplerIfNeeded()
    }
    
    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        
        if event.modifierFlags.contains(.option), mode != .windowOnly {
            let screenPoint = CGPoint(x: loc.x, y: bounds.height - loc.y)
            if let hex = sampler.getPixelHex(at: screenPoint, viewBounds: bounds) {
                ImageExporter.copyText(hex)
                NSSound(named: "Tink")?.play()
                onCancel()
                return
            }
        }
        
        startPoint = loc
        currentPoint = loc
        isDragging = false
        syncLayers()
    }
    
    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if mode == .windowOnly {
            moveCursor(to: loc)
            return
        }
        currentPoint = loc
        if let start = startPoint, hypot(loc.x - start.x, loc.y - start.y) > 3 {
            isDragging = true
            hoveredWindow = nil
        }
        syncLayers()
    }
    
    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        
        if mode == .windowOnly {
            if let hovered = hoveredWindow {
                startPoint = nil
                currentPoint = nil
                onCompleteWindow(hovered)
                return
            }
            onCancel()
            return
        }
        
        if isDragging, let start = startPoint {
            let rect = selectionRect(from: start, to: loc)
            startPoint = nil
            currentPoint = nil
            isDragging = false
            
            if rect.width > 5 && rect.height > 5 {
                let scRect = quartzRect(fromViewRect: rect)
                isHidden = true
                window?.alphaValue = 0
                CATransaction.flush()
                onCompleteRect(scRect)
                return
            }
        }
        
        startPoint = nil
        currentPoint = nil
        isDragging = false
        onCancel()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        requestSamplerIfNeeded()
        moveCursor(to: convert(event.locationInWindow, from: nil))
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard !isDragging else { return }
        currentPoint = nil
        hoveredWindow = nil
        syncLayers()
    }
    
    override func mouseMoved(with event: NSEvent) {
        moveCursor(to: convert(event.locationInWindow, from: nil))
    }
    
    private func moveCursor(to loc: CGPoint) {
        requestSamplerIfNeeded()
        
        if mode == .windowOnly {
            let next = windowUnderCursor(at: loc)
            let same = next?.windowID == hoveredWindow?.windowID
            currentPoint = loc
            guard !same else { return }
            hoveredWindow = next
            syncLayers()
            return
        }
        
        if let currentPoint, abs(currentPoint.x - loc.x) < 0.5, abs(currentPoint.y - loc.y) < 0.5 {
            return
        }
        currentPoint = loc
        syncLayers()
    }
    
    private func requestSamplerIfNeeded() {
        guard mode == .areaOnly, !hasSampler else { return }
        onNeedBackgroundSample?()
    }
    
    // MARK: - Geometry
    
    private static func sortedFrontToBack(_ windows: [SCWindow]) -> [SCWindow] {
        windows.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.windowLayer != rhs.element.windowLayer {
                    return lhs.element.windowLayer > rhs.element.windowLayer
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
    
    private var primaryDisplayHeight: CGFloat {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? bounds.height
    }
    
    private func windowUnderCursor(at loc: CGPoint) -> SCWindow? {
        let mouse = quartzPoint(fromViewPoint: loc)
        return visibleWindows.first { $0.frame.contains(mouse) }
    }
    
    private func quartzPoint(fromViewPoint loc: CGPoint) -> CGPoint {
        let globalAppKit = CGPoint(
            x: screen.frame.origin.x + loc.x,
            y: screen.frame.origin.y + loc.y
        )
        return CGPoint(x: globalAppKit.x, y: primaryDisplayHeight - globalAppKit.y)
    }
    
    private func appKitRect(for quartzFrame: CGRect) -> CGRect {
        let globalAppKitY = primaryDisplayHeight - quartzFrame.origin.y - quartzFrame.height
        return CGRect(
            x: quartzFrame.origin.x - screen.frame.origin.x,
            y: globalAppKitY - screen.frame.origin.y,
            width: quartzFrame.width,
            height: quartzFrame.height
        )
    }
    
    private func quartzRect(fromViewRect rect: CGRect) -> CGRect {
        let globalAppKitX = screen.frame.origin.x + rect.origin.x
        let globalAppKitY = screen.frame.origin.y + rect.origin.y
        return CGRect(
            x: globalAppKitX,
            y: primaryDisplayHeight - globalAppKitY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
    
    private func selectionRect(from start: CGPoint, to current: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(start.x - current.x),
            height: abs(start.y - current.y)
        )
    }
    
    // MARK: - Layer sync
    
    private func refreshTip() {
        let text = tipText()
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
    
    private func tipText() -> String {
        switch mode {
        case .windowOnly: return L("overlay.window_tip")
        case .areaOnly: return L("overlay.area_tip")
        case .recordingArea: return L("overlay.record_tip")
        }
    }
    
    private func syncLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        
        var hole: CGRect?
        var borderRect: CGRect?
        var badge: String?
        var showCrosshair = false
        
        if mode == .windowOnly, let hovered = hoveredWindow {
            let rect = appKitRect(for: hovered.frame)
            hole = rect
            borderRect = rect
            let title = hovered.owningApplication?.applicationName
                ?? (hovered.title ?? L("overlay.window_fallback"))
            badge = L("overlay.window_badge", title)
            borderLayer.strokeColor = CGColor(red: 0.1, green: 0.7, blue: 1.0, alpha: 1)
            borderLayer.lineWidth = 3
        } else if isDragging, let start = startPoint, let current = currentPoint {
            let rect = selectionRect(from: start, to: current)
            hole = rect
            borderRect = rect
            if mode == .recordingArea {
                badge = L("overlay.record_badge", Int(rect.width), Int(rect.height))
                borderLayer.strokeColor = CGColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1)
            } else {
                badge = L("overlay.area_badge", Int(rect.width), Int(rect.height))
                borderLayer.strokeColor = CGColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1)
            }
            borderLayer.lineWidth = 2
        } else if mode != .windowOnly, currentPoint != nil {
            showCrosshair = true
        }
        
        updateDimMask(hole: hole)
        updateBorder(rect: borderRect)
        updateCrosshair(visible: showCrosshair, at: currentPoint)
        
        if let badge, let borderRect {
            showBadge(text: badge, near: borderRect, offset: nil)
        } else if showCrosshair, let point = currentPoint {
            let screenPoint = CGPoint(x: point.x, y: bounds.height - point.y)
            let hex = sampler.getPixelHex(at: screenPoint, viewBounds: bounds) ?? "#------"
            let text = "X: \(Int(point.x))  Y: \(Int(screenPoint.y))  \(hex)"
            showBadge(
                text: text,
                near: CGRect(x: point.x, y: point.y, width: 1, height: 1),
                offset: CGPoint(x: 14, y: 14)
            )
        } else {
            badgeBackgroundLayer.isHidden = true
            badgeTextLayer.isHidden = true
        }
    }
    
    private func updateDimMask(hole: CGRect?) {
        let path = CGMutablePath()
        path.addRect(bounds)
        if let hole, hole.width > 0, hole.height > 0 {
            path.addRect(hole)
        }
        maskLayer.path = path
        maskLayer.frame = bounds
    }
    
    private func updateBorder(rect: CGRect?) {
        guard let rect, rect.width > 0, rect.height > 0 else {
            borderLayer.path = nil
            borderLayer.isHidden = true
            return
        }
        borderLayer.isHidden = false
        if mode == .windowOnly {
            borderLayer.path = CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        } else {
            borderLayer.path = CGPath(rect: rect, transform: nil)
        }
    }
    
    private func updateCrosshair(visible: Bool, at point: CGPoint?) {
        guard visible, let point else {
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
    
    private func showBadge(text: String, near rect: CGRect, offset: CGPoint?) {
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
