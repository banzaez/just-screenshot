import Foundation
import SwiftUI

/// Поддерживаемые языки интерфейса приложения Just Screenshot
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case russian = "ru"
    case ukrainian = "uk"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"
    
    public var id: String { rawValue }
    
    /// Отображаемое название языка в селекторе (название на самом языке)
    public var localizedName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        case .ukrainian: return "Українська"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .spanish: return "Español"
        case .simplifiedChinese: return "简体中文"
        case .japanese: return "日本語"
        }
    }
    
    /// Флаг-символ или код для компактного бейджа
    public var flagIcon: String {
        switch self {
        case .english: return "🇺🇸"
        case .russian: return "🇷🇺"
        case .ukrainian: return "🇺🇦"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        case .simplifiedChinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        }
    }
    
    /// Автоматическое определение языка из настроек локали/системы macOS
    public static func detectSystemLanguage() -> AppLanguage {
        let preferred = Locale.preferredLanguages
        for lang in preferred {
            let lower = lang.lowercased()
            if lower.starts(with: "uk") { return .ukrainian }
            if lower.starts(with: "ru") { return .russian }
            if lower.starts(with: "zh") { return .simplifiedChinese }
            if lower.starts(with: "ja") { return .japanese }
            if lower.starts(with: "de") { return .german }
            if lower.starts(with: "fr") { return .french }
            if lower.starts(with: "es") { return .spanish }
            if lower.starts(with: "en") { return .english }
        }
        return .english
    }
}

/// Высокопроизводительный типизированный менеджер локализации
@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()
    
    private let languageKey = "settings_appLanguage"
    
    @Published public private(set) var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: languageKey),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            // Первый запуск: автоопределение языка ОС пользователя
            let detected = AppLanguage.detectSystemLanguage()
            self.currentLanguage = detected
            UserDefaults.standard.set(detected.rawValue, forKey: languageKey)
        }
    }
    
    public func setLanguage(_ language: AppLanguage) {
        guard currentLanguage != language else { return }
        currentLanguage = language
    }
}

/// Удобная глобальная функция локализации строк
@MainActor
public func L(_ key: String) -> String {
    LocalizationCatalog.translate(key, for: LocalizationManager.shared.currentLanguage)
}

/// Строго типизированная функция локализации по LocKey
@MainActor
public func L(_ key: LocKey) -> String {
    LocalizationCatalog.translate(key.rawValue, for: LocalizationManager.shared.currentLanguage)
}

/// Глобальная функция с форматированием аргументов
@MainActor
public func L(_ key: String, _ args: CVarArg...) -> String {
    let format = LocalizationCatalog.translate(key, for: LocalizationManager.shared.currentLanguage)
    return String(format: format, arguments: args)
}

/// Строго типизированная функция с форматированием аргументов
@MainActor
public func L(_ key: LocKey, _ args: CVarArg...) -> String {
    let format = LocalizationCatalog.translate(key.rawValue, for: LocalizationManager.shared.currentLanguage)
    return String(format: format, arguments: args)
}
