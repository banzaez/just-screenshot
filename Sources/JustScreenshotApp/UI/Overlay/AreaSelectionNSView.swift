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
    
    private let layers = AreaSelectionLayerHost()
    
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
        if let root = layer {
            layers.install(in: root)
        }
        
        let mouseLoc = NSEvent.mouseLocation
        if NSMouseInRect(mouseLoc, screen.frame, false) {
            currentPoint = NSPoint(
                x: mouseLoc.x - screen.frame.origin.x,
                y: mouseLoc.y - screen.frame.origin.y
            )
        }
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
    
    override func layout() {
        super.layout()
        syncLayers()
    }
    
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        syncLayers()
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
                let scRect = ScreenCoordinateSpace.quartzRect(fromScreenLocal: rect, screenFrame: screen.frame)
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
    
    private func windowUnderCursor(at loc: CGPoint) -> SCWindow? {
        let mouse = ScreenCoordinateSpace.quartzPoint(fromScreenLocal: loc, screenFrame: screen.frame)
        return visibleWindows.first { $0.frame.contains(mouse) }
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
    
    private func tipText() -> String {
        switch mode {
        case .windowOnly: return L("overlay.window_tip")
        case .areaOnly: return L("overlay.area_tip")
        case .recordingArea: return L("overlay.record_tip")
        }
    }
    
    private func syncLayers() {
        var hole: CGRect?
        var borderRect: CGRect?
        var badge: String?
        var badgeNear: CGRect?
        var badgeOffset: CGPoint?
        var crosshairPoint: CGPoint?
        var borderColor = CGColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1)
        var borderWidth: CGFloat = 2
        
        if mode == .windowOnly, let hovered = hoveredWindow {
            let rect = ScreenCoordinateSpace.screenLocalRect(
                fromQuartzFrame: hovered.frame,
                screenFrame: screen.frame
            )
            hole = rect
            borderRect = rect
            badgeNear = rect
            let title = hovered.owningApplication?.applicationName
                ?? (hovered.title ?? L("overlay.window_fallback"))
            badge = L("overlay.window_badge", title)
            borderColor = CGColor(red: 0.1, green: 0.7, blue: 1.0, alpha: 1)
            borderWidth = 3
        } else if isDragging, let start = startPoint, let current = currentPoint {
            let rect = selectionRect(from: start, to: current)
            hole = rect
            borderRect = rect
            badgeNear = rect
            if mode == .recordingArea {
                badge = L("overlay.record_badge", Int(rect.width), Int(rect.height))
                borderColor = CGColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1)
            } else {
                badge = L("overlay.area_badge", Int(rect.width), Int(rect.height))
            }
        } else if mode != .windowOnly, let point = currentPoint {
            crosshairPoint = point
            let screenPoint = CGPoint(x: point.x, y: bounds.height - point.y)
            let hex = sampler.getPixelHex(at: screenPoint, viewBounds: bounds) ?? "#------"
            badge = "X: \(Int(point.x))  Y: \(Int(screenPoint.y))  \(hex)"
            badgeNear = CGRect(x: point.x, y: point.y, width: 1, height: 1)
            badgeOffset = CGPoint(x: 14, y: 14)
        }
        
        layers.apply(
            snapshot: AreaSelectionLayerHost.Snapshot(
                bounds: bounds,
                mode: mode,
                hole: hole,
                borderRect: borderRect,
                borderColor: borderColor,
                borderWidth: borderWidth,
                badge: badge,
                badgeNear: badgeNear,
                badgeOffset: badgeOffset,
                crosshairPoint: crosshairPoint,
                tipText: tipText(),
                scale: screen.backingScaleFactor
            )
        )
    }
}
