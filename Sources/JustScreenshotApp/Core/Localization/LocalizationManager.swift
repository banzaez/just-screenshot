import Foundation
import SwiftUI
import Observation

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

    public var locale: Locale {
        Locale(identifier: rawValue)
    }

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

    /// Флаг-символ для компактного бейджа
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

    /// Точное определение языка ОС по первому ISO 639-1 субтегу (без ложных совпадений вроде `est` → `es`)
    public static func detectSystemLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        for lang in preferredLanguages {
            let primary = lang
                .lowercased()
                .split(whereSeparator: { $0 == "-" || $0 == "_" })
                .first
                .map(String.init) ?? ""
            switch primary {
            case "uk": return .ukrainian
            case "ru": return .russian
            case "zh": return .simplifiedChinese
            case "ja": return .japanese
            case "de": return .german
            case "fr": return .french
            case "es": return .spanish
            case "en": return .english
            default: continue
            }
        }
        return .english
    }
}

/// Высокопроизводительный типизированный менеджер локализации
@Observable
@MainActor
public final class LocalizationManager {
    public static let shared = LocalizationManager()

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let languageKey = "settings_appLanguage"

    public private(set) var currentLanguage: AppLanguage {
        didSet {
            defaults.set(currentLanguage.rawValue, forKey: languageKey)
        }
    }

    internal init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.string(forKey: languageKey),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            let detected = AppLanguage.detectSystemLanguage()
            self.currentLanguage = detected
            defaults.set(detected.rawValue, forKey: languageKey)
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

/// Глобальная функция с форматированием аргументов с учётом активной локали
@MainActor
public func L(_ key: String, _ args: CVarArg...) -> String {
    let lang = LocalizationManager.shared.currentLanguage
    let format = LocalizationCatalog.translate(key, for: lang)
    return String(format: format, locale: lang.locale, arguments: args)
}
