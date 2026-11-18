import AppKit
import Carbon

/// Универсальный монитор отмены по клавише Escape:
/// локальный монитор + опционально глобальный монитор и временный системный хоткей (работает без Accessibility).
@MainActor
final class EscapeMonitor {
    private static var nextHotKeyID: UInt32 = 10_000

    private let hotKeyID: UInt32
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var usesHotKeyFallback = false

    init() {
        Self.nextHotKeyID &+= 1
        self.hotKeyID = Self.nextHotKeyID
    }

    func start(
        includeGlobal: Bool = false,
        useHotKeyFallback: Bool = false,
        shouldHandle: @escaping @MainActor () -> Bool = { true },
        onEscape: @escaping @MainActor () -> Void
    ) {
        stop()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 53, shouldHandle() else { return event }
            onEscape()
            return nil
        }

        if includeGlobal {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                guard event.keyCode == 53 else { return }
                DispatchQueue.main.async {
                    guard shouldHandle() else { return }
                    onEscape()
                }
            }
        }

        if useHotKeyFallback {
            usesHotKeyFallback = true
            GlobalHotKeyManager.shared.register(
                id: hotKeyID,
                keyCode: UInt32(kVK_Escape),
                modifiers: 0
            ) {
                guard shouldHandle() else { return }
                onEscape()
            }
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if usesHotKeyFallback {
            usesHotKeyFallback = false
            GlobalHotKeyManager.shared.unregister(id: hotKeyID)
        }
    }
}
