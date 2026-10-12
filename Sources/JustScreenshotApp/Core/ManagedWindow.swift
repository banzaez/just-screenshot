import AppKit

/// Окно + делегат, который сообщает о закрытии (безопасное освобождение ссылок)
@MainActor
final class ManagedWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    private let onClose: (ManagedWindow) -> Void
    
    init(window: NSWindow, onClose: @escaping (ManagedWindow) -> Void) {
        self.window = window
        self.onClose = onClose
        super.init()
        window.isReleasedWhenClosed = false
        window.delegate = self
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose(self)
    }
    
    /// Закрыть окно программно без повторного вызова onClose
    func closeSilently() {
        window.delegate = nil
        window.orderOut(nil)
        window.contentView = nil
        window.close()
    }
    
    func bringToFront() {
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
