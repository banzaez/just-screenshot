import Cocoa
import QuartzCore

/// Прозрачное сквозное окно поверх зоны записи для отображения динамических эффектов:
/// подсветки кликов мыши (ripples) и бейджей нажатых горячих клавиш (keystrokes).
/// В отличие от рамки, это окно захватывается ScreenCaptureKit и попадает в итоговое видео.
public final class RecordingEffectsOverlayWindow: NSWindow {
    public init(screenRect: CGRect) {
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        title = JustScreenshotWindowTitles.recordingEffects
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .none
        
        contentView = RecordingEffectsNSView(frame: NSRect(origin: .zero, size: screenRect.size))
    }
}

@MainActor
private final class RecordingEffectsNSView: NSView {
    private var ripples: [RecordingOverlayRenderer.ClickRipple] = []
    private var currentKeystroke: RecordingOverlayRenderer.KeystrokeInfo?
    private var clickMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var animationTask: Task<Void, Never>?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupMonitoring()
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
    
    private func setupMonitoring() {
        if AppSettings.shared.showClicksDuringRecording {
            setupClickMonitoring()
        }
        if AppSettings.shared.showKeystrokesDuringRecording {
            setupKeyboardMonitoring()
        }
    }
    
    private func cleanUp() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        animationTask?.cancel()
        animationTask = nil
    }
    
    private func setupClickMonitoring() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
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
    
    private func setupKeyboardMonitoring() {
        // В macOS глобальный перехват клавиш требует разрешения «Универсальный доступ» (Accessibility)
        if !AccessibilityPermissionHelper.isGranted {
            AccessibilityPermissionHelper.requestAccess()
        }
        
        // 1. Глобальный монитор (когда активны другие приложения)
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyEvent(event)
            }
        }
        
        // 2. Локальный монитор (когда активно само Just Screenshot)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyEvent(event)
            }
            return event
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        guard let text = KeystrokeFormatter.format(event: event) else { return }
        currentKeystroke = RecordingOverlayRenderer.KeystrokeInfo(text: text, startTime: Date())
        startAnimationIfNeeded()
        needsDisplay = true
    }
    
    private func addRipple(at point: CGPoint) {
        ripples.append(RecordingOverlayRenderer.ClickRipple(center: point, startTime: Date()))
        startAnimationIfNeeded()
        needsDisplay = true
    }
    
    private func startAnimationIfNeeded() {
        guard animationTask == nil else { return }
        animationTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000) // ~60 FPS
                let now = Date()
                self.ripples.removeAll { now.timeIntervalSince($0.startTime) > 0.45 }
                
                if let ks = self.currentKeystroke, now.timeIntervalSince(ks.startTime) > 1.4 {
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
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        RecordingOverlayRenderer.drawRipples(ripples, now: Date(), in: context)
        
        if let ks = currentKeystroke {
            let progress = Date().timeIntervalSince(ks.startTime)
            let alpha = progress > 1.0 ? max(0, 1.0 - (progress - 1.0) / 0.4) : 1.0
            RecordingOverlayRenderer.drawKeystrokeBadge(text: ks.text, alpha: CGFloat(alpha), bounds: bounds, in: context)
        }
    }
}
