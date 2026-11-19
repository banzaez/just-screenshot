import Foundation

/// Каталог локализации: плоские словари по языкам с O(1) поиском и фолбэком на английский
public enum LocalizationCatalog {

    /// Сырой перевод без фолбэка на английский (для строгих тестов паритета ключей)
    public static func rawTranslation(_ key: String, for language: AppLanguage) -> String? {
        strings(for: language)[key]
    }

    /// Быстрый доступ к строке по ключу и языку с фолбэком на английский
    public static func translate(_ key: String, for language: AppLanguage) -> String {
        if let translation = strings(for: language)[key] {
            return translation
        }
        if language != .english, let englishFallback = englishStrings[key] {
            return englishFallback
        }
        return key
    }

    private static func strings(for language: AppLanguage) -> [String: String] {
        switch language {
        case .english: return englishStrings
        case .russian: return russianStrings
        case .ukrainian: return ukrainianStrings
        case .german: return germanStrings
        case .french: return frenchStrings
        case .spanish: return spanishStrings
        case .simplifiedChinese: return simplifiedChineseStrings
        case .japanese: return japaneseStrings
        }
    }
}
