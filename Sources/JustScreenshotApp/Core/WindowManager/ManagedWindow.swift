import AppKit

/// Окно + делегат, который сообщает о закрытии (безопасное освобождение ссылок)
@MainActor
final class ManagedWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    private let onClose: (ManagedWindow) -> Void
    var shouldClose: ((ManagedWindow) -> Bool)?
    
    init(window: NSWindow, onClose: @escaping (ManagedWindow) -> Void) {
        self.window = window
        self.onClose = onClose
        super.init()
        window.isReleasedWhenClosed = false
        window.delegate = self
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let check = shouldClose {
            return check(self)
        }
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose(self)
    }
    
    /// Закрыть окно программно; опционально выполнить onClose для освобождения ресурсов модели
    func closeSilently(runOnClose: Bool = false) {
        window.delegate = nil
        window.orderOut(nil)
        window.contentView = nil
        window.close()
        if runOnClose {
            onClose(self)
        }
    }
    
    func bringToFront() {
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
