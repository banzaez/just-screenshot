import Testing
import Foundation
import AppKit
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

@Suite("Annotation Editor & History Integration Tests")
struct AnnotationEditorHistoryTests {
    @Test @MainActor func testEditorUnsavedChangesTracking() {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        let item = CapturedItem(image: image, rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        let model = AnnotationEditorModel(capturedItem: item)
        model.finishInitialLoading()
        #expect(!model.hasUnsavedChanges)
        
        // Добавление аннотации переводит редактор в состояние несохранённых изменений
        model.commitItemsMutation { items in
            items.append(AnnotationItem(tool: .arrow, startPoint: .zero, endPoint: CGPoint(x: 50, y: 50)))
        }
        #expect(model.hasUnsavedChanges)
        
        // После markSaved изменения считаются сохранёнными
        model.markSaved()
        #expect(!model.hasUnsavedChanges)
    }
    
    @Test @MainActor func testConfirmCloseSavesUnsavedEditsToHistory() {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        let item = CapturedItem(image: image, rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        let model = AnnotationEditorModel(capturedItem: item)
        model.finishInitialLoading()
        
        let windowManager = AppWindowManager.shared
        let initialHistoryCount = HistoryStore.shared.entries.count
        
        // Если изменений нет — confirmCloseIfNeeded не добавляет дубликат
        let window = NSWindow()
        let closedWithoutChanges = windowManager.confirmCloseIfNeeded(model: model, window: window)
        #expect(closedWithoutChanges)
        #expect(HistoryStore.shared.entries.count == initialHistoryCount)
        
        // Вносим правку
        model.commitItemsMutation { items in
            items.append(AnnotationItem(tool: .rectangle, startPoint: .zero, endPoint: CGPoint(x: 40, y: 40)))
        }
        #expect(model.hasUnsavedChanges)
        
        // Закрытие окна после редактирования автоматически сохраняет результат в историю
        let closedWithChanges = windowManager.confirmCloseIfNeeded(model: model, window: window)
        #expect(closedWithChanges)
        #expect(!model.hasUnsavedChanges)
        #expect(HistoryStore.shared.entries.count == initialHistoryCount + 1)
        
        // Очищаем созданную тестовую запись
        if let newEntry = HistoryStore.shared.entries.first {
            HistoryStore.shared.delete(id: newEntry.id)
        }
    }
    
    @Test @MainActor func testSinglePassBackdropRendering() {
        let size = NSSize(width: 200, height: 150)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        
        let item = AnnotationItem(tool: .arrow, startPoint: CGPoint(x: 10, y: 10), endPoint: CGPoint(x: 50, y: 50))
        let rendered = AnnotationRenderer.render(
            baseImage: image,
            items: [item],
            backdrop: .aurora,
            padding: 30,
            cornerRadius: 12,
            shadowRadius: 16,
            shadow: true
        )
        
        #expect(abs(rendered.size.width - 260) < 0.1)
        #expect(abs(rendered.size.height - 210) < 0.1)
    }
    
    @Test @MainActor func testHistoryStoreDownscaledThumbnailCache() {
        let originalSize = NSSize(width: 1200, height: 800)
        let largeImage = NSImage(size: originalSize)
        largeImage.lockFocus()
        NSColor.blue.setFill()
        NSRect(origin: .zero, size: originalSize).fill()
        largeImage.unlockFocus()
        
        let testID = UUID()
        let entry = HistoryStore.shared.add(largeImage, id: testID)
        #expect(entry != nil)
        
        // Превью сразу доступно синхронно через cachedThumbnail
        let cached = HistoryStore.shared.cachedThumbnail(for: entry!)
        #expect(cached != nil)
        if let cached {
            #expect(cached.size.width <= 560)
            #expect(cached.size.height <= 560)
        }
        
        HistoryStore.shared.delete(id: testID)
    }
    
    @Test @MainActor func testWindowFrameMockupRendering() {
        let size = NSSize(width: 200, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.gray.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        
        let rendered = AnnotationRenderer.render(
            baseImage: image,
            items: [],
            backdrop: nil,
            padding: 0,
            cornerRadius: 10,
            shadowRadius: 0,
            shadow: false,
            showWindowFrame: true
        )
        
        #expect(abs(rendered.size.width - 200) < 0.1)
        #expect(abs(rendered.size.height - 130) < 0.1) // 100 + 30 titlebar
    }
    
    @Test @MainActor func testCropToolAndUndoRestoration() {
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        
        let item = CapturedItem(image: image, rect: CGRect(origin: .zero, size: size))
        let model = AnnotationEditorModel(capturedItem: item)
        model.finishInitialLoading()
        
        let annotation = AnnotationItem(tool: .arrow, startPoint: CGPoint(x: 30, y: 30), endPoint: CGPoint(x: 70, y: 70))
        model.appendItem(annotation)
        
        // Задаем область кропа: с 20% по x и y, ширина 50%, высота 50% (пиксели: x: 20, y: 20, w: 50, h: 50)
        model.cropRect = CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        model.applyCrop()
        
        #expect(abs(model.currentBaseImage.size.width - 50) < 0.1)
        #expect(abs(model.currentBaseImage.size.height - 50) < 0.1)
        #expect(model.items.count == 1)
        #expect(abs(model.items[0].startPoint.x - 10) < 0.1) // 30 - 20
        #expect(abs(model.items[0].startPoint.y - 10) < 0.1)
        
        // Проверяем работу Undo для кропа
        model.undo()
        #expect(abs(model.currentBaseImage.size.width - 100) < 0.1)
        #expect(abs(model.items[0].startPoint.x - 30) < 0.1)
    }
    
    @Test func testQRCodeDetection() async {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return }
        let payload = "https://justscreenshot.app"
        filter.setValue(payload.data(using: .utf8), forKey: "inputMessage")
        guard let output = filter.outputImage else { return }
        
        let rep = NSCIImageRep(ciImage: output)
        let qrImage = NSImage(size: NSSize(width: 120, height: 120))
        qrImage.addRepresentation(rep)
        
        let detected = await TextRecognizer.detectQRCodes(in: qrImage)
        #expect(detected.contains(payload))
    }
    
    @Test @MainActor func testPinnedWindowClickThroughAndUnlock() {
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        let testID = UUID()
        
        let wm = AppWindowManager.shared
        wm.pin(image: image, id: testID)
        
        guard let pinEntry = wm.windowRegistry.pins.first else {
            Issue.record("Pinned window not created")
            return
        }
        let pinID = pinEntry.key
        let window = pinEntry.value.window
        
        wm.setPinClickThrough(id: pinID, isLocked: true)
        #expect(wm.hasLockedPins)
        #expect(window.ignoresMouseEvents == true)
        
        wm.unlockAllPins()
        #expect(!wm.hasLockedPins)
        #expect(window.ignoresMouseEvents == false)
        
        wm.closePin(id: pinID)
    }
    
    @Test func testOCRShortcutDefaults() {
        let ocrShortcut = AppSettings.DefaultShortcuts.ocr
        #expect(ocrShortcut.keyCode == 22) // Key 6
        #expect(ocrShortcut.keyChar == "6")
        #expect(ocrShortcut.modifiers == AppSettings.DefaultShortcuts.repeatMod)
    }
}
