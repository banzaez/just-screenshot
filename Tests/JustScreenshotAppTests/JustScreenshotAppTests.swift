import Testing
import Foundation
import CoreGraphics
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
    
    @Test func testCursorTrackCodablePreservesClickIndex() throws {
        let kf1 = CursorKeyframe(timestamp: 0.5, point: CGPoint(x: 0.4, y: 0.6), isClick: true)
        let kf2 = CursorKeyframe(timestamp: 2.0, point: CGPoint(x: 0.8, y: 0.8), isClick: false)
        let original = CursorTrack(keyframes: [kf1, kf2])
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CursorTrack.self, from: data)
        
        let state = decoded.cameraState(at: 0.8, scale: .closeup, mode: .onClicks)
        #expect(state.focus == CGPoint(x: 0.4, y: 0.6))
        #expect(state.zoom >= 1.45)
    }
}

@Suite("Pixel Sampler & Renderer Tests")
struct PixelSamplerAndRendererTests {
    
    @Test func testScreenPixelSamplerReadsExactRGB() {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: 4,
            height: 4,
            bitsPerComponent: 8,
            bytesPerRow: 16,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            Issue.record("Failed to create CGContext")
            return
        }
        ctx.setFillColor(CGColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        
        guard let cgImage = ctx.makeImage() else {
            Issue.record("Failed to make CGImage")
            return
        }
        let sampler = ScreenPixelSampler(image: cgImage)
        let hex = sampler.getPixelHex(at: CGPoint(x: 2, y: 2), viewBounds: CGRect(x: 0, y: 0, width: 4, height: 4))
        #expect(hex == "#FF0000")
    }
    
    @Test func testHistoryEntryBackwardCompatibilityAndVideoSupport() throws {
        // Legacy JSON без полей kind, duration, externalFilePath
        let legacyID = UUID()
        let legacyJSON = """
        {"id":"\(legacyID.uuidString)","date":1000000,"width":1920,"height":1080}
        """.data(using: .utf8)!
        
        let decodedLegacy = try JSONDecoder().decode(HistoryEntry.self, from: legacyJSON)
        #expect(decodedLegacy.id == legacyID)
        #expect(decodedLegacy.kind == .image)
        #expect(decodedLegacy.duration == nil)
        #expect(decodedLegacy.externalFilePath == nil)
        
        // Video entry
        let videoEntry = HistoryEntry(
            width: 1280,
            height: 720,
            kind: .video,
            duration: 14.5,
            externalFilePath: "/tmp/test_recording.mp4"
        )
        let encoded = try JSONEncoder().encode(videoEntry)
        let decodedVideo = try JSONDecoder().decode(HistoryEntry.self, from: encoded)
        #expect(decodedVideo.kind == .video)
        #expect(decodedVideo.duration == 14.5)
        #expect(decodedVideo.externalFilePath == "/tmp/test_recording.mp4")
    }
    
    @Test func testShortcutKeyNamesAndFunctionKeys() {
        // Проверка всех функциональных клавиш F1, F5, F12, F19 (в Carbon kVK_F1 = 122, kVK_F5 = 96, kVK_F12 = 111)
        #expect(ShortcutKey.isFunctionKey(122)) // F1
        #expect(ShortcutKey.isFunctionKey(96))  // F5
        #expect(ShortcutKey.isFunctionKey(111)) // F12
        #expect(ShortcutKey.isFunctionKey(80))  // F19
        
        let f1 = ShortcutKey(keyCode: 122, keyChar: "\u{F704}", modifiers: 0)
        #expect(f1.keySymbols == ["F1"])
        
        let pageUp = ShortcutKey(keyCode: 116, keyChar: "", modifiers: 256) // cmdKey = 256
        #expect(pageUp.keySymbols == ["⌘", "⇞ PgUp"])
        
        let numpadPlus = ShortcutKey(keyCode: 69, keyChar: "+", modifiers: 0)
        #expect(ShortcutKey.canBeUsedWithoutModifiers(69))
        #expect(numpadPlus.keySymbols == ["Num +"])
        
        // Проверка независимости от раскладки (например русская "Й" на физической клавише Q = keyCode 12)
        let qKey = ShortcutKey(keyCode: 12, keyChar: "й", modifiers: 768) // cmdKey | shiftKey
        #expect(qKey.keySymbols == ["⇧", "⌘", "Q"])
    }
}
