import Cocoa
import QuartzCore

/// Прозрачное сквозное окно поверх зоны записи для отображения динамических эффектов:
/// подсветки кликов мыши (ripples) и бейджей нажатых горячих клавиш (keystrokes).
/// В отличие от рамки, это окно захватывается ScreenCaptureKit и попадает в итоговое видео.
public final class RecordingEffectsOverlayWindow: NSWindow {
    private let effectsView: RecordingEffectsNSView

    public init(screenRect: CGRect) {
        self.effectsView = RecordingEffectsNSView(frame: NSRect(origin: .zero, size: screenRect.size))

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
        isReleasedWhenClosed = false

        contentView = effectsView
    }

    public func cleanUp() {
        effectsView.cleanUp()
    }

    public override func close() {
        effectsView.cleanUp()
        super.close()
    }
}

@MainActor
private final class RecordingEffectsNSView: NSView {
    private var ripples: [RecordingOverlayRenderer.ClickRipple] = []
    private var currentKeystroke: RecordingOverlayRenderer.KeystrokeInfo?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
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

    func cleanUp() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
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

    private func handleClickEvent(_ event: NSEvent) {
        guard !AppWindowManager.shared.isRecordingPaused else { return }
        guard let win = window, win.isVisible else { return }
        let screenLoc = NSEvent.mouseLocation
        let windowFrame = win.frame
        guard windowFrame.contains(screenLoc) else { return }

        let localPoint = CGPoint(
            x: screenLoc.x - windowFrame.origin.x,
            y: screenLoc.y - windowFrame.origin.y
        )
        addRipple(at: localPoint, isRightClick: event.type == .rightMouseDown)
    }

    private func setupClickMonitoring() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleClickEvent(event)
            }
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleClickEvent(event)
            }
            return event
        }
    }

    private func setupKeyboardMonitoring() {
        if !AccessibilityPermissionHelper.isGranted {
            AccessibilityPermissionHelper.requestAccess(openSettings: false)
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyEvent(event)
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyEvent(event)
            }
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard !AppWindowManager.shared.isRecordingPaused else { return }
        guard let text = KeystrokeFormatter.format(event: event) else { return }
        currentKeystroke = RecordingOverlayRenderer.KeystrokeInfo(text: text, startTime: Date())
        restartAnimationLoop()
        needsDisplay = true
    }

    private func addRipple(at point: CGPoint, isRightClick: Bool = false) {
        ripples.append(RecordingOverlayRenderer.ClickRipple(center: point, startTime: Date(), isRightClick: isRightClick))
        restartAnimationLoop()
        needsDisplay = true
    }

    private func restartAnimationLoop() {
        animationTask?.cancel()
        animationTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                let now = Date()
                self.ripples.removeAll { now.timeIntervalSince($0.startTime) > 0.45 }
                if let ks = self.currentKeystroke, now.timeIntervalSince(ks.startTime) > 1.4 {
                    self.currentKeystroke = nil
                }

                if self.ripples.isEmpty && self.currentKeystroke == nil {
                    self.needsDisplay = true
                    self.animationTask = nil
                    break
                }

                // Когда нет ripples и плашка клавиш статично удерживается (< 1.0с), спим ровно до начала fade-out
                let sleepDurationNs: UInt64
                if self.ripples.isEmpty,
                   let ks = self.currentKeystroke {
                    let elapsed = now.timeIntervalSince(ks.startTime)
                    if elapsed < 1.0 {
                        let remaining = max(0.016, 1.0 - elapsed)
                        sleepDurationNs = UInt64(remaining * 1_000_000_000)
                    } else {
                        sleepDurationNs = 16_000_000
                    }
                } else {
                    sleepDurationNs = 16_000_000 // ~60 FPS для плавной анимации ripple/fade
                }

                try? await Task.sleep(nanoseconds: sleepDurationNs)
                guard !Task.isCancelled else { break }

                let tickNow = Date()
                self.ripples.removeAll { tickNow.timeIntervalSince($0.startTime) > 0.45 }
                if let ks = self.currentKeystroke, tickNow.timeIntervalSince(ks.startTime) > 1.4 {
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

        let now = Date()
        RecordingOverlayRenderer.drawRipples(ripples, now: now, in: context)

        if let ks = currentKeystroke {
            let progress = now.timeIntervalSince(ks.startTime)
            let alpha = progress > 1.0 ? max(0, 1.0 - (progress - 1.0) / 0.4) : 1.0
            RecordingOverlayRenderer.drawKeystrokeBadge(text: ks.text, alpha: CGFloat(alpha), bounds: bounds, in: context)
        }
    }
}
