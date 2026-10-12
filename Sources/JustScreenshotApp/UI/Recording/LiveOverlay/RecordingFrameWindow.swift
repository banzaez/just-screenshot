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
    private struct ClickRipple: Sendable {
        let center: CGPoint
        let startTime: Date
    }
    
    private struct KeystrokeInfo: Sendable {
        let text: String
        let startTime: Date
    }
    
    private var ripples: [ClickRipple] = []
    private var currentKeystroke: KeystrokeInfo?
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
                var symbols: [String] = []
                let flags = event.modifierFlags
                if flags.contains(.control) { symbols.append("⌃") }
                if flags.contains(.option) { symbols.append("⌥") }
                if flags.contains(.shift) { symbols.append("⇧") }
                if flags.contains(.command) { symbols.append("⌘") }
                
                if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
                    let first = chars.uppercased()
                    // Если это спец-клавиша (пробел, Enter, Esc и т.д.)
                    switch event.keyCode {
                    case 49: symbols.append("Space")
                    case 36: symbols.append("Return")
                    case 53: symbols.append("Esc")
                    case 51: symbols.append("⌫")
                    case 123: symbols.append("←")
                    case 124: symbols.append("→")
                    case 125: symbols.append("↓")
                    case 126: symbols.append("↑")
                    default:
                        if !symbols.isEmpty || chars.count == 1 {
                            symbols.append(first)
                        }
                    }
                }
                
                guard !symbols.isEmpty else { return }
                self.currentKeystroke = KeystrokeInfo(text: symbols.joined(separator: " "), startTime: Date())
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
        ripples.append(ClickRipple(center: point, startTime: Date()))
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
        
        // Красная пульсирующая/яркая рамка вокруг записываемой области
        let insetRect = bounds.insetBy(dx: 1.5, dy: 1.5)
        context.setStrokeColor(CGColor(red: 1.0, green: 0.22, blue: 0.22, alpha: 0.9))
        context.setLineWidth(3.0)
        
        let path = CGPath(roundedRect: insetRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        context.addPath(path)
        context.strokePath()
        
        // Отрисовка расходящихся кругов при кликах мыши (Click Ripples)
        let now = Date()
        for ripple in ripples {
            let progress = CGFloat(min(1.0, now.timeIntervalSince(ripple.startTime) / 0.45))
            let radius = 8.0 + progress * 24.0
            let alpha = 1.0 - progress
            
            let rect = CGRect(x: ripple.center.x - radius, y: ripple.center.y - radius, width: radius * 2, height: radius * 2)
            context.setStrokeColor(CGColor(red: 1.0, green: 0.85, blue: 0.2, alpha: alpha * 0.85))
            context.setFillColor(CGColor(red: 1.0, green: 0.85, blue: 0.2, alpha: alpha * 0.25))
            context.setLineWidth(2.5)
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
        }
        
        // Маленькие маркеры по 4 углам для визуального акцента
        let cornerLen: CGFloat = 16.0
        context.setLineWidth(4.0)
        context.setStrokeColor(CGColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0))
        
        // Нижний левый угол
        context.move(to: CGPoint(x: bounds.minX + 1.5, y: bounds.minY + cornerLen))
        context.addLine(to: CGPoint(x: bounds.minX + 1.5, y: bounds.minY + 1.5))
        context.addLine(to: CGPoint(x: bounds.minX + cornerLen, y: bounds.minY + 1.5))
        
        // Нижний правый угол
        context.move(to: CGPoint(x: bounds.maxX - cornerLen, y: bounds.minY + 1.5))
        context.addLine(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.minY + 1.5))
        context.addLine(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.minY + cornerLen))
        
        // Верхний правый угол
        context.move(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.maxY - cornerLen))
        context.addLine(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.maxY - 1.5))
        context.addLine(to: CGPoint(x: bounds.maxX - cornerLen, y: bounds.maxY - 1.5))
        
        // Верхний левый угол
        context.move(to: CGPoint(x: bounds.minX + cornerLen, y: bounds.maxY - 1.5))
        context.addLine(to: CGPoint(x: bounds.minX + 1.5, y: bounds.maxY - 1.5))
        context.addLine(to: CGPoint(x: bounds.minX + 1.5, y: bounds.maxY - cornerLen))
        
        context.strokePath()
        
        // Отрисовка плашки нажатых клавиш (Keystrokes HUD)
        if let ks = currentKeystroke {
            let progress = now.timeIntervalSince(ks.startTime)
            let alpha = progress > 0.9 ? max(0, 1.0 - (progress - 0.9) / 0.3) : 1.0
            drawKeystrokeBadge(text: ks.text, alpha: CGFloat(alpha), in: context)
        }
    }
    
    private func drawKeystrokeBadge(text: String, alpha: CGFloat, in context: CGContext) {
        let nsText = text as NSString
        let font = NSFont.systemFont(ofSize: 15, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(alpha)
        ]
        let textSize = nsText.size(withAttributes: attrs)
        let badgeRect = CGRect(
            x: bounds.midX - textSize.width / 2 - 14,
            y: max(16, bounds.minY + 20),
            width: textSize.width + 28,
            height: textSize.height + 14
        )
        let path = CGPath(roundedRect: badgeRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: CGColor(gray: 0, alpha: 0.5 * alpha))
        context.setFillColor(CGColor(gray: 0.08, alpha: 0.88 * alpha))
        context.addPath(path)
        context.fillPath()
        
        context.setStrokeColor(CGColor(gray: 1.0, alpha: 0.25 * alpha))
        context.setLineWidth(1.0)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
        
        nsText.draw(at: CGPoint(x: badgeRect.origin.x + 14, y: badgeRect.origin.y + 7), withAttributes: attrs)
    }
}
