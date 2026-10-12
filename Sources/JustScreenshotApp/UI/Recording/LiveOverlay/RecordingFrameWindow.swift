import Cocoa

/// Прозрачное окно-рамка поверх выбранной области экрана, показывающее границы записи
public final class RecordingFrameWindow: NSWindow {
    public init(screenRect: CGRect) {
        // screenRect здесь в экранных координатах AppKit (origin внизу экрана)
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true // Клики проходят сквозь рамку в приложения под ней
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let borderView = RecordingBorderNSView(frame: NSRect(origin: .zero, size: screenRect.size))
        self.contentView = borderView
    }
}

@MainActor
private final class RecordingBorderNSView: NSView {
    private var ripples: [RecordingOverlayRenderer.ClickRipple] = []
    private var currentKeystroke: RecordingOverlayRenderer.KeystrokeInfo?
    private var monitor: Any?
    private var keyMonitor: Any?
    private var animationTask: Task<Void, Never>?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
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
    
    private func cleanUp() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        animationTask?.cancel()
        animationTask = nil
    }
    
    private func setupKeyboardMonitoring() {
        guard AppSettings.shared.showKeystrokesDuringRecording else { return }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let text = KeystrokeFormatter.format(event: event) else { return }
                self.currentKeystroke = RecordingOverlayRenderer.KeystrokeInfo(text: text, startTime: Date())
                self.startAnimationIfNeeded()
                self.needsDisplay = true
            }
        }
    }
    
    private func setupClickMonitoring() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, let win = self.window else { return }
                let clickScreenLoc = event.locationInWindow // В экранных координатах AppKit
                let windowFrame = win.frame
                
                // Проверяем, произошел ли клик внутри записываемой рамки
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
        needsDisplay = true
    }
    
    private func startAnimationIfNeeded() {
        if animationTask == nil {
            animationTask = Task { @MainActor [weak self] in
                while let self, !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 16_000_000) // ~60 fps
                    let now = Date()
                    self.ripples.removeAll { now.timeIntervalSince($0.startTime) > 0.45 }
                    
                    if let ks = self.currentKeystroke, now.timeIntervalSince(ks.startTime) > 1.2 {
                        self.currentKeystroke = nil
                    }
                    
                    self.needsDisplay = true
                    if self.ripples.isEmpty && self.currentKeystroke == nil {
                        self.animationTask = nil
                        break
                    }
                }
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        RecordingOverlayRenderer.drawBorder(bounds: bounds, in: context)
        RecordingOverlayRenderer.drawRipples(ripples, now: Date(), in: context)
        
        if let ks = currentKeystroke {
            let progress = Date().timeIntervalSince(ks.startTime)
            let alpha = progress > 0.9 ? max(0, 1.0 - (progress - 0.9) / 0.3) : 1.0
            RecordingOverlayRenderer.drawKeystrokeBadge(text: ks.text, alpha: CGFloat(alpha), bounds: bounds, in: context)
        }
    }
}
