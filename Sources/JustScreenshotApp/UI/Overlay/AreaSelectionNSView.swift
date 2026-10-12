import Cocoa
import ScreenCaptureKit

/// Интерактивное NSView отображения затемнения, окна hover и рамки выделения
final class AreaSelectionNSView: NSView {
    private let mode: OverlayMode
    private let visibleWindows: [SCWindow]
    private let onCompleteRect: (CGRect) -> Void
    private let onCompleteWindow: (SCWindow) -> Void
    private let onCancel: () -> Void
    
    private var isDragging = false
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var hoveredWindow: SCWindow?
    private var trackingArea: NSTrackingArea?
    
    init(
        frame: NSRect,
        mode: OverlayMode,
        visibleWindows: [SCWindow],
        onCompleteRect: @escaping (CGRect) -> Void,
        onCompleteWindow: @escaping (SCWindow) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.visibleWindows = visibleWindows
        self.onCompleteRect = onCompleteRect
        self.onCompleteWindow = onCompleteWindow
        self.onCancel = onCancel
        super.init(frame: frame)
        self.wantsLayer = true
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
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onCancel()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
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
                let screenHeight = bounds.height
                let scRect = CGRect(
                    x: rect.origin.x,
                    y: screenHeight - rect.origin.y - rect.height,
                    width: rect.width,
                    height: rect.height
                )
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
    
    override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        currentPoint = loc
        
        if mode == .windowOnly {
            let screenHeight = bounds.height
            let mouseInScreenCoords = CGPoint(x: loc.x, y: screenHeight - loc.y)
            
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
            
            let appTitle = hovered.owningApplication?.applicationName ?? (hovered.title ?? "Окно")
            drawBadge(text: "📸 \(appTitle) • Кликните для снимка окна", at: appKitRect, in: context)
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
            drawBadge(text: "\(prefix)\(Int(rect.width)) × \(Int(rect.height)) px", at: rect, in: context)
        }
        
        drawTopTip(in: context)
    }
    
    private func drawBadge(text: String, at rect: CGRect, in context: CGContext) {
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
    
    private func drawTopTip(in context: CGContext) {
        let tipText: NSString
        switch mode {
        case .windowOnly:
            tipText = "Кликните по окну для скриншота окна • ESC для отмены"
        case .areaOnly:
            tipText = "Выделите прямоугольник произвольного размера для скриншота • ESC для отмены"
        case .recordingArea:
            tipText = "Выделите область для записи экрана в видео (MP4) • ESC для отмены"
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
