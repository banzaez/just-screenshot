import Foundation

/// Оптимизированный каталог локализации (Архитектура 2026).
/// Словари строк вынесены по отдельным языковым файлам.
/// Поиск перевода происходит за O(1) в плоской таблице активного языка.
public enum LocalizationCatalog {
    
    /// Быстрый доступ к строке по ключу и языку за один поиск O(1)
    public static func translate(_ key: String, for language: AppLanguage) -> String {
        let dict: [String: String]
        switch language {
        case .english: dict = englishStrings
        case .russian: dict = russianStrings
        case .ukrainian: dict = ukrainianStrings
        case .german: dict = germanStrings
        case .french: dict = frenchStrings
        case .spanish: dict = spanishStrings
        case .simplifiedChinese: dict = simplifiedChineseStrings
        case .japanese: dict = japaneseStrings
        }
        
        if let translation = dict[key] {
            return translation
        }
        
        // Фоллбэк на английский язык, если для выбранного языка ключ отсутствует
        if language != .english, let englishFallback = englishStrings[key] {
            return englishFallback
        }
        
        return key
    }
}
