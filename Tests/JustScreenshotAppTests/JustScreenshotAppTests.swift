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

@Suite("Smart Zoom & Cursor Tracking Tests")
struct SmartZoomTests {
    
    @Test func testEmptyCursorTrackDefaultState() {
        let track = CursorTrack()
        let state = track.cameraState(at: 1.0, mode: .continuous)
        #expect(state.focus == CGPoint(x: 0.5, y: 0.5))
        #expect(state.zoom >= 1.20)
    }
    
    @Test func testCursorTrackInterpolation() {
        let kf1 = CursorKeyframe(timestamp: 0.0, point: CGPoint(x: 0.2, y: 0.2))
        let kf2 = CursorKeyframe(timestamp: 2.0, point: CGPoint(x: 0.8, y: 0.8))
        let track = CursorTrack(keyframes: [kf1, kf2])
        
        let midState = track.cameraState(at: 1.0, mode: .continuous)
        // В середине smoothstep выдает точно 0.5
        #expect(abs(midState.focus.x - 0.5) < 0.05)
        #expect(abs(midState.focus.y - 0.5) < 0.05)
        #expect(midState.zoom >= 1.20)
    }
    
    @Test func testCursorTrackClickZoomPriority() {
        let kf1 = CursorKeyframe(timestamp: 1.0, point: CGPoint(x: 0.3, y: 0.3), isClick: true)
        let track = CursorTrack(keyframes: [kf1])
        
        let clickState = track.cameraState(at: 1.5, scale: .closeup, mode: .onClicks)
        #expect(clickState.focus == CGPoint(x: 0.3, y: 0.3))
        #expect(clickState.zoom >= 1.45)
    }
    
    @Test func testCursorTrackClickModeOverviewWhenNoClick() {
        let kf1 = CursorKeyframe(timestamp: 1.0, point: CGPoint(x: 0.3, y: 0.3), isClick: true)
        let track = CursorTrack(keyframes: [kf1])
        
        // В момент t=5.0 клик уже далеко позади — в режиме onClicks должен быть общий план 1.0x
        let state = track.cameraState(at: 5.0, mode: .onClicks)
        #expect(state.zoom == 1.0)
    }
}
