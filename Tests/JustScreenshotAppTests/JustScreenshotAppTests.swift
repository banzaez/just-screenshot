import Testing
import Foundation
@testable import JustScreenshotApp

@Suite("Localization Tests")
struct LocalizationTests {
    
    @Test func testLanguageDetectionDefaults() async throws {
        let detected = AppLanguage.detectSystemLanguage()
        #expect(AppLanguage.allCases.contains(detected))
    }
    
    @Test func testAllLanguagesHaveNamesAndFlags() async throws {
        for lang in AppLanguage.allCases {
            #expect(!lang.localizedName.isEmpty)
            #expect(!lang.flagIcon.isEmpty)
        }
    }
    
    @Test func testKeyTranslationsAcrossAllLanguages() async throws {
        let sampleKeys = [
            "menu.record_screen",
            "menu.capture_window",
            "menu.capture_area",
            "settings.title",
            "settings.tab.general",
            "settings.tab.hotkeys",
            "settings.tab.recording",
            "editor.close",
            "editor.copy",
            "editor.save",
            "history.title",
            "video_editor.save_mp4"
        ]
        
        for key in sampleKeys {
            for lang in AppLanguage.allCases {
                let translation = LocalizationCatalog.translate(key, for: lang)
                #expect(translation != key, "Key \(key) should be translated for language \(lang.rawValue)")
                #expect(!translation.isEmpty)
            }
        }
    }
    
    @Test @MainActor func testLocalizationManagerSwitching() async throws {
        let manager = LocalizationManager.shared
        manager.setLanguage(.english)
        #expect(manager.currentLanguage == .english)
        #expect(L("editor.close") == "Close")
        
        manager.setLanguage(.russian)
        #expect(manager.currentLanguage == .russian)
        #expect(L("editor.close") == "Закрыть")
        
        manager.setLanguage(.ukrainian)
        #expect(manager.currentLanguage == .ukrainian)
        #expect(L("editor.close") == "Закрити")
        
        manager.setLanguage(.german)
        #expect(manager.currentLanguage == .german)
        #expect(L("editor.close") == "Schließen")
        
        manager.setLanguage(.french)
        #expect(manager.currentLanguage == .french)
        #expect(L("editor.close") == "Fermer")
        
        manager.setLanguage(.spanish)
        #expect(manager.currentLanguage == .spanish)
        #expect(L("editor.close") == "Cerrar")
        
        manager.setLanguage(.simplifiedChinese)
        #expect(manager.currentLanguage == .simplifiedChinese)
        #expect(L("editor.close") == "关闭")
        
        manager.setLanguage(.japanese)
        #expect(manager.currentLanguage == .japanese)
        #expect(L("editor.close") == "閉じる")
        #expect(L(.editorClose) == "閉じる")
    }
}
