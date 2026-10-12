import Cocoa
import ScreenCaptureKit

/// Представление полноэкранного окна оверлея
public final class AreaOverlayWindow: NSWindow {
    public init(
        screen: NSScreen,
        mode: OverlayMode,
        visibleWindows: [SCWindow] = [],
        onCompleteRect: @escaping (CGRect) -> Void,
        onCompleteWindow: @escaping (SCWindow) -> Void,
        onCancel: @escaping () -> Void
    ) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.isOpaque = false
        self.isReleasedWhenClosed = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        
        let overlayView = AreaSelectionNSView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            mode: mode,
            visibleWindows: visibleWindows,
            onCompleteRect: onCompleteRect,
            onCompleteWindow: onCompleteWindow,
            onCancel: onCancel
        )
        self.contentView = overlayView
    }
    
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
}
