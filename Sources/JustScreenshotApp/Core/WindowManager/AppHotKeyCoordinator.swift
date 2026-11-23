import Foundation

/// Регистрация и управление глобальными сочетаниями клавиш приложения
@MainActor
final class AppHotKeyCoordinator {
    private weak var windowManager: AppWindowManager?

    private struct BindingSpec {
        let primaryID: UInt32
        let altID: UInt32
        let action: AppSettings.ShortcutAction
        let handler: (AppWindowManager) -> Void
    }

    private let specs: [BindingSpec] = [
        BindingSpec(primaryID: 1, altID: 11, action: .recording) { $0.toggleRecording() },
        BindingSpec(primaryID: 2, altID: 12, action: .window) { $0.startWindowCapture() },
        BindingSpec(primaryID: 3, altID: 13, action: .area) { $0.startAreaCapture() },
        BindingSpec(primaryID: 4, altID: 14, action: .history) { $0.showHistory() },
        BindingSpec(primaryID: 5, altID: 15, action: .repeatCapture) { $0.repeatLastCapture() },
        BindingSpec(primaryID: 6, altID: 16, action: .ocr) { $0.startTextCapture() }
    ]

    private var managedIDs: Set<UInt32> {
        var ids = Set<UInt32>()
        for spec in specs {
            ids.insert(spec.primaryID)
            ids.insert(spec.altID)
        }
        return ids
    }

    init(windowManager: AppWindowManager) {
        self.windowManager = windowManager
    }

    func reload() {
        // Снимаем только собственные ID, не трогая временный EscapeMonitor
        GlobalHotKeyManager.shared.unregister(ids: managedIDs)
        setup()
    }

    func setup() {
        guard let wm = windowManager else { return }
        let settings = AppSettings.shared
        let hk = GlobalHotKeyManager.shared

        for spec in specs {
            let pair = settings.shortcutPair(for: spec.action)
            let invoke: () -> Void = { [weak wm] in
                guard let wm else { return }
                spec.handler(wm)
            }
            if let primary = pair.primary {
                hk.register(
                    id: spec.primaryID,
                    keyCode: primary.keyCode,
                    modifiers: primary.modifiers,
                    action: invoke
                )
            }
            if let alt = pair.alternate {
                hk.register(
                    id: spec.altID,
                    keyCode: alt.keyCode,
                    modifiers: alt.modifiers,
                    action: invoke
                )
            }
        }
    }
}
