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
        self.wantsLayer = true
        
        // Показываем прицел сразу, если курсор мыши находится на этом экране
        let mouseLoc = NSEvent.mouseLocation
        if NSMouseInRect(mouseLoc, screen.frame, false) {
            let windowPoint = NSPoint(x: mouseLoc.x - screen.frame.origin.x, y: mouseLoc.y - screen.frame.origin.y)
            self.currentPoint = windowPoint
        } else {
            self.currentPoint = nil
        }
    }
    
    func updateSampler(_ sampler: ScreenPixelSampler) {
        self.sampler = sampler
        needsDisplay = true
    }
    
    func updateVisibleWindows(_ windows: [SCWindow]) {
        self.visibleWindows = windows
    }
    
    func updateBackgroundImage(_ image: CGImage) {
        self.sampler = ScreenPixelSampler(image: image)
        needsDisplay = true
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
    
    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
        needsDisplay = true
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
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        currentPoint = loc
        
        if mode != .windowOnly, let start = startPoint {
            let dist = hypot(loc.x - start.x, loc.y - start.y)
            if dist > 3 {
                isDragging = true
                hoveredWindow = nil
            }
        }
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        
        // 1. Режим окна (windowOnly)
        if mode == .windowOnly {
            if let hovered = hoveredWindow {
                startPoint = nil
                currentPoint = nil
                needsDisplay = true
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
            needsDisplay = true
            
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
        needsDisplay = true
        onCancel()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        let loc = convert(event.locationInWindow, from: nil)
        currentPoint = loc
        needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if !isDragging {
            currentPoint = nil
            hoveredWindow = nil
            needsDisplay = true
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        currentPoint = loc
        
        if mode == .windowOnly {
            let globalAppKitX = screen.frame.origin.x + loc.x
            let globalAppKitY = screen.frame.origin.y + loc.y
            let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
            let mouseInScreenCoords = CGPoint(x: globalAppKitX, y: primaryHeight - globalAppKitY)
            
            hoveredWindow = visibleWindows.first(where: { win in
                win.frame.contains(mouseInScreenCoords)
            })
        }
        
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let screenHeight = bounds.height
        
        // Затемнение экрана
        context.setFillColor(CGColor(gray: 0, alpha: 0.35))
        context.fill(bounds)
        
        // 1. Отрисовка подсветки окна
        if mode == .windowOnly, let hovered = hoveredWindow {
            let winFrame = hovered.frame
            let appKitRect = NSRect(
                x: winFrame.origin.x,
                y: screenHeight - winFrame.origin.y - winFrame.height,
                width: winFrame.width,
                height: winFrame.height
            )
            
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
            let rect = CGRect(
                x: min(start.x, current.x),
                y: min(start.y, current.y),
                width: abs(start.x - current.x),
                height: abs(start.y - current.y)
            )
            
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
        
        AreaOverlayBadgeRenderer.drawTopTip(mode: mode, bounds: bounds, in: context)
    }
}
