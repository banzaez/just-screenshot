import Cocoa
import QuartzCore

/// Полноэкранное окно затемнения пространства вокруг выбранной области записи.
/// Использует аппаратную векторную маску CALayer с правилом evenOdd — практически 0% нагрузки на CPU/GPU.
/// Исключается из захвата видео ScreenCaptureKit через JustScreenshotWindowTitles.
public final class RecordingDimOverlayWindow: NSWindow {
    private let dimView: RecordingDimOverlayNSView
    public let screenID: CGDirectDisplayID
    
    public init(screen: NSScreen, holeRect: CGRect?) {
        self.screenID = screen.displayID
        self.dimView = RecordingDimOverlayNSView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            screenFrame: screen.frame,
            holeRect: holeRect
        )
        
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.title = JustScreenshotWindowTitles.recordingDim
        self.level = .floating - 1
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true // Никогда не блокирует клики мыши пользователя
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.animationBehavior = .none
        self.isReleasedWhenClosed = false
        
        self.contentView = dimView
    }
    
    public func updateHole(appKitRect: CGRect?) {
        dimView.updateHole(appKitRect: appKitRect)
    }
}

@MainActor
private final class RecordingDimOverlayNSView: NSView {
    private let screenFrame: CGRect
    private let dimLayer = CALayer()
    private let maskLayer = CAShapeLayer()
    
    init(frame: NSRect, screenFrame: CGRect, holeRect: CGRect?) {
        self.screenFrame = screenFrame
        super.init(frame: frame)
        wantsLayer = true
        setupLayers()
        updateHole(appKitRect: holeRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayers() {
        guard let root = layer else { return }
        root.backgroundColor = NSColor.clear.cgColor
        
        dimLayer.frame = bounds
        // Мягкое элегантное затемнение (38% черноты)
        dimLayer.backgroundColor = CGColor(gray: 0, alpha: 0.38)
        maskLayer.fillColor = NSColor.white.cgColor
        maskLayer.fillRule = .evenOdd
        dimLayer.mask = maskLayer
        
        root.addSublayer(dimLayer)
    }
    
    func updateHole(appKitRect: CGRect?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        
        dimLayer.frame = bounds
        let path = CGMutablePath()
        path.addRect(bounds)
        
        if let appKitRect, appKitRect.intersects(screenFrame) {
            let localX = appKitRect.origin.x - screenFrame.origin.x
            let localY = appKitRect.origin.y - screenFrame.origin.y
            let localRect = CGRect(x: localX, y: localY, width: appKitRect.width, height: appKitRect.height)
            path.addRect(localRect)
        }
        
        maskLayer.path = path
        maskLayer.frame = bounds
    }
}
