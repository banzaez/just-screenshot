import Cocoa
import QuartzCore

/// Режимы отображения рамки области записи
public enum RecordingFrameMode: Sendable {
    /// Режим настройки: интерактивные маркеры изменения размера, перемещение, бейдж разрешения и пропорций
    case setup
    /// Режим активной записи: прозрачность для кликов, красная рамка с индикаторами
    case recording
}

/// Прозрачное окно-рамка вокруг выбранной области экрана.
/// В режиме .setup позволяет изменять размеры (за углы/грани) и перемещать область.
/// В режиме .recording переходит в фоновый режим с красной индикацией и пропускает клики насквозь.
public final class RecordingFrameWindow: NSWindow {
    private let frameView: RecordingFrameNSView
    
    public var currentMode: RecordingFrameMode {
        frameView.mode
    }
    
    public init(
        screenRect: CGRect,
        mode: RecordingFrameMode = .setup,
        onRectChanged: ((CGRect) -> Void)? = nil,
        onStartRequested: (() -> Void)? = nil,
        onCancelRequested: (() -> Void)? = nil
    ) {
        self.frameView = RecordingFrameNSView(
            frame: NSRect(origin: .zero, size: screenRect.size),
            mode: mode,
            onRectChanged: onRectChanged,
            onStartRequested: onStartRequested,
            onCancelRequested: onCancelRequested
        )
        
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.title = JustScreenshotWindowTitles.recordingFrame
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = (mode == .recording)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.animationBehavior = .none
        self.acceptsMouseMovedEvents = true
        
        self.contentView = frameView
    }
    
    public func setMode(_ newMode: RecordingFrameMode) {
        self.ignoresMouseEvents = (newMode == .recording)
        frameView.setMode(newMode)
        invalidateCursorRects(for: frameView)
    }
    
    public func updateFrame(_ newRect: CGRect) {
        setFrame(newRect, display: true)
        frameView.notifyRectChanged(newRect)
    }
    
    public override var canBecomeKey: Bool {
        frameView.mode == .setup
    }
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 { // Return / Enter
            frameView.onStartRequested?()
        } else if event.keyCode == 53 { // Escape
            frameView.onCancelRequested?()
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - RecordingFrameNSView

@MainActor
final class RecordingFrameNSView: NSView {
    private(set) var mode: RecordingFrameMode
    var onRectChanged: ((CGRect) -> Void)?
    var onStartRequested: (() -> Void)?
    var onCancelRequested: (() -> Void)?
    
    // CALayers для режима активной записи
    private let recordingBorderLayer = CAShapeLayer()
    private let recordingCornerLayer = CAShapeLayer()
    
    // CALayers для режима настройки (setup)
    private let setupBorderLayer = CAShapeLayer()
    private let setupInnerBorderLayer = CAShapeLayer()
    private let setupCornerHandlesLayer = CAShapeLayer()
    private let setupEdgeHandlesLayer = CAShapeLayer()
    private let badgeBackgroundLayer = CAShapeLayer()
    private let badgeTextLayer = CATextLayer()
    
    // Состояние перетаскивания и изменения размера
    private enum HitTarget {
        case none
        case move
        case topLeft
        case topCenter
        case topRight
        case rightCenter
        case bottomRight
        case bottomCenter
        case bottomLeft
        case leftCenter
    }
    
    private var activeHitTarget: HitTarget = .none
    private var initialMouseScreenLoc: NSPoint = .zero
    private var initialWindowFrame: NSRect = .zero
    
    private let cornerHandleSize: CGFloat = 12
    private let edgeHandleLength: CGFloat = 18
    private let edgeHandleThickness: CGFloat = 6
    private let hitSlop: CGFloat = 10
    
    init(
        frame: NSRect,
        mode: RecordingFrameMode,
        onRectChanged: ((CGRect) -> Void)?,
        onStartRequested: (() -> Void)? = nil,
        onCancelRequested: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.onRectChanged = onRectChanged
        self.onStartRequested = onStartRequested
        self.onCancelRequested = onCancelRequested
        super.init(frame: frame)
        
        wantsLayer = true
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setMode(_ newMode: RecordingFrameMode) {
        guard mode != newMode else { return }
        self.mode = newMode
        updateLayersVisibility()
        needsLayout = true
        layoutSubtreeIfNeeded()
        window?.invalidateCursorRects(for: self)
    }
    
    func notifyRectChanged(_ rect: CGRect) {
        onRectChanged?(rect)
    }
    
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updateLayerPaths()
        CATransaction.commit()
    }
    
    private func setupLayers() {
        guard let root = layer else { return }
        root.backgroundColor = NSColor.clear.cgColor
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        
        // Слои активной записи (.recording)
        recordingBorderLayer.fillColor = nil
        recordingBorderLayer.strokeColor = CGColor(red: 1.0, green: 0.22, blue: 0.22, alpha: 0.9)
        recordingBorderLayer.lineWidth = 3
        recordingBorderLayer.contentsScale = scale
        root.addSublayer(recordingBorderLayer)
        
        recordingCornerLayer.fillColor = nil
        recordingCornerLayer.strokeColor = CGColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)
        recordingCornerLayer.lineWidth = 4
        recordingCornerLayer.lineCap = .round
        recordingCornerLayer.lineJoin = .round
        recordingCornerLayer.contentsScale = scale
        root.addSublayer(recordingCornerLayer)
        
        // Слои режима настройки (.setup)
        // Основная линия: ярко-синий акцент Apple
        setupBorderLayer.fillColor = nil
        setupBorderLayer.strokeColor = CGColor(red: 0.1, green: 0.55, blue: 1.0, alpha: 0.95)
        setupBorderLayer.lineWidth = 2
        setupBorderLayer.contentsScale = scale
        setupBorderLayer.shadowColor = NSColor.black.cgColor
        setupBorderLayer.shadowOpacity = 0.45
        setupBorderLayer.shadowRadius = 4
        setupBorderLayer.shadowOffset = .zero
        root.addSublayer(setupBorderLayer)
        
        // Внутренняя тонкая белая линия для идеальной видимости на темных фонах
        setupInnerBorderLayer.fillColor = nil
        setupInnerBorderLayer.strokeColor = CGColor(gray: 1.0, alpha: 0.4)
        setupInnerBorderLayer.lineWidth = 1
        setupInnerBorderLayer.contentsScale = scale
        root.addSublayer(setupInnerBorderLayer)
        
        // Угловые маркеры (rounded squares)
        setupCornerHandlesLayer.fillColor = NSColor.white.cgColor
        setupCornerHandlesLayer.strokeColor = CGColor(red: 0.08, green: 0.48, blue: 0.98, alpha: 1.0)
        setupCornerHandlesLayer.lineWidth = 2
        setupCornerHandlesLayer.contentsScale = scale
        setupCornerHandlesLayer.shadowColor = NSColor.black.cgColor
        setupCornerHandlesLayer.shadowOpacity = 0.35
        setupCornerHandlesLayer.shadowRadius = 3
        setupCornerHandlesLayer.shadowOffset = CGSize(width: 0, height: -1)
        root.addSublayer(setupCornerHandlesLayer)
        
        // Граничные маркеры (pills)
        setupEdgeHandlesLayer.fillColor = NSColor.white.cgColor
        setupEdgeHandlesLayer.strokeColor = CGColor(red: 0.08, green: 0.48, blue: 0.98, alpha: 1.0)
        setupEdgeHandlesLayer.lineWidth = 1.5
        setupEdgeHandlesLayer.contentsScale = scale
        setupEdgeHandlesLayer.shadowColor = NSColor.black.cgColor
        setupEdgeHandlesLayer.shadowOpacity = 0.3
        setupEdgeHandlesLayer.shadowRadius = 3
        setupEdgeHandlesLayer.shadowOffset = CGSize(width: 0, height: -1)
        root.addSublayer(setupEdgeHandlesLayer)
        
        // Бейдж с размером и пропорциями
        badgeBackgroundLayer.fillColor = CGColor(red: 0.08, green: 0.09, blue: 0.13, alpha: 0.9)
        badgeBackgroundLayer.strokeColor = CGColor(gray: 1.0, alpha: 0.25)
        badgeBackgroundLayer.lineWidth = 1
        badgeBackgroundLayer.contentsScale = scale
        badgeBackgroundLayer.shadowColor = NSColor.black.cgColor
        badgeBackgroundLayer.shadowOpacity = 0.45
        badgeBackgroundLayer.shadowRadius = 5
        badgeBackgroundLayer.shadowOffset = CGSize(width: 0, height: -2)
        root.addSublayer(badgeBackgroundLayer)
        
        badgeTextLayer.contentsScale = scale
        badgeTextLayer.alignmentMode = .center
        badgeTextLayer.fontSize = 11
        badgeTextLayer.foregroundColor = NSColor.white.cgColor
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        badgeTextLayer.font = font
        root.addSublayer(badgeTextLayer)
        
        updateLayersVisibility()
        updateLayerPaths()
    }
    
    private func updateLayersVisibility() {
        let isRecording = (mode == .recording)
        recordingBorderLayer.isHidden = !isRecording
        recordingCornerLayer.isHidden = !isRecording
        
        setupBorderLayer.isHidden = isRecording
        setupInnerBorderLayer.isHidden = isRecording
        setupCornerHandlesLayer.isHidden = isRecording
        setupEdgeHandlesLayer.isHidden = isRecording
        badgeBackgroundLayer.isHidden = isRecording
        badgeTextLayer.isHidden = isRecording
    }
    
    private func updateLayerPaths() {
        if mode == .recording {
            updateRecordingLayerPaths()
        } else {
            updateSetupLayerPaths()
        }
    }
    
    private func updateRecordingLayerPaths() {
        let inset = bounds.insetBy(dx: 1.5, dy: 1.5)
        recordingBorderLayer.path = CGPath(roundedRect: inset, cornerWidth: 6, cornerHeight: 6, transform: nil)
        recordingBorderLayer.frame = bounds
        
        let cornerLen: CGFloat = 16
        let path = CGMutablePath()
        path.move(to: CGPoint(x: bounds.minX + 1.5, y: bounds.minY + cornerLen))
        path.addLine(to: CGPoint(x: bounds.minX + 1.5, y: bounds.minY + 1.5))
        path.addLine(to: CGPoint(x: bounds.minX + cornerLen, y: bounds.minY + 1.5))
        
        path.move(to: CGPoint(x: bounds.maxX - cornerLen, y: bounds.minY + 1.5))
        path.addLine(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.minY + 1.5))
        path.addLine(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.minY + cornerLen))
        
        path.move(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.maxY - cornerLen))
        path.addLine(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.maxY - 1.5))
        path.addLine(to: CGPoint(x: bounds.maxX - cornerLen, y: bounds.maxY - 1.5))
        
        path.move(to: CGPoint(x: bounds.minX + cornerLen, y: bounds.maxY - 1.5))
        path.addLine(to: CGPoint(x: bounds.minX + 1.5, y: bounds.maxY - 1.5))
        path.addLine(to: CGPoint(x: bounds.minX + 1.5, y: bounds.maxY - cornerLen))
        
        recordingCornerLayer.path = path
        recordingCornerLayer.frame = bounds
    }
    
    private func updateSetupLayerPaths() {
        let inset = bounds.insetBy(dx: 1, dy: 1)
        setupBorderLayer.path = CGPath(roundedRect: inset, cornerWidth: 4, cornerHeight: 4, transform: nil)
        setupBorderLayer.frame = bounds
        
        let innerInset = bounds.insetBy(dx: 2.5, dy: 2.5)
        setupInnerBorderLayer.path = CGPath(roundedRect: innerInset, cornerWidth: 3, cornerHeight: 3, transform: nil)
        setupInnerBorderLayer.frame = bounds
        
        // 4 угловых маркера (rounded rectangles 12x12)
        let s = cornerHandleSize
        let cornerPath = CGMutablePath()
        let cornerRects = [
            CGRect(x: bounds.minX - s / 4, y: bounds.maxY - s * 0.75, width: s, height: s),
            CGRect(x: bounds.maxX - s * 0.75, y: bounds.maxY - s * 0.75, width: s, height: s),
            CGRect(x: bounds.maxX - s * 0.75, y: bounds.minY - s / 4, width: s, height: s),
            CGRect(x: bounds.minX - s / 4, y: bounds.minY - s / 4, width: s, height: s)
        ]
        for r in cornerRects {
            cornerPath.addRoundedRect(in: r, cornerWidth: 3, cornerHeight: 3)
        }
        setupCornerHandlesLayer.path = cornerPath
        setupCornerHandlesLayer.frame = bounds
        
        // 4 граничных маркера (pills)
        let edgePath = CGMutablePath()
        let el = edgeHandleLength
        let et = edgeHandleThickness
        
        // Верхний и нижний маркеры (горизонтальные pills)
        let topEdge = CGRect(x: bounds.midX - el / 2, y: bounds.maxY - et / 2, width: el, height: et)
        let bottomEdge = CGRect(x: bounds.midX - el / 2, y: bounds.minY - et / 2, width: el, height: et)
        // Левый и правый маркеры (вертикальные pills)
        let leftEdge = CGRect(x: bounds.minX - et / 2, y: bounds.midY - el / 2, width: et, height: el)
        let rightEdge = CGRect(x: bounds.maxX - et / 2, y: bounds.midY - el / 2, width: et, height: el)
        
        edgePath.addRoundedRect(in: topEdge, cornerWidth: et / 2, cornerHeight: et / 2)
        edgePath.addRoundedRect(in: bottomEdge, cornerWidth: et / 2, cornerHeight: et / 2)
        edgePath.addRoundedRect(in: leftEdge, cornerWidth: et / 2, cornerHeight: et / 2)
        edgePath.addRoundedRect(in: rightEdge, cornerWidth: et / 2, cornerHeight: et / 2)
        
        setupEdgeHandlesLayer.path = edgePath
        setupEdgeHandlesLayer.frame = bounds
        
        // Бейдж с разрешением и пропорцией
        let w = Int(bounds.width)
        let h = Int(bounds.height)
        let ratioStr = aspectString(width: bounds.width, height: bounds.height)
        let dimString = ratioStr.isEmpty ? "\(w) × \(h)" : "\(w) × \(h) • \(ratioStr)"
        badgeTextLayer.string = dimString
        
        let badgeW: CGFloat = ratioStr.isEmpty ? 104 : 144
        let badgeH: CGFloat = 24
        var badgeY = bounds.maxY - badgeH - 10
        if badgeY < bounds.minY + 12 {
            badgeY = bounds.minY + 10
        }
        let badgeRect = CGRect(
            x: bounds.midX - badgeW / 2,
            y: badgeY,
            width: badgeW,
            height: badgeH
        )
        badgeBackgroundLayer.path = CGPath(roundedRect: badgeRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        badgeBackgroundLayer.frame = bounds
        
        badgeTextLayer.frame = CGRect(
            x: badgeRect.origin.x,
            y: badgeRect.origin.y + 4.5,
            width: badgeW,
            height: badgeH - 4.5
        )
    }
    
    private func aspectString(width: CGFloat, height: CGFloat) -> String {
        guard height > 0 else { return "" }
        let ratio = width / height
        if abs(ratio - 16.0 / 9.0) < 0.04 { return "16:9" }
        if abs(ratio - 4.0 / 3.0) < 0.04 { return "4:3" }
        if abs(ratio - 1.0) < 0.04 { return "1:1" }
        if abs(ratio - 21.0 / 9.0) < 0.04 { return "21:9" }
        return ""
    }
    
    // MARK: - Hit Testing & Cursors
    
    private func hitTestTarget(at pt: CGPoint) -> HitTarget {
        let slop = hitSlop
        
        let tl = CGRect(x: bounds.minX - slop, y: bounds.maxY - slop * 2, width: slop * 3, height: slop * 3)
        if tl.contains(pt) { return .topLeft }
        
        let tr = CGRect(x: bounds.maxX - slop * 2, y: bounds.maxY - slop * 2, width: slop * 3, height: slop * 3)
        if tr.contains(pt) { return .topRight }
        
        let bl = CGRect(x: bounds.minX - slop, y: bounds.minY - slop, width: slop * 3, height: slop * 3)
        if bl.contains(pt) { return .bottomLeft }
        
        let br = CGRect(x: bounds.maxX - slop * 2, y: bounds.minY - slop, width: slop * 3, height: slop * 3)
        if br.contains(pt) { return .bottomRight }
        
        let tc = CGRect(x: bounds.midX - edgeHandleLength, y: bounds.maxY - slop * 1.5, width: edgeHandleLength * 2, height: slop * 2.5)
        if tc.contains(pt) { return .topCenter }
        
        let bc = CGRect(x: bounds.midX - edgeHandleLength, y: bounds.minY - slop, width: edgeHandleLength * 2, height: slop * 2.5)
        if bc.contains(pt) { return .bottomCenter }
        
        let lc = CGRect(x: bounds.minX - slop, y: bounds.midY - edgeHandleLength, width: slop * 2.5, height: edgeHandleLength * 2)
        if lc.contains(pt) { return .leftCenter }
        
        let rc = CGRect(x: bounds.maxX - slop * 1.5, y: bounds.midY - edgeHandleLength, width: slop * 2.5, height: edgeHandleLength * 2)
        if rc.contains(pt) { return .rightCenter }
        
        if bounds.contains(pt) {
            return .move
        }
        return .none
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        guard mode == .setup else { return }
        
        let slop = hitSlop
        
        addCursorRect(CGRect(x: bounds.minX - slop, y: bounds.maxY - slop * 2, width: slop * 3, height: slop * 3), cursor: .crosshair)
        addCursorRect(CGRect(x: bounds.maxX - slop * 2, y: bounds.maxY - slop * 2, width: slop * 3, height: slop * 3), cursor: .crosshair)
        addCursorRect(CGRect(x: bounds.minX - slop, y: bounds.minY - slop, width: slop * 3, height: slop * 3), cursor: .crosshair)
        addCursorRect(CGRect(x: bounds.maxX - slop * 2, y: bounds.minY - slop, width: slop * 3, height: slop * 3), cursor: .crosshair)
        
        addCursorRect(CGRect(x: bounds.midX - edgeHandleLength, y: bounds.maxY - slop * 1.5, width: edgeHandleLength * 2, height: slop * 2.5), cursor: .resizeUpDown)
        addCursorRect(CGRect(x: bounds.midX - edgeHandleLength, y: bounds.minY - slop, width: edgeHandleLength * 2, height: slop * 2.5), cursor: .resizeUpDown)
        addCursorRect(CGRect(x: bounds.minX - slop, y: bounds.midY - edgeHandleLength, width: slop * 2.5, height: edgeHandleLength * 2), cursor: .resizeLeftRight)
        addCursorRect(CGRect(x: bounds.maxX - slop * 1.5, y: bounds.midY - edgeHandleLength, width: slop * 2.5, height: edgeHandleLength * 2), cursor: .resizeLeftRight)
        
        let inner = bounds.insetBy(dx: slop * 2, dy: slop * 2)
        if inner.width > 0 && inner.height > 0 {
            addCursorRect(inner, cursor: .openHand)
        }
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        guard mode == .setup, let win = window else {
            super.mouseDown(with: event)
            return
        }
        
        let loc = convert(event.locationInWindow, from: nil)
        activeHitTarget = hitTestTarget(at: loc)
        initialMouseScreenLoc = NSEvent.mouseLocation
        initialWindowFrame = win.frame
        
        if activeHitTarget == .move {
            NSCursor.closedHand.push()
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard mode == .setup, let win = window, activeHitTarget != .none else {
            super.mouseDragged(with: event)
            return
        }
        
        let currentMouse = NSEvent.mouseLocation
        let dx = currentMouse.x - initialMouseScreenLoc.x
        let dy = currentMouse.y - initialMouseScreenLoc.y
        
        let minW: CGFloat = 160
        let minH: CGFloat = 120
        var newFrame = initialWindowFrame
        
        switch activeHitTarget {
        case .move:
            newFrame.origin.x = initialWindowFrame.origin.x + dx
            newFrame.origin.y = initialWindowFrame.origin.y + dy
            
        case .topRight:
            let w = max(minW, initialWindowFrame.width + dx)
            let h = max(minH, initialWindowFrame.height + dy)
            newFrame = CGRect(x: initialWindowFrame.minX, y: initialWindowFrame.minY, width: w, height: h)
            
        case .topLeft:
            let w = max(minW, initialWindowFrame.width - dx)
            let h = max(minH, initialWindowFrame.height + dy)
            let x = initialWindowFrame.maxX - w
            newFrame = CGRect(x: x, y: initialWindowFrame.minY, width: w, height: h)
            
        case .bottomRight:
            let w = max(minW, initialWindowFrame.width + dx)
            let h = max(minH, initialWindowFrame.height - dy)
            let y = initialWindowFrame.maxY - h
            newFrame = CGRect(x: initialWindowFrame.minX, y: y, width: w, height: h)
            
        case .bottomLeft:
            let w = max(minW, initialWindowFrame.width - dx)
            let h = max(minH, initialWindowFrame.height - dy)
            let x = initialWindowFrame.maxX - w
            let y = initialWindowFrame.maxY - h
            newFrame = CGRect(x: x, y: y, width: w, height: h)
            
        case .rightCenter:
            let w = max(minW, initialWindowFrame.width + dx)
            newFrame = CGRect(x: initialWindowFrame.minX, y: initialWindowFrame.minY, width: w, height: initialWindowFrame.height)
            
        case .leftCenter:
            let w = max(minW, initialWindowFrame.width - dx)
            let x = initialWindowFrame.maxX - w
            newFrame = CGRect(x: x, y: initialWindowFrame.minY, width: w, height: initialWindowFrame.height)
            
        case .topCenter:
            let h = max(minH, initialWindowFrame.height + dy)
            newFrame = CGRect(x: initialWindowFrame.minX, y: initialWindowFrame.minY, width: initialWindowFrame.width, height: h)
            
        case .bottomCenter:
            let h = max(minH, initialWindowFrame.height - dy)
            let y = initialWindowFrame.maxY - h
            newFrame = CGRect(x: initialWindowFrame.minX, y: y, width: initialWindowFrame.width, height: h)
            
        case .none:
            break
        }
        
        win.setFrame(newFrame, display: true)
        onRectChanged?(newFrame)
    }
    
    override func mouseUp(with event: NSEvent) {
        guard mode == .setup, let win = window else {
            super.mouseUp(with: event)
            return
        }
        
        if activeHitTarget == .move {
            NSCursor.pop()
        }
        activeHitTarget = .none
        
        // Размеры видео должны быть четными для аппаратного H.264
        var f = win.frame
        let w = Int(f.width)
        let h = Int(f.height)
        let evenW = CGFloat(w - (w % 2))
        let evenH = CGFloat(h - (h % 2))
        if evenW != f.width || evenH != f.height {
            f.size = CGSize(width: evenW, height: evenH)
            win.setFrame(f, display: true)
        }
        
        onRectChanged?(f)
        win.invalidateCursorRects(for: self)
    }
}
