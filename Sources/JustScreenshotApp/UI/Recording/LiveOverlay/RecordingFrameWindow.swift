import Cocoa
import QuartzCore

/// Прозрачное окно-рамка поверх выбранной области экрана, показывающее границы записи.
/// Рамка — статичный CAShapeLayer; ripples/keystrokes перерисовываются только в своей зоне.
public final class RecordingFrameWindow: NSWindow {
    public init(screenRect: CGRect) {
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        title = JustScreenshotWindowTitles.recordingFrame
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .none
        
        contentView = RecordingBorderNSView(frame: NSRect(origin: .zero, size: screenRect.size))
    }
}

@MainActor
private final class RecordingBorderNSView: NSView {
    private var ripples: [RecordingOverlayRenderer.ClickRipple] = []
    private var currentKeystroke: RecordingOverlayRenderer.KeystrokeInfo?
    private var monitor: Any?
    private var keyMonitor: Any?
    private var animationTask: Task<Void, Never>?
    private let borderLayer = CAShapeLayer()
    private let cornerLayer = CAShapeLayer()
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setupBorderLayers()
        setupClickMonitoring()
        setupKeyboardMonitoring()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            cleanUp()
        }
    }
    
    override func layout() {
        super.layout()
        updateBorderPaths()
    }
    
    private func setupBorderLayers() {
        guard let root = layer else { return }
        root.backgroundColor = NSColor.clear.cgColor
        
        borderLayer.fillColor = nil
        borderLayer.strokeColor = CGColor(red: 1.0, green: 0.22, blue: 0.22, alpha: 0.9)
        borderLayer.lineWidth = 3
        borderLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        root.addSublayer(borderLayer)
        
        cornerLayer.fillColor = nil
        cornerLayer.strokeColor = CGColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1)
        cornerLayer.lineWidth = 4
        cornerLayer.lineCap = .round
        cornerLayer.lineJoin = .round
        cornerLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        root.addSublayer(cornerLayer)
        
        updateBorderPaths()
    }
    
    private func updateBorderPaths() {
        let inset = bounds.insetBy(dx: 1.5, dy: 1.5)
        borderLayer.path = CGPath(roundedRect: inset, cornerWidth: 6, cornerHeight: 6, transform: nil)
        borderLayer.frame = bounds
        
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
        
        cornerLayer.path = path
        cornerLayer.frame = bounds
    }
    
    private func cleanUp() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        animationTask?.cancel()
        animationTask = nil
    }
    
    private func setupKeyboardMonitoring() {
        guard AppSettings.shared.showKeystrokesDuringRecording else { return }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let text = KeystrokeFormatter.format(event: event) else { return }
                self.invalidateEffectsRegion()
                self.currentKeystroke = RecordingOverlayRenderer.KeystrokeInfo(text: text, startTime: Date())
                self.startAnimationIfNeeded()
                self.invalidateEffectsRegion()
            }
        }
    }
    
    private func setupClickMonitoring() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, let win = self.window else { return }
                let clickScreenLoc = event.locationInWindow
                let windowFrame = win.frame
                if windowFrame.contains(clickScreenLoc) {
                    let localX = clickScreenLoc.x - windowFrame.origin.x
                    let localY = clickScreenLoc.y - windowFrame.origin.y
                    self.addRipple(at: CGPoint(x: localX, y: localY))
                }
            }
        }
    }
    
    private func addRipple(at point: CGPoint) {
        ripples.append(RecordingOverlayRenderer.ClickRipple(center: point, startTime: Date()))
        startAnimationIfNeeded()
        setNeedsDisplay(rippleDirtyRect(around: point))
    }
    
    private func startAnimationIfNeeded() {
        guard animationTask == nil else { return }
        animationTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                let now = Date()
                let oldRipples = self.ripples
                self.ripples.removeAll { now.timeIntervalSince($0.startTime) > 0.45 }
                
                if let ks = self.currentKeystroke, now.timeIntervalSince(ks.startTime) > 1.2 {
                    self.invalidateEffectsRegion()
                    self.currentKeystroke = nil
                }
                
                for ripple in oldRipples {
                    self.setNeedsDisplay(self.rippleDirtyRect(around: ripple.center))
                }
                if self.currentKeystroke != nil {
                    self.invalidateEffectsRegion()
                }
                
                if self.ripples.isEmpty && self.currentKeystroke == nil {
                    self.animationTask = nil
                    break
                }
            }
        }
    }
    
    private func rippleDirtyRect(around point: CGPoint) -> NSRect {
        let r: CGFloat = 40
        return NSRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)
            .intersection(bounds.insetBy(dx: -2, dy: -2))
    }
    
    private func invalidateEffectsRegion() {
        // Нижняя зона бейджа клавиш + центр
        let badge = NSRect(x: 0, y: 0, width: bounds.width, height: min(80, bounds.height))
        setNeedsDisplay(badge)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        // Рамка рисуется слоями; здесь только динамические эффекты.
        RecordingOverlayRenderer.drawRipples(ripples, now: Date(), in: context)
        
        if let ks = currentKeystroke {
            let progress = Date().timeIntervalSince(ks.startTime)
            let alpha = progress > 0.9 ? max(0, 1.0 - (progress - 0.9) / 0.3) : 1.0
            RecordingOverlayRenderer.drawKeystrokeBadge(text: ks.text, alpha: CGFloat(alpha), bounds: bounds, in: context)
        }
    }
}
