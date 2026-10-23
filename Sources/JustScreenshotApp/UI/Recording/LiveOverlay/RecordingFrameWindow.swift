import Cocoa
import QuartzCore

/// Прозрачное окно-рамка поверх выбранной области экрана, показывающее границы записи.
/// Исключается из видеозаписи через ScreenCaptureKit, чтобы красная граница не попадала в видео.
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
    private let borderLayer = CAShapeLayer()
    private let cornerLayer = CAShapeLayer()
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setupBorderLayers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
}
