import Cocoa
import ScreenCaptureKit

/// Представление полноэкранного окна оверлея
public final class AreaOverlayWindow: NSWindow {
    private let onCancel: () -> Void
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

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
        installEscMonitors()
    }

    private func installEscMonitors() {
        let cancel = onCancel
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                DispatchQueue.main.async { cancel() }
                return nil
            }
            return event
        }
        // Фолбэк, если приложение не стало активным и окно не получает клавиши
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                DispatchQueue.main.async { cancel() }
            }
        }
    }

    private func removeEscMonitors() {
        if let m = localKeyMonitor { NSEvent.removeMonitor(m) }
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m) }
        localKeyMonitor = nil
        globalKeyMonitor = nil
    }

    public override func close() {
        removeEscMonitors()
        super.close()
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
