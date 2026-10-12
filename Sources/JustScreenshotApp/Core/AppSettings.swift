import Foundation
import Carbon
import SwiftUI

/// Модель шортката клавиш для сохранения в UserDefaults
public struct ShortcutKey: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var keyChar: String
    public var modifiers: UInt32 // Carbon modifiers: cmdKey, shiftKey, etc.
    
    public init(keyCode: UInt32, keyChar: String, modifiers: UInt32 = UInt32(cmdKey | shiftKey)) {
        self.keyCode = keyCode
        self.keyChar = keyChar
        self.modifiers = modifiers
    }
    
    public var keySymbols: [String] {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyChar.uppercased())
        return parts
    }
    
    public var displayString: String {
        keySymbols.joined()
    }
}

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
        static let shortcutWindow = "settings_shortcut_window"
        static let shortcutRecording = "settings_shortcut_recording"
        static let shortcutHistory = "settings_shortcut_history"
        static let videoFps = "settings_video_fps"
        static let showFloatingBar = "settings_show_floating_bar"
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
    
    // Горячие клавиши
    @Published public var shortcutArea: ShortcutKey {
        didSet { saveShortcut(shortcutArea, key: Keys.shortcutArea) }
    }
    
    @Published public var shortcutWindow: ShortcutKey {
        didSet { saveShortcut(shortcutWindow, key: Keys.shortcutWindow) }
    }
    
    @Published public var shortcutRecording: ShortcutKey {
        didSet { saveShortcut(shortcutRecording, key: Keys.shortcutRecording) }
    }
    
    @Published public var shortcutHistory: ShortcutKey {
        didSet { saveShortcut(shortcutHistory, key: Keys.shortcutHistory) }
    }
    
    private init() {
        let defaults = UserDefaults.standard
        
        self.playSound = defaults.object(forKey: Keys.playSound) as? Bool ?? true
        self.copyToClipboardOnCapture = defaults.object(forKey: Keys.copyToClipboardOnCapture) as? Bool ?? true
        
        let defaultMovies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first?.path ?? ""
        self.defaultSaveDirectoryPath = defaults.string(forKey: Keys.defaultSaveDirectory) ?? defaultMovies
        self.showFloatingBarDuringRecording = defaults.object(forKey: Keys.showFloatingBar) as? Bool ?? true
        
        let defaultMod = UInt32(cmdKey | shiftKey)
        self.shortcutArea = AppSettings.loadShortcut(key: Keys.shortcutArea) ?? ShortcutKey(keyCode: UInt32(kVK_ANSI_5), keyChar: "5", modifiers: defaultMod)
        self.shortcutWindow = AppSettings.loadShortcut(key: Keys.shortcutWindow) ?? ShortcutKey(keyCode: UInt32(kVK_ANSI_4), keyChar: "4", modifiers: defaultMod)
        self.shortcutRecording = AppSettings.loadShortcut(key: Keys.shortcutRecording) ?? ShortcutKey(keyCode: UInt32(kVK_ANSI_3), keyChar: "3", modifiers: defaultMod)
        self.shortcutHistory = AppSettings.loadShortcut(key: Keys.shortcutHistory) ?? ShortcutKey(keyCode: UInt32(kVK_ANSI_H), keyChar: "H", modifiers: defaultMod)
    }
    
    private func saveShortcut(_ shortcut: ShortcutKey, key: String) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private static func loadShortcut(key: String) -> ShortcutKey? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(ShortcutKey.self, from: data) else {
            return nil
        }
        return shortcut
    }
    
    public func resetHotkeysToDefaults() {
        let defaultMod = UInt32(cmdKey | shiftKey)
        shortcutArea = ShortcutKey(keyCode: UInt32(kVK_ANSI_5), keyChar: "5", modifiers: defaultMod)
        shortcutWindow = ShortcutKey(keyCode: UInt32(kVK_ANSI_4), keyChar: "4", modifiers: defaultMod)
        shortcutRecording = ShortcutKey(keyCode: UInt32(kVK_ANSI_3), keyChar: "3", modifiers: defaultMod)
        shortcutHistory = ShortcutKey(keyCode: UInt32(kVK_ANSI_H), keyChar: "H", modifiers: defaultMod)
    }
}
