import Cocoa
import ScreenCaptureKit

/// Интерактивное NSView отображения затемнения, окна hover и рамки выделения
final class AreaSelectionNSView: NSView {
    private let screen: NSScreen
    private let mode: OverlayMode
    private var visibleWindows: [SCWindow]
    private let onCompleteRect: (CGRect) -> Void
    private let onCompleteWindow: (SCWindow) -> Void
    private let onCancel: () -> Void
    
    private var isDragging = false
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var hoveredWindow: SCWindow?
    private var trackingArea: NSTrackingArea?
    
    private var sampler: ScreenPixelSampler
    /// Области, уже нарисованные на экране. Перерисовывается только их разница с новым кадром.
    private var paintedRegions: [CGRect] = []
    
    init(
        frame: NSRect,
        screen: NSScreen,
        mode: OverlayMode,
        visibleWindows: [SCWindow],
        backgroundImage: CGImage? = nil,
        onCompleteRect: @escaping (CGRect) -> Void,
        onCompleteWindow: @escaping (SCWindow) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.screen = screen
        self.mode = mode
        self.visibleWindows = visibleWindows
        self.sampler = ScreenPixelSampler(image: backgroundImage)
        self.onCompleteRect = onCompleteRect
        self.onCompleteWindow = onCompleteWindow
        self.onCancel = onCancel
        super.init(frame: frame)
        // Без layer-backed view грязные прямоугольники реально остаются полосками,
        // а не перезаливают весь экран на каждый mouseMoved.
        self.wantsLayer = false
        
        // Показываем прицел сразу, если курсор мыши находится на этом экране
        let mouseLoc = NSEvent.mouseLocation
        if NSMouseInRect(mouseLoc, screen.frame, false) {
            let windowPoint = NSPoint(x: mouseLoc.x - screen.frame.origin.x, y: mouseLoc.y - screen.frame.origin.y)
            self.currentPoint = windowPoint
        } else {
            self.currentPoint = nil
        }
        paintedRegions = currentDamageRegions()
    }
    
    func updateSampler(_ sampler: ScreenPixelSampler) {
        self.sampler = sampler
        guard mode != .windowOnly, !isDragging else { return }
        syncPaint()
    }
    
    func updateVisibleWindows(_ windows: [SCWindow]) {
        self.visibleWindows = windows
        guard mode == .windowOnly else { return }
        if let loc = currentPoint {
            hoveredWindow = windowUnderCursor(at: loc)
        }
        syncPaint()
    }
    
    func updateBackgroundImage(_ image: CGImage) {
        sampler = ScreenPixelSampler(image: image)
        guard mode != .windowOnly, !isDragging else { return }
        syncPaint()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .mouseEnteredAndExited]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }
    
    override var acceptsFirstResponder: Bool { true }

    /// Первый клик по ещё неактивному окну сразу начинает выделение, а не только активирует приложение.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(self)
        }
    }
    
    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onCancel()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        
        // Быстрое копирование HEX-кода при зажатой клавише Option (⌥)
        if event.modifierFlags.contains(.option) {
            let screenHeight = bounds.height
            let screenPoint = CGPoint(x: loc.x, y: screenHeight - loc.y)
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
        syncPaint()
    }
    
    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if mode == .windowOnly {
            moveCursor(to: loc)
            return
        }
        currentPoint = loc
        
        if let start = startPoint {
            let dist = hypot(loc.x - start.x, loc.y - start.y)
            if dist > 3 {
                isDragging = true
                hoveredWindow = nil
            }
        }
        syncPaint()
    }
    
    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        
        // 1. Режим окна (windowOnly)
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
        
        // 2. Режим произвольной области (areaOnly / recordingArea)
        if isDragging, let start = startPoint {
            let rect = CGRect(
                x: min(start.x, loc.x),
                y: min(start.y, loc.y),
                width: abs(start.x - loc.x),
                height: abs(start.y - loc.y)
            )
            
            startPoint = nil
            currentPoint = nil
            isDragging = false
            
            if rect.width > 5 && rect.height > 5 {
                let globalAppKitX = screen.frame.origin.x + rect.origin.x
                let globalAppKitY = screen.frame.origin.y + rect.origin.y
                let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
                let scRect = CGRect(
                    x: globalAppKitX,
                    y: primaryHeight - globalAppKitY - rect.height,
                    width: rect.width,
                    height: rect.height
                )
                self.isHidden = true
                self.window?.alphaValue = 0.0
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
        moveCursor(to: convert(event.locationInWindow, from: nil))
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard !isDragging else { return }
        currentPoint = nil
        hoveredWindow = nil
        syncPaint()
    }
    
    override func mouseMoved(with event: NSEvent) {
        moveCursor(to: convert(event.locationInWindow, from: nil))
    }

    private func moveCursor(to loc: CGPoint) {
        if mode == .windowOnly {
            let next = windowUnderCursor(at: loc)
            let sameWindow = next?.windowID == hoveredWindow?.windowID
            currentPoint = loc
            guard !sameWindow else { return }
            hoveredWindow = next
            syncPaint()
            return
        }
        if let currentPoint, abs(currentPoint.x - loc.x) < 0.5, abs(currentPoint.y - loc.y) < 0.5 {
            return
        }
        currentPoint = loc
        syncPaint()
    }

    private func windowUnderCursor(at loc: CGPoint) -> SCWindow? {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? bounds.height
        let mouse = CGPoint(
            x: screen.frame.origin.x + loc.x,
            y: primaryHeight - (screen.frame.origin.y + loc.y)
        )
        return visibleWindows.first { $0.frame.contains(mouse) }
    }

    private func appKitRect(for winFrame: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? bounds.height
        let appKitGlobalY = primaryHeight - winFrame.origin.y - winFrame.height
        return CGRect(
            x: winFrame.origin.x - screen.frame.origin.x,
            y: appKitGlobalY - screen.frame.origin.y,
            width: winFrame.width,
            height: winFrame.height
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

    private func syncPaint() {
        let next = currentDamageRegions()
        guard next != paintedRegions else { return }
        for rect in paintedRegions where !rect.isEmpty {
            setNeedsDisplay(rect)
        }
        for rect in next where !rect.isEmpty {
            setNeedsDisplay(rect)
        }
        paintedRegions = next
    }

    private func currentDamageRegions() -> [CGRect] {
        if mode == .windowOnly, let hovered = hoveredWindow {
            let rect = appKitRect(for: hovered.frame)
            let title = hovered.owningApplication?.applicationName ?? (hovered.title ?? L("overlay.window_fallback"))
            let badge = AreaOverlayBadgeRenderer.badgeRect(for: L("overlay.window_badge", title), near: rect)
            return [rect.insetBy(dx: -4, dy: -4), badge.insetBy(dx: -2, dy: -2)]
        }
        if isDragging, let start = startPoint, let current = currentPoint {
            let rect = selectionRect(from: start, to: current)
            let prefix = mode == .recordingArea ? "🎥 Запись: " : ""
            let badge = AreaOverlayBadgeRenderer.badgeRect(
                for: "\(prefix)\(Int(rect.width)) × \(Int(rect.height)) px",
                near: rect
            )
            return [rect.insetBy(dx: -3, dy: -3), badge.insetBy(dx: -2, dy: -2)]
        }
        guard mode != .windowOnly, let current = currentPoint else { return [] }
        let badge = AreaOverlayBadgeRenderer.crosshairBadgeRect(point: current, bounds: bounds, sampler: sampler)
        return [
            CGRect(x: 0, y: current.y - 2, width: max(bounds.width, 1), height: 4),
            CGRect(x: current.x - 2, y: 0, width: 4, height: max(bounds.height, 1)),
            badge.insetBy(dx: -2, dy: -2)
        ]
    }

    private func rectsBeingDrawn(fallback: NSRect) -> [NSRect] {
        var pointer: UnsafePointer<NSRect>?
        var count = 0
        getRectsBeingDrawn(&pointer, count: &count)
        guard let pointer, count > 0 else { return [fallback] }
        return (0..<count).map { pointer[$0] }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let dirtyRects = rectsBeingDrawn(fallback: dirtyRect)
        
        // Затемняется только повреждённый кусок, иначе каждый mouseMoved
        // перезаливает кадр всего монитора и оверлей перестаёт успевать за курсором.
        context.setBlendMode(.copy)
        context.setFillColor(CGColor(gray: 0, alpha: 0.35))
        for rect in dirtyRects {
            context.fill(rect)
        }
        context.setBlendMode(.normal)
        
        // 1. Отрисовка подсветки окна
        if mode == .windowOnly, let hovered = hoveredWindow {
            let appKitRect = self.appKitRect(for: hovered.frame)
            
            context.saveGState()
            context.setBlendMode(.clear)
            context.fill(appKitRect)
            context.restoreGState()
            
            context.setStrokeColor(CGColor(red: 0.1, green: 0.7, blue: 1.0, alpha: 1.0))
            context.setLineWidth(3.0)
            let path = CGPath(roundedRect: appKitRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
            context.addPath(path)
            context.strokePath()
            
            let appTitle = hovered.owningApplication?.applicationName ?? (hovered.title ?? L("overlay.window_fallback"))
            AreaOverlayBadgeRenderer.drawBadge(text: L("overlay.window_badge", appTitle), at: appKitRect, in: context)
        }
        // 2. Отрисовка рамки произвольного размера
        else if isDragging, let start = startPoint, let current = currentPoint {
            let rect = selectionRect(from: start, to: current)
            
            context.saveGState()
            context.setBlendMode(.clear)
            context.fill(rect)
            context.restoreGState()
            
            let strokeColor = mode == .recordingArea ? CGColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1.0) : CGColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
            context.setStrokeColor(strokeColor)
            context.setLineWidth(2.0)
            context.stroke(rect)
            
            let prefix = mode == .recordingArea ? "🎥 Запись: " : ""
            AreaOverlayBadgeRenderer.drawBadge(text: "\(prefix)\(Int(rect.width)) × \(Int(rect.height)) px", at: rect, in: context)
        } else if mode != .windowOnly, let current = currentPoint {
            // Отрисовка аккуратного прицела/перекрестья до начала драга
            context.setStrokeColor(CGColor(gray: 1.0, alpha: 0.35))
            context.setLineWidth(1.0)
            context.setLineDash(phase: 0, lengths: [4, 4])
            
            context.move(to: CGPoint(x: 0, y: current.y))
            context.addLine(to: CGPoint(x: bounds.width, y: current.y))
            context.move(to: CGPoint(x: current.x, y: 0))
            context.addLine(to: CGPoint(x: current.x, y: bounds.height))
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
            
            AreaOverlayBadgeRenderer.drawCrosshairBadge(point: current, bounds: bounds, sampler: sampler, in: context)
        }
        
        let tipRect = AreaOverlayBadgeRenderer.topTipRect(mode: mode, bounds: bounds)
        if dirtyRects.contains(where: { $0.intersects(tipRect) }) {
            AreaOverlayBadgeRenderer.drawTopTip(mode: mode, bounds: bounds, in: context)
        }
    }
}
