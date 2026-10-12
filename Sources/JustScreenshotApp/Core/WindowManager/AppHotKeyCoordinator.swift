import Foundation

/// Регистрация и управление глобальными сочетаниями клавиш приложения
@MainActor
final class AppHotKeyCoordinator {
    private weak var windowManager: AppWindowManager?
    
    init(windowManager: AppWindowManager) {
        self.windowManager = windowManager
    }
    
    func reload() {
        GlobalHotKeyManager.shared.unregisterAll()
        setup()
    }
    
    func setup() {
        guard let wm = windowManager else { return }
        let settings = AppSettings.shared
        let hk = GlobalHotKeyManager.shared
        
        // 1. Запись экрана (Основной и Альтернативный)
        hk.register(id: 1, keyCode: settings.shortcutRecording.keyCode, modifiers: settings.shortcutRecording.modifiers) { [weak wm] in
            wm?.toggleRecording()
        }
        if let alt = settings.shortcutRecordingAlt {
            hk.register(id: 11, keyCode: alt.keyCode, modifiers: alt.modifiers) { [weak wm] in
                wm?.toggleRecording()
            }
        }
        
        // 2. Снимок окна
        hk.register(id: 2, keyCode: settings.shortcutWindow.keyCode, modifiers: settings.shortcutWindow.modifiers) { [weak wm] in
            wm?.startWindowCapture()
        }
        if let alt = settings.shortcutWindowAlt {
            hk.register(id: 12, keyCode: alt.keyCode, modifiers: alt.modifiers) { [weak wm] in
                wm?.startWindowCapture()
            }
        }
        
        // 3. Снимок области
        hk.register(id: 3, keyCode: settings.shortcutArea.keyCode, modifiers: settings.shortcutArea.modifiers) { [weak wm] in
            wm?.startAreaCapture()
        }
        if let alt = settings.shortcutAreaAlt {
            hk.register(id: 13, keyCode: alt.keyCode, modifiers: alt.modifiers) { [weak wm] in
                wm?.startAreaCapture()
            }
        }
        
        // 4. История снимков
        hk.register(id: 4, keyCode: settings.shortcutHistory.keyCode, modifiers: settings.shortcutHistory.modifiers) { [weak wm] in
            wm?.showHistory()
        }
        if let alt = settings.shortcutHistoryAlt {
            hk.register(id: 14, keyCode: alt.keyCode, modifiers: alt.modifiers) { [weak wm] in
                wm?.showHistory()
            }
        }
        
        // 5. Повтор предыдущего захвата (Repeat Last Capture)
        hk.register(id: 5, keyCode: settings.shortcutRepeat.keyCode, modifiers: settings.shortcutRepeat.modifiers) { [weak wm] in
            wm?.repeatLastCapture()
        }
        if let alt = settings.shortcutRepeatAlt {
            hk.register(id: 15, keyCode: alt.keyCode, modifiers: alt.modifiers) { [weak wm] in
                wm?.repeatLastCapture()
            }
        }
    }
}
