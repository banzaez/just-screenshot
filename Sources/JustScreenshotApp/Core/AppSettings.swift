import Foundation
import Carbon
import SwiftUI

/// Сервис настроек приложения
@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    // UserDefaults Keys
    private enum Keys {
        static let playSound = "settings_playSound"
        static let copyToClipboardOnCapture = "settings_copyToClipboardOnCapture"
        static let defaultSaveDirectory = "settings_defaultSaveDirectory"
        static let shortcutArea = "settings_shortcut_area"
        static let shortcutAreaAlt = "settings_shortcut_area_alt"
        static let shortcutWindow = "settings_shortcut_window"
        static let shortcutWindowAlt = "settings_shortcut_window_alt"
        static let shortcutRecording = "settings_shortcut_recording"
        static let shortcutRecordingAlt = "settings_shortcut_recording_alt"
        static let shortcutRepeat = "settings_shortcut_repeat"
        static let shortcutRepeatAlt = "settings_shortcut_repeat_alt"
        static let shortcutHistory = "settings_shortcut_history"
        static let shortcutHistoryAlt = "settings_shortcut_history_alt"
        static let showFloatingBar = "settings_show_floating_bar"
        static let showKeystrokes = "settings_show_keystrokes"
        static let showClicks = "settings_show_clicks"
        static let lastCapturedRect = "settings_last_captured_rect"
        static let lastRecordingRect = "settings_last_recording_rect"
        static let recordingCountdown = "settings_recording_countdown"
        static let dimOutsideRecording = "settings_dim_outside_recording"
    }
    
    // Язык интерфейса
    @Published public var language: AppLanguage {
        didSet {
            LocalizationManager.shared.setLanguage(language)
        }
    }
    
    // Настройки захвата
    @Published public var playSound: Bool {
        didSet { UserDefaults.standard.set(playSound, forKey: Keys.playSound) }
    }
    
    @Published public var copyToClipboardOnCapture: Bool {
        didSet { UserDefaults.standard.set(copyToClipboardOnCapture, forKey: Keys.copyToClipboardOnCapture) }
    }
    
    @Published public var defaultSaveDirectoryPath: String {
        didSet { UserDefaults.standard.set(defaultSaveDirectoryPath, forKey: Keys.defaultSaveDirectory) }
    }
    
    @Published public var showFloatingBarDuringRecording: Bool {
        didSet { UserDefaults.standard.set(showFloatingBarDuringRecording, forKey: Keys.showFloatingBar) }
    }
    
    @Published public var showKeystrokesDuringRecording: Bool {
        didSet { UserDefaults.standard.set(showKeystrokesDuringRecording, forKey: Keys.showKeystrokes) }
    }
    
    @Published public var showClicksDuringRecording: Bool {
        didSet { UserDefaults.standard.set(showClicksDuringRecording, forKey: Keys.showClicks) }
    }
    
    // Последняя захваченная область для быстрого повтора (Repeat Last Capture)
    @Published public var lastCapturedRect: CGRect? {
        didSet { AppSettings.saveRect(lastCapturedRect, key: Keys.lastCapturedRect) }
    }
    
    // Последняя выбранная область для записи видео
    @Published public var lastRecordingRect: CGRect? {
        didSet { AppSettings.saveRect(lastRecordingRect, key: Keys.lastRecordingRect) }
    }
    
    // Обратный отсчет перед записью (0 = без отсчета, 3 = 3 сек)
    @Published public var recordingCountdownSeconds: Int {
        didSet { UserDefaults.standard.set(recordingCountdownSeconds, forKey: Keys.recordingCountdown) }
    }
    
    // Затемнять экран вокруг выбранной области записи
    @Published public var dimOutsideRecordingArea: Bool {
        didSet { UserDefaults.standard.set(dimOutsideRecordingArea, forKey: Keys.dimOutsideRecording) }
    }
    
    // Горячие клавиши (Основной вариант + Альтернативный)
    @Published public var shortcutArea: ShortcutKey {
        didSet { saveShortcut(shortcutArea, key: Keys.shortcutArea) }
    }
    @Published public var shortcutAreaAlt: ShortcutKey? {
        didSet { saveOptionalShortcut(shortcutAreaAlt, key: Keys.shortcutAreaAlt) }
    }
    
    @Published public var shortcutWindow: ShortcutKey {
        didSet { saveShortcut(shortcutWindow, key: Keys.shortcutWindow) }
    }
    @Published public var shortcutWindowAlt: ShortcutKey? {
        didSet { saveOptionalShortcut(shortcutWindowAlt, key: Keys.shortcutWindowAlt) }
    }
    
    @Published public var shortcutRecording: ShortcutKey {
        didSet { saveShortcut(shortcutRecording, key: Keys.shortcutRecording) }
    }
    @Published public var shortcutRecordingAlt: ShortcutKey? {
        didSet { saveOptionalShortcut(shortcutRecordingAlt, key: Keys.shortcutRecordingAlt) }
    }
    
    @Published public var shortcutRepeat: ShortcutKey {
        didSet { saveShortcut(shortcutRepeat, key: Keys.shortcutRepeat) }
    }
    @Published public var shortcutRepeatAlt: ShortcutKey? {
        didSet { saveOptionalShortcut(shortcutRepeatAlt, key: Keys.shortcutRepeatAlt) }
    }
    
    @Published public var shortcutHistory: ShortcutKey {
        didSet { saveShortcut(shortcutHistory, key: Keys.shortcutHistory) }
    }
    @Published public var shortcutHistoryAlt: ShortcutKey? {
        didSet { saveOptionalShortcut(shortcutHistoryAlt, key: Keys.shortcutHistoryAlt) }
    }
    
    public struct DefaultShortcuts {
        public static let defaultMod = UInt32(cmdKey | shiftKey)
        public static let repeatMod = UInt32(cmdKey | optionKey)
        
        public static let area = ShortcutKey(keyCode: UInt32(kVK_ANSI_5), keyChar: "5", modifiers: defaultMod)
        public static let window = ShortcutKey(keyCode: UInt32(kVK_ANSI_4), keyChar: "4", modifiers: defaultMod)
        public static let recording = ShortcutKey(keyCode: UInt32(kVK_ANSI_3), keyChar: "3", modifiers: defaultMod)
        public static let repeatCapture = ShortcutKey(keyCode: UInt32(kVK_ANSI_5), keyChar: "5", modifiers: repeatMod)
        public static let history = ShortcutKey(keyCode: UInt32(kVK_ANSI_H), keyChar: "H", modifiers: defaultMod)
    }
    
    private init() {
        let defaults = UserDefaults.standard
        
        self.language = LocalizationManager.shared.currentLanguage
        self.playSound = defaults.object(forKey: Keys.playSound) as? Bool ?? true
        self.copyToClipboardOnCapture = defaults.object(forKey: Keys.copyToClipboardOnCapture) as? Bool ?? true
        
        let defaultMovies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first?.path ?? ""
        self.defaultSaveDirectoryPath = defaults.string(forKey: Keys.defaultSaveDirectory) ?? defaultMovies
        self.showFloatingBarDuringRecording = defaults.object(forKey: Keys.showFloatingBar) as? Bool ?? true
        self.showKeystrokesDuringRecording = defaults.object(forKey: Keys.showKeystrokes) as? Bool ?? true
        self.showClicksDuringRecording = defaults.object(forKey: Keys.showClicks) as? Bool ?? true
        self.lastCapturedRect = AppSettings.loadRect(key: Keys.lastCapturedRect)
        self.lastRecordingRect = AppSettings.loadRect(key: Keys.lastRecordingRect)
        self.recordingCountdownSeconds = defaults.object(forKey: Keys.recordingCountdown) as? Int ?? 0
        self.dimOutsideRecordingArea = defaults.object(forKey: Keys.dimOutsideRecording) as? Bool ?? true
        
        self.shortcutArea = AppSettings.loadShortcut(key: Keys.shortcutArea) ?? DefaultShortcuts.area
        self.shortcutAreaAlt = AppSettings.loadShortcut(key: Keys.shortcutAreaAlt)
        
        self.shortcutWindow = AppSettings.loadShortcut(key: Keys.shortcutWindow) ?? DefaultShortcuts.window
        self.shortcutWindowAlt = AppSettings.loadShortcut(key: Keys.shortcutWindowAlt)
        
        self.shortcutRecording = AppSettings.loadShortcut(key: Keys.shortcutRecording) ?? DefaultShortcuts.recording
        self.shortcutRecordingAlt = AppSettings.loadShortcut(key: Keys.shortcutRecordingAlt)
        
        self.shortcutRepeat = AppSettings.loadShortcut(key: Keys.shortcutRepeat) ?? DefaultShortcuts.repeatCapture
        self.shortcutRepeatAlt = AppSettings.loadShortcut(key: Keys.shortcutRepeatAlt)
        
        self.shortcutHistory = AppSettings.loadShortcut(key: Keys.shortcutHistory) ?? DefaultShortcuts.history
        self.shortcutHistoryAlt = AppSettings.loadShortcut(key: Keys.shortcutHistoryAlt)
    }
    
    private func saveShortcut(_ shortcut: ShortcutKey, key: String) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func saveOptionalShortcut(_ shortcut: ShortcutKey?, key: String) {
        if let shortcut {
            saveShortcut(shortcut, key: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    private static func loadShortcut(key: String) -> ShortcutKey? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(ShortcutKey.self, from: data) else {
            return nil
        }
        return shortcut
    }
    
    private static func saveRect(_ rect: CGRect?, key: String) {
        if let rect {
            let dict: [String: Double] = [
                "x": Double(rect.origin.x),
                "y": Double(rect.origin.y),
                "w": Double(rect.size.width),
                "h": Double(rect.size.height)
            ]
            UserDefaults.standard.set(dict, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    private static func loadRect(key: String) -> CGRect? {
        guard let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Double],
              let x = dict["x"], let y = dict["y"], let w = dict["w"], let h = dict["h"] else {
            return nil
        }
        return CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h))
    }
    
    public func resetHotkeysToDefaults() {
        shortcutArea = DefaultShortcuts.area
        shortcutAreaAlt = nil
        shortcutWindow = DefaultShortcuts.window
        shortcutWindowAlt = nil
        shortcutRecording = DefaultShortcuts.recording
        shortcutRecordingAlt = nil
        shortcutRepeat = DefaultShortcuts.repeatCapture
        shortcutRepeatAlt = nil
        shortcutHistory = DefaultShortcuts.history
        shortcutHistoryAlt = nil
    }
}
