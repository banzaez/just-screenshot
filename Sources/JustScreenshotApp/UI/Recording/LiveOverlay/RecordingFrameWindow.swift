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
/// Окно расширено на `framePad` со всех сторон, чтобы маркеры, обводка и тени не обрезались
/// и не попадали внутрь области видеозаписи `innerScreenRect`.
public final class RecordingFrameWindow: NSWindow {
    static let framePad: CGFloat = 12

    private let frameView: RecordingFrameNSView
    private(set) var innerScreenRect: CGRect

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
        self.innerScreenRect = screenRect
        let paddedRect = screenRect.insetBy(dx: -Self.framePad, dy: -Self.framePad)
        self.frameView = RecordingFrameNSView(
            frame: NSRect(origin: .zero, size: paddedRect.size),
            framePad: Self.framePad,
            mode: mode,
            onRectChanged: onRectChanged,
            onStartRequested: onStartRequested,
            onCancelRequested: onCancelRequested
        )

        super.init(
            contentRect: paddedRect,
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
        self.isReleasedWhenClosed = false

        self.contentView = frameView
    }

    public func setMode(_ newMode: RecordingFrameMode) {
        self.ignoresMouseEvents = (newMode == .recording)
        frameView.setMode(newMode)
        invalidateCursorRects(for: frameView)
    }

    public func updateFrame(_ newRect: CGRect, notify: Bool = true) {
        innerScreenRect = newRect
        let paddedRect = newRect.insetBy(dx: -Self.framePad, dy: -Self.framePad)
        setFrame(paddedRect, display: true)
        frameView.needsLayout = true
        frameView.layoutSubtreeIfNeeded()
        invalidateCursorRects(for: frameView)
        if notify {
            frameView.notifyRectChanged(newRect)
        }
    }

    func updateInnerRect(_ newInnerRect: CGRect) {
        innerScreenRect = newInnerRect
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
    private let framePad: CGFloat
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
    private let badgeFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)

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

    private struct HandleSpec {
        let target: HitTarget
        let isCorner: Bool
        let visualRect: CGRect
        let hitRect: CGRect
        let cursor: NSCursor
    }

    private var activeHitTarget: HitTarget = .none
    private var initialMouseScreenLoc: NSPoint = .zero
    private var initialInnerFrame: NSRect = .zero

    private let cornerHandleSize: CGFloat = 12
    private let edgeHandleLength: CGFloat = 18
    private let edgeHandleThickness: CGFloat = 6
    private let hitSlop: CGFloat = 10

    init(
        frame: NSRect,
        framePad: CGFloat,
        mode: RecordingFrameMode,
        onRectChanged: ((CGRect) -> Void)?,
        onStartRequested: (() -> Void)? = nil,
        onCancelRequested: (() -> Void)? = nil
    ) {
        self.framePad = framePad
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

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateLayerContentsScale()
    }

    private var innerBounds: CGRect {
        bounds.insetBy(dx: framePad, dy: framePad)
    }

    private func setupLayers() {
        guard let root = layer else { return }
        root.backgroundColor = NSColor.clear.cgColor

        // Слои активной записи (.recording)
        recordingBorderLayer.fillColor = nil
        recordingBorderLayer.strokeColor = CGColor(red: 1.0, green: 0.22, blue: 0.22, alpha: 0.9)
        recordingBorderLayer.lineWidth = 3
        root.addSublayer(recordingBorderLayer)

        recordingCornerLayer.fillColor = nil
        recordingCornerLayer.strokeColor = CGColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)
        recordingCornerLayer.lineWidth = 4
        recordingCornerLayer.lineCap = .round
        recordingCornerLayer.lineJoin = .round
        root.addSublayer(recordingCornerLayer)

        // Слои режима настройки (.setup)
        setupBorderLayer.fillColor = nil
        setupBorderLayer.strokeColor = CGColor(red: 0.1, green: 0.55, blue: 1.0, alpha: 0.95)
        setupBorderLayer.lineWidth = 2
        setupBorderLayer.shadowColor = NSColor.black.cgColor
        setupBorderLayer.shadowOpacity = 0.45
        setupBorderLayer.shadowRadius = 4
        setupBorderLayer.shadowOffset = .zero
        root.addSublayer(setupBorderLayer)

        setupInnerBorderLayer.fillColor = nil
        setupInnerBorderLayer.strokeColor = CGColor(gray: 1.0, alpha: 0.4)
        setupInnerBorderLayer.lineWidth = 1
        root.addSublayer(setupInnerBorderLayer)

        setupCornerHandlesLayer.fillColor = NSColor.white.cgColor
        setupCornerHandlesLayer.strokeColor = CGColor(red: 0.08, green: 0.48, blue: 0.98, alpha: 1.0)
        setupCornerHandlesLayer.lineWidth = 2
        setupCornerHandlesLayer.shadowColor = NSColor.black.cgColor
        setupCornerHandlesLayer.shadowOpacity = 0.35
        setupCornerHandlesLayer.shadowRadius = 3
        setupCornerHandlesLayer.shadowOffset = CGSize(width: 0, height: -1)
        root.addSublayer(setupCornerHandlesLayer)

        setupEdgeHandlesLayer.fillColor = NSColor.white.cgColor
        setupEdgeHandlesLayer.strokeColor = CGColor(red: 0.08, green: 0.48, blue: 0.98, alpha: 1.0)
        setupEdgeHandlesLayer.lineWidth = 1.5
        setupEdgeHandlesLayer.shadowColor = NSColor.black.cgColor
        setupEdgeHandlesLayer.shadowOpacity = 0.3
        setupEdgeHandlesLayer.shadowRadius = 3
        setupEdgeHandlesLayer.shadowOffset = CGSize(width: 0, height: -1)
        root.addSublayer(setupEdgeHandlesLayer)

        badgeBackgroundLayer.fillColor = CGColor(red: 0.08, green: 0.09, blue: 0.13, alpha: 0.9)
        badgeBackgroundLayer.strokeColor = CGColor(gray: 1.0, alpha: 0.25)
        badgeBackgroundLayer.lineWidth = 1
        badgeBackgroundLayer.shadowColor = NSColor.black.cgColor
        badgeBackgroundLayer.shadowOpacity = 0.45
        badgeBackgroundLayer.shadowRadius = 5
        badgeBackgroundLayer.shadowOffset = CGSize(width: 0, height: -2)
        root.addSublayer(badgeBackgroundLayer)

        badgeTextLayer.alignmentMode = .center
        badgeTextLayer.fontSize = 11
        badgeTextLayer.foregroundColor = NSColor.white.cgColor
        badgeTextLayer.font = badgeFont
        root.addSublayer(badgeTextLayer)

        updateLayerContentsScale()
        updateLayersVisibility()
        updateLayerPaths()
    }

    private func updateLayerContentsScale() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        for sublayer in [
            recordingBorderLayer,
            recordingCornerLayer,
            setupBorderLayer,
            setupInnerBorderLayer,
            setupCornerHandlesLayer,
            setupEdgeHandlesLayer,
            badgeBackgroundLayer,
            badgeTextLayer
        ] {
            sublayer.contentsScale = scale
        }
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

    private func clampedRoundedRectPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
        let clampedR = max(0, min(radius, min(rect.width, rect.height) / 2))
        return CGPath(roundedRect: rect, cornerWidth: clampedR, cornerHeight: clampedR, transform: nil)
    }

    private func updateRecordingLayerPaths() {
        // Красная рамка рисуется снаружи innerBounds (вне области захвата)
        let strokeRect = innerBounds.insetBy(dx: -1.5, dy: -1.5)
        guard strokeRect.width > 0, strokeRect.height > 0 else { return }
        recordingBorderLayer.path = clampedRoundedRectPath(strokeRect, radius: 6)
        recordingBorderLayer.frame = bounds

        let cornerLen: CGFloat = min(16, strokeRect.width / 3, strokeRect.height / 3)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: strokeRect.minX, y: strokeRect.minY + cornerLen))
        path.addLine(to: CGPoint(x: strokeRect.minX, y: strokeRect.minY))
        path.addLine(to: CGPoint(x: strokeRect.minX + cornerLen, y: strokeRect.minY))

        path.move(to: CGPoint(x: strokeRect.maxX - cornerLen, y: strokeRect.minY))
        path.addLine(to: CGPoint(x: strokeRect.maxX, y: strokeRect.minY))
        path.addLine(to: CGPoint(x: strokeRect.maxX, y: strokeRect.minY + cornerLen))

        path.move(to: CGPoint(x: strokeRect.maxX, y: strokeRect.maxY - cornerLen))
        path.addLine(to: CGPoint(x: strokeRect.maxX, y: strokeRect.maxY))
        path.addLine(to: CGPoint(x: strokeRect.maxX - cornerLen, y: strokeRect.maxY))

        path.move(to: CGPoint(x: strokeRect.minX + cornerLen, y: strokeRect.maxY))
        path.addLine(to: CGPoint(x: strokeRect.minX, y: strokeRect.maxY))
        path.addLine(to: CGPoint(x: strokeRect.minX, y: strokeRect.maxY - cornerLen))

        recordingCornerLayer.path = path
        recordingCornerLayer.frame = bounds
    }

    private func handleSpecs(for box: CGRect) -> [HandleSpec] {
        let s = cornerHandleSize
        let el = edgeHandleLength
        let et = edgeHandleThickness
        let hs = hitSlop

        func cornerSpec(_ target: HitTarget, center: CGPoint) -> HandleSpec {
            let visual = CGRect(x: center.x - s / 2, y: center.y - s / 2, width: s, height: s)
            let hit = CGRect(x: center.x - hs * 1.5, y: center.y - hs * 1.5, width: hs * 3, height: hs * 3)
            return HandleSpec(target: target, isCorner: true, visualRect: visual, hitRect: hit, cursor: .crosshair)
        }

        func horizontalEdgeSpec(_ target: HitTarget, center: CGPoint) -> HandleSpec {
            let visual = CGRect(x: center.x - el / 2, y: center.y - et / 2, width: el, height: et)
            let hit = CGRect(x: center.x - el, y: center.y - hs * 1.25, width: el * 2, height: hs * 2.5)
            return HandleSpec(target: target, isCorner: false, visualRect: visual, hitRect: hit, cursor: .resizeUpDown)
        }

        func verticalEdgeSpec(_ target: HitTarget, center: CGPoint) -> HandleSpec {
            let visual = CGRect(x: center.x - et / 2, y: center.y - el / 2, width: et, height: el)
            let hit = CGRect(x: center.x - hs * 1.25, y: center.y - el, width: hs * 2.5, height: el * 2)
            return HandleSpec(target: target, isCorner: false, visualRect: visual, hitRect: hit, cursor: .resizeLeftRight)
        }

        return [
            cornerSpec(.topLeft, center: CGPoint(x: box.minX, y: box.maxY)),
            cornerSpec(.topRight, center: CGPoint(x: box.maxX, y: box.maxY)),
            cornerSpec(.bottomLeft, center: CGPoint(x: box.minX, y: box.minY)),
            cornerSpec(.bottomRight, center: CGPoint(x: box.maxX, y: box.minY)),
            horizontalEdgeSpec(.topCenter, center: CGPoint(x: box.midX, y: box.maxY)),
            horizontalEdgeSpec(.bottomCenter, center: CGPoint(x: box.midX, y: box.minY)),
            verticalEdgeSpec(.leftCenter, center: CGPoint(x: box.minX, y: box.midY)),
            verticalEdgeSpec(.rightCenter, center: CGPoint(x: box.maxX, y: box.midY))
        ]
    }

    private func updateSetupLayerPaths() {
        let box = innerBounds
        guard box.width > 0, box.height > 0 else { return }

        let outerBorder = box.insetBy(dx: -1, dy: -1)
        setupBorderLayer.path = clampedRoundedRectPath(outerBorder, radius: 4)
        setupBorderLayer.frame = bounds

        let innerBorder = box.insetBy(dx: 0.5, dy: 0.5)
        setupInnerBorderLayer.path = clampedRoundedRectPath(innerBorder, radius: 3)
        setupInnerBorderLayer.frame = bounds

        let cornerPath = CGMutablePath()
        let edgePath = CGMutablePath()
        for spec in handleSpecs(for: box) {
            if spec.isCorner {
                let r = min(3, min(spec.visualRect.width, spec.visualRect.height) / 2)
                cornerPath.addRoundedRect(in: spec.visualRect, cornerWidth: r, cornerHeight: r)
            } else {
                let r = min(edgeHandleThickness / 2, min(spec.visualRect.width, spec.visualRect.height) / 2)
                edgePath.addRoundedRect(in: spec.visualRect, cornerWidth: r, cornerHeight: r)
            }
        }
        setupCornerHandlesLayer.path = cornerPath
        setupCornerHandlesLayer.frame = bounds
        setupEdgeHandlesLayer.path = edgePath
        setupEdgeHandlesLayer.frame = bounds

        // Динамическая ширина бейджа под фактический текст
        let w = Int(box.width.rounded())
        let h = Int(box.height.rounded())
        let ratioStr = aspectString(width: box.width, height: box.height)
        let dimString = ratioStr.isEmpty ? "\(w) × \(h)" : "\(w) × \(h) • \(ratioStr)"
        badgeTextLayer.string = dimString

        let textSize = (dimString as NSString).size(withAttributes: [.font: badgeFont])
        let maxAllowedWidth = max(40, box.width - 12)
        let badgeW = min(maxAllowedWidth, max(88, ceil(textSize.width) + 24))
        let badgeH: CGFloat = 24
        var badgeY = box.maxY - badgeH - 10
        if badgeY < box.minY + 12 {
            badgeY = box.minY + 10
        }
        let badgeX = min(
            max(box.minX + 6, box.midX - badgeW / 2),
            max(box.minX + 6, box.maxX - badgeW - 6)
        )
        let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeW, height: badgeH)
        badgeBackgroundLayer.path = clampedRoundedRectPath(badgeRect, radius: 6)
        badgeBackgroundLayer.frame = bounds

        badgeTextLayer.frame = CGRect(
            x: badgeRect.origin.x + 4,
            y: badgeRect.origin.y + 4.5,
            width: max(1, badgeW - 8),
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
        let box = innerBounds
        for spec in handleSpecs(for: box) where spec.hitRect.contains(pt) {
            return spec.target
        }
        if box.contains(pt) {
            return .move
        }
        return .none
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard mode == .setup else { return }

        let box = innerBounds
        for spec in handleSpecs(for: box) {
            addCursorRect(spec.hitRect, cursor: spec.cursor)
        }

        let inner = box.insetBy(dx: hitSlop, dy: hitSlop)
        if inner.width > 0 && inner.height > 0 {
            addCursorRect(inner, cursor: .openHand)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        guard mode == .setup, let win = window as? RecordingFrameWindow else {
            super.mouseDown(with: event)
            return
        }

        let loc = convert(event.locationInWindow, from: nil)
        activeHitTarget = hitTestTarget(at: loc)
        initialMouseScreenLoc = NSEvent.mouseLocation
        initialInnerFrame = win.frame.insetBy(dx: framePad, dy: framePad)

        if activeHitTarget == .move {
            NSCursor.closedHand.set()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard mode == .setup, let win = window as? RecordingFrameWindow, activeHitTarget != .none else {
            super.mouseDragged(with: event)
            return
        }

        let currentMouse = NSEvent.mouseLocation
        let dx = currentMouse.x - initialMouseScreenLoc.x
        let dy = currentMouse.y - initialMouseScreenLoc.y

        let minW: CGFloat = 160
        let minH: CGFloat = 120
        let boundsFrame = ScreenCoordinateSpace.targetScreen(for: initialInnerFrame)?.frame
        var newInner = initialInnerFrame

        switch activeHitTarget {
        case .move:
            newInner.origin.x = initialInnerFrame.origin.x + dx
            newInner.origin.y = initialInnerFrame.origin.y + dy
            if let screen = boundsFrame {
                newInner.origin.x = min(max(screen.minX, newInner.origin.x), screen.maxX - newInner.width)
                newInner.origin.y = min(max(screen.minY, newInner.origin.y), screen.maxY - newInner.height)
            }

        case .topRight:
            var w = max(minW, initialInnerFrame.width + dx)
            var h = max(minH, initialInnerFrame.height + dy)
            if let screen = boundsFrame {
                w = min(w, max(minW, screen.maxX - initialInnerFrame.minX))
                h = min(h, max(minH, screen.maxY - initialInnerFrame.minY))
            }
            newInner = CGRect(x: initialInnerFrame.minX, y: initialInnerFrame.minY, width: w, height: h)

        case .topLeft:
            var w = max(minW, initialInnerFrame.width - dx)
            var h = max(minH, initialInnerFrame.height + dy)
            if let screen = boundsFrame {
                w = min(w, max(minW, initialInnerFrame.maxX - screen.minX))
                h = min(h, max(minH, screen.maxY - initialInnerFrame.minY))
            }
            newInner = CGRect(x: initialInnerFrame.maxX - w, y: initialInnerFrame.minY, width: w, height: h)

        case .bottomRight:
            var w = max(minW, initialInnerFrame.width + dx)
            var h = max(minH, initialInnerFrame.height - dy)
            if let screen = boundsFrame {
                w = min(w, max(minW, screen.maxX - initialInnerFrame.minX))
                h = min(h, max(minH, initialInnerFrame.maxY - screen.minY))
            }
            newInner = CGRect(x: initialInnerFrame.minX, y: initialInnerFrame.maxY - h, width: w, height: h)

        case .bottomLeft:
            var w = max(minW, initialInnerFrame.width - dx)
            var h = max(minH, initialInnerFrame.height - dy)
            if let screen = boundsFrame {
                w = min(w, max(minW, initialInnerFrame.maxX - screen.minX))
                h = min(h, max(minH, initialInnerFrame.maxY - screen.minY))
            }
            newInner = CGRect(x: initialInnerFrame.maxX - w, y: initialInnerFrame.maxY - h, width: w, height: h)

        case .rightCenter:
            var w = max(minW, initialInnerFrame.width + dx)
            if let screen = boundsFrame {
                w = min(w, max(minW, screen.maxX - initialInnerFrame.minX))
            }
            newInner = CGRect(x: initialInnerFrame.minX, y: initialInnerFrame.minY, width: w, height: initialInnerFrame.height)

        case .leftCenter:
            var w = max(minW, initialInnerFrame.width - dx)
            if let screen = boundsFrame {
                w = min(w, max(minW, initialInnerFrame.maxX - screen.minX))
            }
            newInner = CGRect(x: initialInnerFrame.maxX - w, y: initialInnerFrame.minY, width: w, height: initialInnerFrame.height)

        case .topCenter:
            var h = max(minH, initialInnerFrame.height + dy)
            if let screen = boundsFrame {
                h = min(h, max(minH, screen.maxY - initialInnerFrame.minY))
            }
            newInner = CGRect(x: initialInnerFrame.minX, y: initialInnerFrame.minY, width: initialInnerFrame.width, height: h)

        case .bottomCenter:
            var h = max(minH, initialInnerFrame.height - dy)
            if let screen = boundsFrame {
                h = min(h, max(minH, initialInnerFrame.maxY - screen.minY))
            }
            newInner = CGRect(x: initialInnerFrame.minX, y: initialInnerFrame.maxY - h, width: initialInnerFrame.width, height: h)

        case .none:
            break
        }

        win.updateInnerRect(newInner)
        win.setFrame(newInner.insetBy(dx: -framePad, dy: -framePad), display: true)
        onRectChanged?(newInner)
    }

    override func mouseUp(with event: NSEvent) {
        guard mode == .setup, let win = window as? RecordingFrameWindow else {
            super.mouseUp(with: event)
            return
        }

        if activeHitTarget == .move {
            NSCursor.openHand.set()
        }
        activeHitTarget = .none

        // Размеры области видеозаписи должны быть четными для аппаратного H.264
        var inner = win.frame.insetBy(dx: framePad, dy: framePad)
        let w = Int(inner.width.rounded())
        let h = Int(inner.height.rounded())
        let evenW = max(2, w - (w % 2))
        let evenH = max(2, h - (h % 2))
        inner = CGRect(
            x: inner.origin.x.rounded(),
            y: inner.origin.y.rounded(),
            width: CGFloat(evenW),
            height: CGFloat(evenH)
        )
        win.updateInnerRect(inner)
        win.setFrame(inner.insetBy(dx: -framePad, dy: -framePad), display: true)
        onRectChanged?(inner)
        win.invalidateCursorRects(for: self)
    }
}
