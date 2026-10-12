import Cocoa
import ScreenCaptureKit

/// Представление полноэкранного окна оверлея
public final class AreaOverlayWindow: NSWindow {
    private let onCancel: () -> Void

    public init(
        screen: NSScreen,
        mode: OverlayMode,
        visibleWindows: [SCWindow] = [],
        backgroundImage: CGImage? = nil,
        onCompleteRect: @escaping (CGRect) -> Void,
        onCompleteWindow: @escaping (SCWindow) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onCancel = onCancel
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.title = "JustScreenshotAreaOverlay"
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.isReleasedWhenClosed = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        
        let overlayView = AreaSelectionNSView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            screen: screen,
            mode: mode,
            visibleWindows: visibleWindows,
            backgroundImage: backgroundImage,
            onCompleteRect: onCompleteRect,
            onCompleteWindow: onCompleteWindow,
            onCancel: onCancel
        )
        self.contentView = overlayView
    }
    
    public func updateSampler(_ sampler: ScreenPixelSampler) {
        (contentView as? AreaSelectionNSView)?.updateSampler(sampler)
    }
    
    public func updateBackgroundImage(_ image: CGImage) {
        (contentView as? AreaSelectionNSView)?.updateBackgroundImage(image)
    }
    
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && event.keyCode == 53 { // ESC key
            onCancel()
            return
        }
        super.sendEvent(event)
    }
    
    public override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
}
