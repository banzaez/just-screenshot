import AppKit
import Carbon

/// Универсальный монитор отмены по клавише Escape
@MainActor
final class EscapeMonitor {
    private static var nextHotKeyID: UInt32 = 10_000

    private let hotKeyID: UInt32
    private var localMonitor: Any?
    private var usesGlobalHotKey = false

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

        // Используем GlobalHotKeyManager (CGEventTap с фолбэком на Carbon RegisterEventHotKey),
        // чтобы перехватывать и поглощать Escape глобально, не передавая его в активное стороннее окно.
        if includeGlobal || useHotKeyFallback {
            usesGlobalHotKey = true
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
        if usesGlobalHotKey {
            usesGlobalHotKey = false
            GlobalHotKeyManager.shared.unregister(id: hotKeyID)
        }
    }
}
