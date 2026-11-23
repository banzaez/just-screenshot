import Foundation
import Carbon
import Observation

/// Сервис настроек приложения
@Observable
@MainActor
public final class AppSettings {
    public static let shared = AppSettings()

    public enum ShortcutAction: String, CaseIterable, Identifiable, Sendable {
        case area
        case window
        case recording
        case repeatCapture
        case ocr
        case history

        public var id: String { rawValue }

        var primaryKey: String {
            switch self {
            case .area: return Keys.shortcutArea
            case .window: return Keys.shortcutWindow
            case .recording: return Keys.shortcutRecording
            case .repeatCapture: return Keys.shortcutRepeat
            case .ocr: return Keys.shortcutOCR
            case .history: return Keys.shortcutHistory
            }
        }

        var altKey: String {
            primaryKey + "_alt"
        }

        var defaultPrimary: ShortcutKey {
            switch self {
            case .area: return DefaultShortcuts.area
            case .window: return DefaultShortcuts.window
            case .recording: return DefaultShortcuts.recording
            case .repeatCapture: return DefaultShortcuts.repeatCapture
            case .ocr: return DefaultShortcuts.ocr
            case .history: return DefaultShortcuts.history
            }
        }
    }

    private enum Keys {
        static let playSound = "settings_playSound"
        static let copyToClipboardOnCapture = "settings_copyToClipboardOnCapture"
        static let defaultSaveDirectory = "settings_defaultSaveDirectory"
        static let shortcutArea = "settings_shortcut_area"
        static let shortcutWindow = "settings_shortcut_window"
        static let shortcutRecording = "settings_shortcut_recording"
        static let shortcutRepeat = "settings_shortcut_repeat"
        static let shortcutHistory = "settings_shortcut_history"
        static let shortcutOCR = "settings_shortcut_ocr"
        static let showFloatingBar = "settings_show_floating_bar"
        static let lastCapturedRect = "settings_last_captured_rect"
        static let recordingCountdown = "settings_recording_countdown"
        static let dimOutsideRecordingArea = "settings_dim_outside_recording"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Язык интерфейса (единый источник истины — LocalizationManager)
    public var language: AppLanguage {
        get { LocalizationManager.shared.currentLanguage }
        set { LocalizationManager.shared.setLanguage(newValue) }
    }

    // Настройки захвата
    public var playSound: Bool {
        didSet { defaults.set(playSound, forKey: Keys.playSound) }
    }

    public var copyToClipboardOnCapture: Bool {
        didSet { defaults.set(copyToClipboardOnCapture, forKey: Keys.copyToClipboardOnCapture) }
    }

    public var defaultSaveDirectoryPath: String {
        didSet { defaults.set(defaultSaveDirectoryPath, forKey: Keys.defaultSaveDirectory) }
    }

    public var showFloatingBarDuringRecording: Bool {
        didSet { defaults.set(showFloatingBarDuringRecording, forKey: Keys.showFloatingBar) }
    }

    /// Последняя захваченная область для быстрого повтора (Repeat Last Capture)
    public var lastCapturedRect: CGRect? {
        didSet { Self.saveRect(lastCapturedRect, key: Keys.lastCapturedRect, defaults: defaults) }
    }

    /// Обратный отсчет перед записью (0 = без отсчета, 3 = 3 сек)
    public var recordingCountdownSeconds: Int {
        didSet { defaults.set(recordingCountdownSeconds, forKey: Keys.recordingCountdown) }
    }

    /// Затемнять экран вокруг выбранной области записи
    public var dimOutsideRecordingArea: Bool {
        didSet { defaults.set(dimOutsideRecordingArea, forKey: Keys.dimOutsideRecordingArea) }
    }

    // Горячие клавиши (Основной вариант + Альтернативный)
    public var shortcutArea: ShortcutKey {
        didSet { saveShortcut(shortcutArea, key: ShortcutAction.area.primaryKey) }
    }
    public var shortcutAreaAlt: ShortcutKey? {
        didSet { saveOptionalShortcut(shortcutAreaAlt, key: ShortcutAction.area.altKey) }
    }

    public var shortcutWindow: ShortcutKey {
        didSet { saveShortcut(shortcutWindow, key: ShortcutAction.window.primaryKey) }
    }
    public var shortcutWindowAlt: ShortcutKey? {
        didSet { saveOptionalShortcut(shortcutWindowAlt, key: ShortcutAction.window.altKey) }
    }

    public var shortcutRecording: ShortcutKey {
        didSet { saveShortcut(shortcutRecording, key: ShortcutAction.recording.primaryKey) }
    }
    public var shortcutRecordingAlt: ShortcutKey? {
        didSet { saveOptionalShortcut(shortcutRecordingAlt, key: ShortcutAction.recording.altKey) }
    }

    public var shortcutRepeat: ShortcutKey {
        didSet { saveShortcut(shortcutRepeat, key: ShortcutAction.repeatCapture.primaryKey) }
    }
    public var shortcutRepeatAlt: ShortcutKey? {
        didSet { saveOptionalShortcut(shortcutRepeatAlt, key: ShortcutAction.repeatCapture.altKey) }
    }

    public var shortcutHistory: ShortcutKey {
        didSet { saveShortcut(shortcutHistory, key: ShortcutAction.history.primaryKey) }
    }
    public var shortcutHistoryAlt: ShortcutKey? {
        didSet { saveOptionalShortcut(shortcutHistoryAlt, key: ShortcutAction.history.altKey) }
    }

    public var shortcutOCR: ShortcutKey {
        didSet { saveShortcut(shortcutOCR, key: ShortcutAction.ocr.primaryKey) }
    }
    public var shortcutOCRAlt: ShortcutKey? {
        didSet { saveOptionalShortcut(shortcutOCRAlt, key: ShortcutAction.ocr.altKey) }
    }

    public struct DefaultShortcuts {
        public static let defaultMod = UInt32(cmdKey | shiftKey)
        public static let repeatMod = UInt32(cmdKey | optionKey)

        public static let area = ShortcutKey(keyCode: UInt32(kVK_ANSI_5), keyChar: "5", modifiers: defaultMod)
        public static let window = ShortcutKey(keyCode: UInt32(kVK_ANSI_4), keyChar: "4", modifiers: defaultMod)
        public static let recording = ShortcutKey(keyCode: UInt32(kVK_ANSI_3), keyChar: "3", modifiers: defaultMod)
        public static let repeatCapture = ShortcutKey(keyCode: UInt32(kVK_ANSI_5), keyChar: "5", modifiers: repeatMod)
        public static let history = ShortcutKey(keyCode: UInt32(kVK_ANSI_H), keyChar: "H", modifiers: defaultMod)
        public static let ocr = ShortcutKey(keyCode: UInt32(kVK_ANSI_6), keyChar: "6", modifiers: repeatMod)
    }

    internal init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.playSound = defaults.object(forKey: Keys.playSound) as? Bool ?? true
        self.copyToClipboardOnCapture = defaults.object(forKey: Keys.copyToClipboardOnCapture) as? Bool ?? true

        let defaultMovies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first?.path ?? ""
        self.defaultSaveDirectoryPath = defaults.string(forKey: Keys.defaultSaveDirectory) ?? defaultMovies
        self.showFloatingBarDuringRecording = defaults.object(forKey: Keys.showFloatingBar) as? Bool ?? true
        self.lastCapturedRect = Self.loadRect(key: Keys.lastCapturedRect, defaults: defaults)
        self.recordingCountdownSeconds = defaults.object(forKey: Keys.recordingCountdown) as? Int ?? 0
        self.dimOutsideRecordingArea = defaults.object(forKey: Keys.dimOutsideRecordingArea) as? Bool ?? true

        self.shortcutArea = Self.loadShortcut(key: ShortcutAction.area.primaryKey, defaults: defaults) ?? DefaultShortcuts.area
        self.shortcutAreaAlt = Self.loadShortcut(key: ShortcutAction.area.altKey, defaults: defaults)

        self.shortcutWindow = Self.loadShortcut(key: ShortcutAction.window.primaryKey, defaults: defaults) ?? DefaultShortcuts.window
        self.shortcutWindowAlt = Self.loadShortcut(key: ShortcutAction.window.altKey, defaults: defaults)

        self.shortcutRecording = Self.loadShortcut(key: ShortcutAction.recording.primaryKey, defaults: defaults) ?? DefaultShortcuts.recording
        self.shortcutRecordingAlt = Self.loadShortcut(key: ShortcutAction.recording.altKey, defaults: defaults)

        self.shortcutRepeat = Self.loadShortcut(key: ShortcutAction.repeatCapture.primaryKey, defaults: defaults) ?? DefaultShortcuts.repeatCapture
        self.shortcutRepeatAlt = Self.loadShortcut(key: ShortcutAction.repeatCapture.altKey, defaults: defaults)

        self.shortcutHistory = Self.loadShortcut(key: ShortcutAction.history.primaryKey, defaults: defaults) ?? DefaultShortcuts.history
        self.shortcutHistoryAlt = Self.loadShortcut(key: ShortcutAction.history.altKey, defaults: defaults)

        self.shortcutOCR = Self.loadShortcut(key: ShortcutAction.ocr.primaryKey, defaults: defaults) ?? DefaultShortcuts.ocr
        self.shortcutOCRAlt = Self.loadShortcut(key: ShortcutAction.ocr.altKey, defaults: defaults)
    }

    public func shortcutPair(for action: ShortcutAction) -> (primary: ShortcutKey, alternate: ShortcutKey?) {
        switch action {
        case .area: return (shortcutArea, shortcutAreaAlt)
        case .window: return (shortcutWindow, shortcutWindowAlt)
        case .recording: return (shortcutRecording, shortcutRecordingAlt)
        case .repeatCapture: return (shortcutRepeat, shortcutRepeatAlt)
        case .ocr: return (shortcutOCR, shortcutOCRAlt)
        case .history: return (shortcutHistory, shortcutHistoryAlt)
        }
    }

    /// Проверяет, занято ли сочетание другим слотом
    public func hasConflict(_ candidate: ShortcutKey, excludingTargetID: String) -> Bool {
        for action in ShortcutAction.allCases {
            let pair = shortcutPair(for: action)
            if "primary:\(action.rawValue)" != excludingTargetID && pair.primary == candidate {
                return true
            }
            if "alt:\(action.rawValue)" != excludingTargetID, let alt = pair.alternate, alt == candidate {
                return true
            }
        }
        return false
    }

    private static let shortcutEncoder = JSONEncoder()
    private static let shortcutDecoder = JSONDecoder()

    private func saveShortcut(_ shortcut: ShortcutKey, key: String) {
        if let data = try? Self.shortcutEncoder.encode(shortcut) {
            defaults.set(data, forKey: key)
        }
    }

    private func saveOptionalShortcut(_ shortcut: ShortcutKey?, key: String) {
        if let shortcut {
            saveShortcut(shortcut, key: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func loadShortcut(key: String, defaults: UserDefaults) -> ShortcutKey? {
        guard let data = defaults.data(forKey: key),
              let shortcut = try? shortcutDecoder.decode(ShortcutKey.self, from: data) else {
            return nil
        }
        return shortcut
    }

    private static func saveRect(_ rect: CGRect?, key: String, defaults: UserDefaults) {
        if let rect {
            let dict: [String: Double] = [
                "x": Double(rect.origin.x),
                "y": Double(rect.origin.y),
                "w": Double(rect.size.width),
                "h": Double(rect.size.height)
            ]
            defaults.set(dict, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func loadRect(key: String, defaults: UserDefaults) -> CGRect? {
        guard let dict = defaults.dictionary(forKey: key) as? [String: Double],
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
        shortcutOCR = DefaultShortcuts.ocr
        shortcutOCRAlt = nil
    }
}
