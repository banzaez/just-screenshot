import Cocoa
import ScreenCaptureKit

/// Полноэкранное окно оверлея. Переиспользуется из пула без повторного alloc.
public final class AreaOverlayWindow: NSWindow {
    private(set) var screenID: CGDirectDisplayID
    
    public init(screen: NSScreen) {
        self.screenID = screen.displayID
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        title = JustScreenshotWindowTitles.areaOverlay
        level = .screenSaver
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        
        let overlayView = AreaSelectionNSView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            screen: screen,
            mode: .areaOnly,
            visibleWindows: [],
            onCompleteRect: { _ in },
            onCompleteWindow: { _ in },
            onCancel: {}
        )
        contentView = overlayView
    }
    
    public func configure(
        screen: NSScreen,
        mode: OverlayMode,
        visibleWindows: [SCWindow] = [],
        backgroundImage: CGImage? = nil,
        onCompleteRect: @escaping (CGRect) -> Void,
        onCompleteWindow: @escaping (SCWindow) -> Void,
        onCancel: @escaping () -> Void,
        onNeedBackgroundSample: (() -> Void)? = nil
    ) {
        screenID = screen.displayID
        setFrame(screen.frame, display: false)
        alphaValue = 1
        
        let view: AreaSelectionNSView
        if let existing = contentView as? AreaSelectionNSView {
            view = existing
            view.isHidden = false
            view.frame = NSRect(origin: .zero, size: screen.frame.size)
        } else {
            view = AreaSelectionNSView(
                frame: NSRect(origin: .zero, size: screen.frame.size),
                screen: screen,
                mode: mode,
                visibleWindows: visibleWindows,
                backgroundImage: backgroundImage,
                onCompleteRect: onCompleteRect,
                onCompleteWindow: onCompleteWindow,
                onCancel: onCancel,
                onNeedBackgroundSample: onNeedBackgroundSample
            )
            contentView = view
            return
        }
        
        view.reconfigure(
            screen: screen,
            mode: mode,
            visibleWindows: visibleWindows,
            backgroundImage: backgroundImage,
            onCompleteRect: onCompleteRect,
            onCompleteWindow: onCompleteWindow,
            onCancel: onCancel,
            onNeedBackgroundSample: onNeedBackgroundSample
        )
    }
    
    public func prepareForReuse() {
        alphaValue = 0
        orderOut(nil)
        (contentView as? AreaSelectionNSView)?.resetOverlayState()
    }
    
    public func updateSampler(_ sampler: ScreenPixelSampler) {
        (contentView as? AreaSelectionNSView)?.updateSampler(sampler)
    }
    
    public func updateVisibleWindows(_ windows: [SCWindow]) {
        (contentView as? AreaSelectionNSView)?.updateVisibleWindows(windows)
    }
    
    public func updateBackgroundImage(_ image: CGImage) {
        (contentView as? AreaSelectionNSView)?.updateBackgroundImage(image)
    }
    
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    public override func cancelOperation(_ sender: Any?) {
        (contentView as? AreaSelectionNSView)?.cancelOperation(sender)
    }
    
    @discardableResult
    func configured(
        screen: NSScreen,
        mode: OverlayMode,
        onCompleteRect: @escaping (CGRect) -> Void,
        onCompleteWindow: @escaping (SCWindow) -> Void,
        onCancel: @escaping () -> Void,
        onNeedBackgroundSample: (() -> Void)? = nil
    ) -> AreaOverlayWindow {
        configure(
            screen: screen,
            mode: mode,
            visibleWindows: [],
            backgroundImage: nil,
            onCompleteRect: onCompleteRect,
            onCompleteWindow: onCompleteWindow,
            onCancel: onCancel,
            onNeedBackgroundSample: onNeedBackgroundSample
        )
        return self
    }
}

extension NSScreen {
    /// Стабильный ID дисплея для пула оверлеев.
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
