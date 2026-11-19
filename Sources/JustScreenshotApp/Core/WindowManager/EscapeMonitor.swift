import AppKit
import Carbon

/// Универсальный монитор отмены по клавише Escape
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

    isolated deinit {
        stop()
    }

    func start(
        includeGlobal: Bool = false,
        useHotKeyFallback: Bool = false,
        shouldHandle: @escaping @MainActor () -> Bool = { true },
        onEscape: @escaping @MainActor () -> Void
    ) {
        stop()

        let escCode = UInt16(kVK_Escape)

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == escCode, shouldHandle() else { return event }
            onEscape()
            return nil
        }

        if includeGlobal {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                guard event.keyCode == escCode else { return }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard shouldHandle() else { return }
                        onEscape()
                    }
                }
            }
        }

        // Регистрируем Carbon-фолбэк только когда неактивен globalMonitor (например, нет Accessibility)
        if useHotKeyFallback && globalMonitor == nil {
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
