import Testing
import Foundation
import SwiftUI
import AppKit
import AVFoundation
import Carbon
import CoreGraphics
import CoreImage
import CoreVideo
import ImageIO
@testable import JustScreenshotApp

// MARK: - Helpers

private func makeSolidNSImage(size: NSSize, color: NSColor, scale: CGFloat = 1.0) -> NSImage {
    let pixelW = max(1, Int((size.width * scale).rounded()))
    let pixelH = max(1, Int((size.height * scale).rounded()))
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil,
        width: pixelW,
        height: pixelH,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setFillColor(color.usingColorSpace(.sRGB)?.cgColor ?? color.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: pixelW, height: pixelH))
    let cg = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: cg)
    rep.size = size
    let img = NSImage(size: size)
    img.addRepresentation(rep)
    return img
}

private func makeTextNSImage(text: String, pointSize: NSSize, scale: CGFloat) -> NSImage {
    let pixelW = max(1, Int((pointSize.width * scale).rounded()))
    let pixelH = max(1, Int((pointSize.height * scale).rounded()))
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil,
        width: pixelW,
        height: pixelH,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: scale, y: scale)
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    NSColor.white.setFill()
    NSRect(origin: .zero, size: pointSize).fill()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
        .foregroundColor: NSColor.black
    ]
    (text as NSString).draw(at: NSPoint(x: 20, y: pointSize.height * 0.38), withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()

    let cg = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: cg)
    rep.size = pointSize
    let img = NSImage(size: pointSize)
    img.addRepresentation(rep)
    return img
}

/// Создает синтетический MP4-файл с левой красной и правой синей половинами для проверки crop/blur/smartZoom
private func writeSyntheticMP4(
    to url: URL,
    width: Int = 160,
    height: Int = 120,
    fps: Int = 15,
    durationSeconds: Double = 1.0
) async throws {
    if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
    }

    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    input.expectsMediaDataInRealTime = false

    let attrs: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: attrs
    )

    writer.add(input)
    guard writer.startWriting() else {
        throw writer.error ?? VideoExportError.exportFailed("Synthetic writer startWriting failed")
    }
    writer.startSession(atSourceTime: .zero)

    let totalFrames = max(2, Int((durationSeconds * Double(fps)).rounded()))
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    for frameIdx in 0..<totalFrames {
        while !input.isReadyForMoreMediaData {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        var pixelBufferOut: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBufferOut
        )
        guard status == kCVReturnSuccess, let pb = pixelBufferOut else {
            throw VideoExportError.exportFailed("Failed to allocate pixel buffer")
        }

        CVPixelBufferLockBaseAddress(pb, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(pb),
           let ctx = CGContext(
               data: baseAddress,
               width: width,
               height: height,
               bitsPerComponent: 8,
               bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
               space: colorSpace,
               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
           ) {
            // Левая половина — чисто красная, правая — чисто синяя
            ctx.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
            ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        }
        CVPixelBufferUnlockBaseAddress(pb, [])

        let pts = CMTime(value: CMTimeValue(frameIdx), timescale: CMTimeScale(fps))
        adaptor.append(pb, withPresentationTime: pts)
    }

    input.markAsFinished()
    nonisolated(unsafe) let finishingWriter = writer
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        finishingWriter.finishWriting {
            if finishingWriter.status == .completed {
                cont.resume()
            } else {
                cont.resume(throwing: finishingWriter.error ?? VideoExportError.exportFailed("Synthetic writer finish failed"))
            }
        }
    }
}

private func extractFormatSpecifiers(from template: String) -> [String] {
    let regex = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?(?:l|ll)?(?:\\.[0-9]+)?[@dDuUxXfFgGs]")
    let ns = template as NSString
    return regex.matches(in: template, range: NSRange(location: 0, length: ns.length)).map {
        ns.substring(with: $0.range)
    }
}

// MARK: - Localization Tests

@Suite("Localization Tests", .serialized)
struct LocalizationTests {

    @Test func testLanguageDetectionExactPrimarySubtag() {
        #expect(AppLanguage.detectSystemLanguage(preferredLanguages: ["est-EE"]) == .english)
        #expect(AppLanguage.detectSystemLanguage(preferredLanguages: ["uk-UA"]) == .ukrainian)
        #expect(AppLanguage.detectSystemLanguage(preferredLanguages: ["ru_RU"]) == .russian)
        #expect(AppLanguage.detectSystemLanguage(preferredLanguages: ["zh-Hans-CN"]) == .simplifiedChinese)
        #expect(AppLanguage.detectSystemLanguage(preferredLanguages: ["ja-JP"]) == .japanese)
        #expect(AppLanguage.detectSystemLanguage(preferredLanguages: ["de-AT"]) == .german)
        #expect(AppLanguage.detectSystemLanguage(preferredLanguages: ["fr-CA"]) == .french)
        #expect(AppLanguage.detectSystemLanguage(preferredLanguages: ["es-419"]) == .spanish)
        #expect(AppLanguage.detectSystemLanguage(preferredLanguages: ["fi-FI", "de-DE"]) == .german)
    }

    @Test func testAllLanguagesHaveNamesAndFlags() {
        for lang in AppLanguage.allCases {
            #expect(!lang.localizedName.isEmpty)
            #expect(!lang.flagIcon.isEmpty)
        }
    }

    @Test func testAllLanguagesCompleteRawKeyAndFormatParity() {
        let englishKeys = LocalizationCatalog.englishStrings.keys.sorted()
        #expect(!englishKeys.isEmpty)

        for key in englishKeys {
            let enValue = LocalizationCatalog.rawTranslation(key, for: .english)!
            let enSpecifiers = extractFormatSpecifiers(from: enValue)

            for lang in AppLanguage.allCases {
                let raw = LocalizationCatalog.rawTranslation(key, for: lang)
                #expect(raw != nil, "Missing raw translation key '\(key)' for language \(lang.rawValue)")
                if let raw {
                    #expect(!raw.isEmpty, "Empty translation for key '\(key)' in \(lang.rawValue)")
                    let langSpecifiers = extractFormatSpecifiers(from: raw)
                    #expect(
                        langSpecifiers == enSpecifiers,
                        "Format specifier mismatch for '\(key)' in \(lang.rawValue): \(langSpecifiers) vs \(enSpecifiers)"
                    )
                }
            }
        }
    }

    @Test @MainActor func testLocalizationManagerSwitching() {
        let manager = LocalizationManager.shared
        let previous = manager.currentLanguage
        defer { manager.setLanguage(previous) }

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
    }
}

// MARK: - Smart Zoom Tests

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

    @Test func testCursorTrackSustainedIdleNoFalseTriggerOnRevisit() {
        let track = CursorTrack(keyframes: [
            CursorKeyframe(timestamp: 0.0, point: CGPoint(x: 0.2, y: 0.2)),
            CursorKeyframe(timestamp: 1.2, point: CGPoint(x: 0.8, y: 0.8)),
            CursorKeyframe(timestamp: 2.1, point: CGPoint(x: 0.2, y: 0.2)),
            CursorKeyframe(timestamp: 4.8, point: CGPoint(x: 0.2, y: 0.2))
        ])

        // В t=2.2 курсор вернулся в прежнюю точку 0.2,0.2, но перед этим двигался в t=1.2 — простоя >= 2с еще нет
        let revisitState = track.cameraState(at: 2.2, scale: .balanced, mode: .continuous, autoZoomOutOnIdle: true)
        #expect(revisitState.zoom >= 1.20)

        // После длительного непрерывного удержания (t=4.8, > 2.4с покоя) камера плавно отъехала до 1.0x
        let idleState = track.cameraState(at: 4.8, scale: .balanced, mode: .continuous, autoZoomOutOnIdle: true)
        #expect(abs(idleState.zoom - 1.0) < 0.001)
    }

    @Test func testCursorTrackSmoothClickTransitions() {
        let track = CursorTrack(keyframes: [
            CursorKeyframe(timestamp: 1.0, point: CGPoint(x: 0.1, y: 0.9), isClick: true)
        ])

        let atStart = track.cameraState(at: 1.0, scale: .closeup, mode: .onClicks)
        #expect(atStart.focus == CGPoint(x: 0.5, y: 0.5))
        #expect(atStart.zoom == 1.0)

        let midRampIn = track.cameraState(at: 1.125, scale: .closeup, mode: .onClicks)
        #expect(midRampIn.zoom > 1.05 && midRampIn.zoom < 1.45)
        #expect(midRampIn.focus.x < 0.49 && midRampIn.focus.x > 0.11)

        let atHold = track.cameraState(at: 1.6, scale: .closeup, mode: .onClicks)
        #expect(atHold.focus == CGPoint(x: 0.1, y: 0.9))
        #expect(abs(atHold.zoom - 1.5) < 0.001)

        let midRampOut = track.cameraState(at: 2.4, scale: .closeup, mode: .onClicks)
        #expect(midRampOut.zoom > 1.05 && midRampOut.zoom < 1.45)
    }

    @Test func testCursorTrackRapidConsecutiveClicksNoSnapBack() {
        let track = CursorTrack(keyframes: [
            CursorKeyframe(timestamp: 1.0, point: CGPoint(x: 0.2, y: 0.2), isClick: true),
            CursorKeyframe(timestamp: 1.8, point: CGPoint(x: 0.8, y: 0.8), isClick: true)
        ])

        // В момент второго клика (t = 1.8, прошло 0.8с после первого) камера уже на первом клике, не сбрасывается в 1.0x
        let atSecondClick = track.cameraState(at: 1.8, scale: .closeup, mode: .onClicks)
        #expect(abs(atSecondClick.zoom - 1.5) < 0.001)
        #expect(abs(atSecondClick.focus.x - 0.2) < 0.001)

        // В середине перехода между первым и вторым кликом (t = 1.925) зум остаётся 1.5x, а фокус плавно идёт от 0.2 к 0.8
        let midTransition = track.cameraState(at: 1.925, scale: .closeup, mode: .onClicks)
        #expect(abs(midTransition.zoom - 1.5) < 0.001)
        #expect(abs(midTransition.focus.x - 0.5) < 0.01)
    }

    @Test func testKeystrokeTrackActiveTimingAndFade() {
        let track = KeystrokeTrack(events: [
            KeystrokeEvent(timestamp: 1.0, text: "⌘ C"),
            KeystrokeEvent(timestamp: 3.0, text: "⌘ V")
        ])

        #expect(track.activeKeystroke(at: 0.5) == nil)

        let active = track.activeKeystroke(at: 1.5)
        #expect(active?.text == "⌘ C")
        #expect(active?.alpha == 1.0)

        let fading = track.activeKeystroke(at: 2.2)
        #expect(fading?.text == "⌘ C")
        #expect((fading?.alpha ?? 0) > 0.1 && (fading?.alpha ?? 1) < 0.9)

        #expect(track.activeKeystroke(at: 2.5) == nil)
        #expect(track.activeKeystroke(at: 3.1)?.text == "⌘ V")
    }

    @Test func testKeystrokeFilterAndSmartZoomAvoidance() {
        let track = KeystrokeTrack(events: [
            KeystrokeEvent(timestamp: 1.0, text: "⌘ C"),
            KeystrokeEvent(timestamp: 1.3, text: "A")
        ])

        // В режиме .all на t = 1.4 активна последняя клавиша "A"
        #expect(track.activeKeystroke(at: 1.4, filter: .all)?.text == "A")
        // В режиме .shortcutsOnly одиночная клавиша "A" игнорируется, остается "⌘ C"
        #expect(track.activeKeystroke(at: 1.4, filter: .shortcutsOnly)?.text == "⌘ C")

        // Когда Smart Zoom сфокусирован прямо на области плашки у края, она переносится на противоположный край
        #expect(KeystrokePosition.bottomCenter.resolved(cameraFocus: CGPoint(x: 0.5, y: 0.88), cameraZoom: 1.35) == .topCenter)
        #expect(KeystrokePosition.topCenter.resolved(cameraFocus: CGPoint(x: 0.5, y: 0.12), cameraZoom: 1.35) == .bottomCenter)
        // Если фокус сбоку, угловая/боковая плашка не смещается
        #expect(KeystrokePosition.bottomLeft.resolved(cameraFocus: CGPoint(x: 0.8, y: 0.88), cameraZoom: 1.35) == .bottomLeft)
        // Без активного зума позиция сохраняется
        #expect(KeystrokePosition.bottomLeft.resolved(cameraFocus: CGPoint(x: 0.2, y: 0.9), cameraZoom: 1.0) == .bottomLeft)
    }

    @Test func testCursorTrackActiveClickRipples() {
        let track = CursorTrack(keyframes: [
            CursorKeyframe(timestamp: 1.0, point: CGPoint(x: 0.2, y: 0.3), isClick: true, isRightClick: false),
            CursorKeyframe(timestamp: 1.2, point: CGPoint(x: 0.8, y: 0.7), isClick: true, isRightClick: true)
        ])

        #expect(track.activeClickRipples(at: 0.9).isEmpty)

        let both = track.activeClickRipples(at: 1.3)
        #expect(both.count == 2)
        let hasLeft = both.contains(where: { !$0.isRightClick && abs($0.point.x - 0.2) < 0.001 })
        let hasRight = both.contains(where: { $0.isRightClick && abs($0.point.x - 0.8) < 0.001 })
        #expect(hasLeft)
        #expect(hasRight)

        let onlySecond = track.activeClickRipples(at: 1.55)
        #expect(onlySecond.count == 1)
        #expect(onlySecond[0].isRightClick)

        #expect(track.activeClickRipples(at: 2.0).isEmpty)
    }

    @Test func testKeystrokeTypingEffectsAtCursor() {
        let cursorTrack = CursorTrack(keyframes: [
            CursorKeyframe(timestamp: 1.0, point: CGPoint(x: 0.3, y: 0.4), isClick: false),
            CursorKeyframe(timestamp: 2.0, point: CGPoint(x: 0.6, y: 0.4), isClick: false)
        ])
        let keyTrack = KeystrokeTrack(events: [
            KeystrokeEvent(timestamp: 1.0, text: "A"),
            KeystrokeEvent(timestamp: 1.2, text: "⌘ C")
        ])

        // Шорткат "⌘ C" не вызывает эффект ввода текста, только обычный символ "A"
        let effects = keyTrack.activeTypingEffects(at: 1.25, cursorTrack: cursorTrack)
        #expect(effects.count == 1)
        #expect(abs(effects[0].point.x - 0.3) < 0.001)
        #expect(effects[0].progress > 0.5 && effects[0].progress < 0.6)
        #expect(keyTrack.activeTypingEffects(at: 2.0, cursorTrack: cursorTrack).isEmpty)
    }

    @Test func testVideoEditorStatePersistenceRoundTrip() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("VideoEdits-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let videoURL = tempDir.appendingPathComponent("clip.mp4")
        let anno = SavedVideoAnnotation(
            id: UUID(),
            rect: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.25),
            rotationAngle: 12
        )
        let state = VideoEditorState(
            trimStart: 1.2,
            trimEnd: 4.5,
            hasUserEditedTrim: true,
            playbackRate: 1.5,
            cropRect: CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9),
            isSmartZoomEnabled: true,
            smartZoomScale: .closeup,
            smartZoomMode: .continuous,
            autoZoomOutOnIdle: false,
            blurStyle: .darkGlass,
            blurIntensity: .heavy,
            annotations: [anno],
            isKeystrokesEnabled: true,
            keystrokeFilter: .shortcutsOnly,
            keystrokePosition: .bottomRight,
            keystrokeSize: .large,
            isTypingHighlightEnabled: true,
            isClickHighlightsEnabled: true
        )

        VideoEditorStateStore.save(state, forVideoURL: videoURL)
        let loaded = try #require(VideoEditorStateStore.load(forVideoURL: videoURL))
        #expect(loaded == state)
    }
}

// MARK: - Capture Geometry, Sampler, Shortcuts & Formatting Tests

@Suite("Capture Geometry, Sampler & Shortcuts Tests")
struct CaptureAndGeometryTests {

    @Test func testScreenPixelSamplerReadsExactRGB() throws {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let ctx = try #require(CGContext(
            data: nil,
            width: 4,
            height: 4,
            bitsPerComponent: 8,
            bytesPerRow: 16,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ))
        ctx.setFillColor(CGColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))

        let cgImage = try #require(ctx.makeImage())
        let sampler = ScreenPixelSampler(image: cgImage)
        let bounds = CGRect(x: 0, y: 0, width: 4, height: 4)
        let hex = sampler.getPixelHex(at: CGPoint(x: 2, y: 2), viewBounds: bounds)
        #expect(hex == "#FF0000")

        let sample = try #require(sampler.getPixelSample(at: CGPoint(x: 2, y: 2), viewBounds: bounds))
        #expect(sample.hex == "#FF0000")
        #expect(sample.r == 255 && sample.g == 0 && sample.b == 0)
        #expect(sample.cgColor.components?.prefix(3) == [1.0, 0.0, 0.0])

        let loupe = try #require(sampler.makeLoupeImage(at: CGPoint(x: 2, y: 2), viewBounds: bounds, gridRadius: 7))
        #expect(loupe.width == 15)
        #expect(loupe.height == 15)
        let loupeSampler = ScreenPixelSampler(image: loupe)
        #expect(loupeSampler.getPixelHex(at: CGPoint(x: 7.5, y: 7.5), viewBounds: CGRect(x: 0, y: 0, width: 15, height: 15)) == "#FF0000")
        #expect(loupeSampler.getPixelHex(at: CGPoint(x: 0.5, y: 0.5), viewBounds: CGRect(x: 0, y: 0, width: 15, height: 15)) == "#181818")
    }

    @Test func testScreenPixelSampler24BitStrideAndEdgeClamping() throws {
        // 2x2 24-bit RGB со stride padding (6 байт пикселей + 2 байта выравнивания = 8 байт/строка)
        let bytesPerRow = 8
        let height = 2
        let bytes: [UInt8] = [
            0x12, 0x34, 0x56, 0xAA, 0xBB, 0xCC, 0x00, 0x00,
            0x10, 0x20, 0x30, 0xDE, 0xAD, 0xBE, 0x00, 0x00
        ]
        let cfData = CFDataCreate(nil, bytes, bytes.count)!
        let provider = try #require(CGDataProvider(data: cfData))
        let cgImage = try #require(CGImage(
            width: 2,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))

        let sampler = ScreenPixelSampler(image: cgImage)
        // Top-down screenPoint coords (как передает AreaSelectionNSView): y=0 — верхняя строка (row 0)
        let topLeft = sampler.getPixelHex(at: CGPoint(x: 0.1, y: 0.1), viewBounds: CGRect(x: 0, y: 0, width: 10, height: 10))
        // Граница viewBounds (10, 10) должна безопасно клампиться на последний пиксель (1, 1), не выходя за буфер
        let bottomRightEdge = sampler.getPixelHex(at: CGPoint(x: 10.0, y: 10.0), viewBounds: CGRect(x: 0, y: 0, width: 10, height: 10))
        let outOfBounds = sampler.getPixelHex(at: CGPoint(x: 15.0, y: -5.0), viewBounds: CGRect(x: 0, y: 0, width: 10, height: 10))
        #expect(topLeft == "#123456")
        #expect(bottomRightEdge == "#DEADBE")
        #expect(outOfBounds == nil)
    }

    @Test @MainActor func testScreenCoordinateSpaceRoundTrip() {
        let primaryHeight: CGFloat = 1080
        let quartz = CGRect(x: 120, y: 80, width: 400, height: 300)
        let appKit = ScreenCoordinateSpace.appKitRect(fromQuartz: quartz, primaryHeight: primaryHeight)
        #expect(appKit == CGRect(x: 120, y: 700, width: 400, height: 300))

        let backToQuartz = ScreenCoordinateSpace.quartzRect(fromAppKit: appKit, primaryHeight: primaryHeight)
        #expect(backToQuartz == quartz)
    }

    @Test func testShortcutKeyNamesEqualityProtectedAndSwiftUIMapping() {
        #expect(ShortcutKey.isFunctionKey(122))
        #expect(ShortcutKey.isFunctionKey(96))
        #expect(ShortcutKey.isFunctionKey(111))
        #expect(ShortcutKey.isFunctionKey(80))

        let f1 = ShortcutKey(keyCode: 122, keyChar: "\u{F704}", modifiers: 0)
        #expect(f1.keySymbols == ["F1"])
        #expect(f1.swiftUIKeyboardShortcut == nil)

        let pageUp = ShortcutKey(keyCode: 116, keyChar: "", modifiers: 256)
        #expect(pageUp.keySymbols == ["⌘", "⇞ PgUp"])

        let numpadPlus = ShortcutKey(keyCode: 69, keyChar: "+", modifiers: 0)
        #expect(ShortcutKey.canBeUsedWithoutModifiers(69))
        #expect(numpadPlus.keySymbols == ["Num +"])

        // Сравнение игнорирует раскладку (keyChar) и отсекает лишние флаги модификаторов (alphaLock и т.п.)
        let qRussian = ShortcutKey(keyCode: 12, keyChar: "й", modifiers: UInt32(cmdKey | shiftKey) | UInt32(alphaLock))
        let qEnglish = ShortcutKey(keyCode: 12, keyChar: "Q", modifiers: UInt32(cmdKey | shiftKey))
        #expect(qRussian == qEnglish)
        #expect(qRussian.keySymbols == ["⇧", "⌘", "Q"])
        #expect(qRussian.swiftUIKeyboardShortcut?.key == "q")

        // Системные шорткаты защищены
        #expect(ShortcutKey.isProtectedSystemShortcut(keyCode: UInt32(kVK_ANSI_Q), modifiers: UInt32(cmdKey)))
        #expect(!ShortcutKey.isProtectedSystemShortcut(keyCode: UInt32(kVK_ANSI_4), modifiers: UInt32(cmdKey | shiftKey)))
    }

    @Test @MainActor func testAppSettingsConflictDetectionIsolated() {
        let suiteName = "com.justscreenshot.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        #expect(settings.shortcutHistory == nil)

        // Дефолтный window = Cmd+Shift+4
        let conflictWithWindow = settings.shortcutWindow
        #expect(settings.hasConflict(conflictWithWindow, excludingTargetID: "primary:area"))
        #expect(!settings.hasConflict(conflictWithWindow, excludingTargetID: "primary:window"))

        settings.shortcutAreaAlt = ShortcutKey(keyCode: UInt32(kVK_ANSI_9), keyChar: "9", modifiers: UInt32(cmdKey | optionKey))
        let dupAlt = ShortcutKey(keyCode: UInt32(kVK_ANSI_9), keyChar: "9", modifiers: UInt32(cmdKey | optionKey))
        #expect(settings.hasConflict(dupAlt, excludingTargetID: "primary:history"))
        #expect(!settings.hasConflict(dupAlt, excludingTargetID: "alt:area"))

        settings.shortcutHistory = ShortcutKey(keyCode: UInt32(kVK_ANSI_H), keyChar: "H", modifiers: UInt32(cmdKey | optionKey))
        #expect(settings.shortcutHistory != nil)
        settings.resetHotkeysToDefaults()
        #expect(settings.shortcutHistory == nil)
    }

    @Test @MainActor func testZoomLabelAndPaletteColorsMatch() {
        #expect(AnnotationFormatting.zoomLabel(1.5) == "1.5×")
        #expect(AnnotationFormatting.zoomLabel(2.0) == "2×")
        #expect(AnnotationFormatting.zoomLabel(2.5) == "2.5×")
        #expect(AnnotationFormatting.zoomLabel(3.0) == "3×")

        let srgbRed = Color(.sRGB, red: 1.0, green: 0.23, blue: 0.19, opacity: 1.0)
        #expect(EditorPalette.colorsMatch(.red, .red))
        #expect(!EditorPalette.colorsMatch(srgbRed, .blue))
    }
}

// MARK: - Isolated HistoryStore Tests

@Suite("Isolated HistoryStore Tests")
struct IsolatedHistoryStoreTests {

    @Test func testHistoryEntryBackwardCompatibilityAndVideoSupport() throws {
        let legacyID = UUID()
        let legacyJSON = """
        {"id":"\(legacyID.uuidString)","date":1000000,"width":1920,"height":1080}
        """.data(using: .utf8)!

        let decodedLegacy = try JSONDecoder().decode(HistoryEntry.self, from: legacyJSON)
        #expect(decodedLegacy.id == legacyID)
        #expect(decodedLegacy.kind == .image)
        #expect(decodedLegacy.duration == nil)
        #expect(decodedLegacy.externalFilePath == nil)

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

    @Test @MainActor func testHistoryStorePendingWriteAndThumbnailsIsolated() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("HistoryTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = HistoryStore(directory: tempDir, observeTermination: false)
        let largeImage = makeSolidNSImage(size: NSSize(width: 1200, height: 800), color: .blue)
        let testID = UUID()

        let entry = try #require(store.add(largeImage, id: testID))
        let cached = try #require(store.cachedThumbnail(for: entry))
        #expect(cached.size.width <= 560)
        #expect(cached.size.height <= 560)

        await store.waitForPendingWrite(id: testID)
        let savedURL = try #require(store.existingFileURL(for: entry))
        #expect(FileManager.default.fileExists(atPath: savedURL.path))
    }

    @Test @MainActor func testHistoryStoreClearPreservesExternalVideos() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("HistoryVideoClear-\(UUID().uuidString)", isDirectory: true)
        let externalVideoDir = FileManager.default.temporaryDirectory.appendingPathComponent("ExternalVideo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: externalVideoDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
            try? FileManager.default.removeItem(at: externalVideoDir)
        }

        let videoURL = externalVideoDir.appendingPathComponent("recording.mp4")
        let trackURL = CursorTrackRecorder.companionTrackURL(for: videoURL)
        try Data([0x00, 0x01, 0x02]).write(to: videoURL)
        try Data("{}".utf8).write(to: trackURL)

        let store = HistoryStore(directory: tempDir, observeTermination: false)
        _ = store.addVideo(url: videoURL, width: 1280, height: 720, duration: 5.0)
        #expect(store.entries.count == 1)

        // Очистка всей истории должна удалить индекс записи, но НЕ удалять пользовательский MP4 с диска
        store.clear()
        #expect(store.entries.isEmpty)
        #expect(FileManager.default.fileExists(atPath: videoURL.path))
        #expect(FileManager.default.fileExists(atPath: trackURL.path))
    }
}

// MARK: - Annotation Editor & Vision Tests

@Suite("Annotation Editor & Vision Tests", .serialized)
struct AnnotationEditorAndVisionTests {

    @Test @MainActor func testEditorUnsavedChangesTracking() {
        let image = makeSolidNSImage(size: NSSize(width: 100, height: 100), color: .white)
        let item = CapturedItem(image: image, rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        let model = AnnotationEditorModel(capturedItem: item)
        model.finishInitialLoading()
        #expect(!model.hasUnsavedChanges)

        model.commitItemsMutation { items in
            items.append(AnnotationItem(tool: .arrow, startPoint: .zero, endPoint: CGPoint(x: 50, y: 50)))
        }
        #expect(model.hasUnsavedChanges)

        model.markSaved()
        #expect(!model.hasUnsavedChanges)
    }

    @Test @MainActor func testConfirmCloseSavesUnsavedEditsToHistory() {
        let image = makeSolidNSImage(size: NSSize(width: 100, height: 100), color: .white)
        let item = CapturedItem(image: image, rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        let model = AnnotationEditorModel(capturedItem: item)
        model.finishInitialLoading()

        let windowManager = AppWindowManager.shared
        let beforeIDs = Set(HistoryStore.shared.entries.map(\.id))
        defer {
            let afterIDs = HistoryStore.shared.entries.map(\.id)
            for id in afterIDs where !beforeIDs.contains(id) {
                HistoryStore.shared.delete(id: id)
            }
        }

        let window = NSWindow()
        let closedWithoutChanges = windowManager.confirmCloseIfNeeded(model: model, window: window)
        #expect(closedWithoutChanges)
        #expect(Set(HistoryStore.shared.entries.map(\.id)) == beforeIDs)

        model.commitItemsMutation { items in
            items.append(AnnotationItem(tool: .rectangle, startPoint: .zero, endPoint: CGPoint(x: 40, y: 40)))
        }
        #expect(model.hasUnsavedChanges)

        let closedWithChanges = windowManager.confirmCloseIfNeeded(model: model, window: window)
        #expect(closedWithChanges)
        #expect(!model.hasUnsavedChanges)
        #expect(HistoryStore.shared.entries.count == beforeIDs.count + 1)
    }

    @Test @MainActor func testSinglePassBackdropRendering() {
        let size = NSSize(width: 200, height: 150)
        let image = makeSolidNSImage(size: size, color: .red, scale: 2.0)

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

    @Test @MainActor func testWindowFrameMockupRendering() {
        let size = NSSize(width: 200, height: 100)
        let image = makeSolidNSImage(size: size, color: .gray)

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
        #expect(abs(rendered.size.height - 130) < 0.1)
    }

    @Test @MainActor func testCropToolAndUnifiedChronologicalUndo() {
        let size = NSSize(width: 100, height: 100)
        let image = makeSolidNSImage(size: size, color: .white, scale: 2.0)

        let item = CapturedItem(image: image, rect: CGRect(origin: .zero, size: size))
        let model = AnnotationEditorModel(capturedItem: item)
        model.finishInitialLoading()

        // 1. Добавляем счетчик №1
        model.appendItem(AnnotationItem(tool: .counter, startPoint: CGPoint(x: 35, y: 35), endPoint: CGPoint(x: 35, y: 35), counterNumber: model.nextCounterNumber))
        #expect(model.nextCounterNumber == 2)

        // 2. Кропаем 20%...70% (новый размер 50x50, координаты сместились на -20)
        model.cropRect = CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        model.applyCrop()
        #expect(abs(model.currentBaseImage.size.width - 50) < 0.5)
        #expect(abs(model.currentBaseImage.size.height - 50) < 0.5)
        #expect(abs(model.items[0].startPoint.x - 15) < 0.5)

        // 3. Добавляем изогнутую стрелку и дублируем (должен сохраниться curveOffset)
        let curved = AnnotationItem(tool: .curvedArrow, startPoint: CGPoint(x: 5, y: 5), endPoint: CGPoint(x: 40, y: 40), curveOffset: 36)
        model.appendItem(curved)
        model.duplicateSelected()
        #expect(model.items.count == 3)
        #expect(model.items[2].curveOffset == 36)

        // 4. Хронологический Undo должен сначала отменить дубликат и стрелку, затем кроп, затем счетчик
        model.undo()
        #expect(model.items.count == 2)
        model.undo()
        #expect(model.items.count == 1)
        model.undo()
        #expect(abs(model.currentBaseImage.size.width - 100) < 0.5)
        #expect(abs(model.items[0].startPoint.x - 35) < 0.5)
        model.undo()
        #expect(model.items.isEmpty)
        #expect(model.nextCounterNumber == 1)
    }

    @Test func testHollowShapeOutlineHitTesting() {
        let hollowRect = AnnotationItem(
            tool: .rectangle,
            startPoint: CGPoint(x: 100, y: 100),
            endPoint: CGPoint(x: 300, y: 300),
            lineWidth: 4
        )
        // На границе попадает
        #expect(hollowRect.contains(point: CGPoint(x: 100, y: 200), tolerance: 6))
        // В центре пустого прямоугольника — НЕ перехватывает клик
        #expect(!hollowRect.contains(point: CGPoint(x: 200, y: 200), tolerance: 6))

        let hollowEllipse = AnnotationItem(
            tool: .ellipse,
            startPoint: CGPoint(x: 100, y: 100),
            endPoint: CGPoint(x: 300, y: 300),
            lineWidth: 4
        )
        #expect(hollowEllipse.contains(point: CGPoint(x: 200, y: 100), tolerance: 6))
        #expect(!hollowEllipse.contains(point: CGPoint(x: 200, y: 200), tolerance: 6))
    }

    @Test @MainActor func testQRCodeDetection() async throws {
        let filter = try #require(CIFilter(name: "CIQRCodeGenerator"))
        let payload = "https://justscreenshot.app"
        filter.setValue(payload.data(using: .utf8), forKey: "inputMessage")
        let output = try #require(filter.outputImage)

        let rep = NSCIImageRep(ciImage: output)
        let qrImage = NSImage(size: NSSize(width: 120, height: 120))
        qrImage.addRepresentation(rep)

        let detected = await TextRecognizer.detectQRCodes(in: qrImage)
        #expect(detected.contains(payload))
    }

    @Test @MainActor func testTextRecognizerRetinaPointCoordinates() async {
        let pointSize = NSSize(width: 420, height: 110)
        let retinaImage = makeTextNSImage(text: "Contact: alice@example.com", pointSize: pointSize, scale: 2.0)

        let regions = await TextRecognizer.findSensitiveRegions(in: retinaImage)
        #expect(!regions.isEmpty)
        for rect in regions {
            #expect(rect.minX >= 0 && rect.maxX <= pointSize.width + 0.5)
            #expect(rect.minY >= 0 && rect.maxY <= pointSize.height + 0.5)
        }
    }

    @Test @MainActor func testPinnedWindowClickThroughAndUnlock() throws {
        let size = NSSize(width: 100, height: 100)
        let image = makeSolidNSImage(size: size, color: .white)
        let testID = UUID()

        let wm = AppWindowManager.shared
        wm.pin(image: image, id: testID)

        let pinEntry = try #require(wm.windowRegistry.pins.first)
        let pinID = pinEntry.key
        let window = pinEntry.value.managed.window
        defer { wm.closePin(id: pinID) }

        wm.setPinClickThrough(id: pinID, isLocked: true)
        #expect(wm.hasLockedPins)
        #expect(pinEntry.value.state.isClickThrough)
        #expect(window.ignoresMouseEvents == true)

        wm.unlockAllPins()
        #expect(!wm.hasLockedPins)
        #expect(!pinEntry.value.state.isClickThrough)
        #expect(window.ignoresMouseEvents == false)
    }

    @Test func testOCRShortcutDefaults() {
        let ocrShortcut = AppSettings.DefaultShortcuts.ocr
        #expect(ocrShortcut.keyCode == 22)
        #expect(ocrShortcut.keyChar == "6")
        #expect(ocrShortcut.modifiers == AppSettings.DefaultShortcuts.repeatMod)
    }
}

// MARK: - Keystroke Formatter Tests

@Suite("Keystroke Formatter Tests", .serialized)
struct KeystrokeFormatterTests {
    private func makeKeyEvent(
        type: NSEvent.EventType = .keyDown,
        keyCode: Int,
        characters: String = "",
        charactersIgnoringModifiers: String? = nil,
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: type,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers ?? characters,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        )
    }

    @Test @MainActor func testUsesActiveKeyboardLayoutCharacters() throws {
        let russianA = try #require(makeKeyEvent(keyCode: kVK_ANSI_A, characters: "ф"))
        #expect(KeystrokeFormatter.format(event: russianA) == "Ф")

        let russianSemicolon = try #require(makeKeyEvent(keyCode: kVK_ANSI_Semicolon, characters: "ж"))
        #expect(KeystrokeFormatter.format(event: russianSemicolon) == "Ж")

        let russianCmdC = try #require(makeKeyEvent(keyCode: kVK_ANSI_C, characters: "с", modifiers: [.command]))
        #expect(KeystrokeFormatter.format(event: russianCmdC) == "⌘ С")

        let russianCtrlC = try #require(makeKeyEvent(
            keyCode: kVK_ANSI_C,
            characters: "\u{03}",
            charactersIgnoringModifiers: "с",
            modifiers: [.control]
        ))
        #expect(KeystrokeFormatter.format(event: russianCtrlC) == "⌃ С")

        let shiftExclamation = try #require(makeKeyEvent(
            keyCode: kVK_ANSI_1,
            characters: "!",
            charactersIgnoringModifiers: "1",
            modifiers: [.shift]
        ))
        #expect(KeystrokeFormatter.format(event: shiftExclamation) == "⇧ !")
    }

    @Test @MainActor func testPreservesSpecialAndLocalizedKeys() throws {
        let manager = LocalizationManager.shared
        let previousLanguage = manager.currentLanguage
        defer { manager.setLanguage(previousLanguage) }

        manager.setLanguage(.russian)
        let space = try #require(makeKeyEvent(keyCode: kVK_Space, characters: " "))
        #expect(KeystrokeFormatter.format(event: space) == L("keystroke.space"))

        let f5 = try #require(makeKeyEvent(keyCode: kVK_F5, characters: "\u{F708}"))
        #expect(KeystrokeFormatter.format(event: f5) == "F5")

        let delete = try #require(makeKeyEvent(keyCode: kVK_Delete, characters: "\u{7F}"))
        #expect(KeystrokeFormatter.format(event: delete) == "⌫ Delete")
    }

    @Test @MainActor func testModifierReleaseDoesNotOverwriteChord() throws {
        // Сброс активных модификаторов перед проверкой
        let releaseAll = try #require(makeKeyEvent(type: .flagsChanged, keyCode: kVK_Command, modifiers: []))
        _ = KeystrokeFormatter.format(event: releaseAll)

        let pressCmd = try #require(makeKeyEvent(type: .flagsChanged, keyCode: kVK_Command, modifiers: [.command]))
        #expect(KeystrokeFormatter.format(event: pressCmd) == "⌘")

        let pressCmdShift = try #require(makeKeyEvent(type: .flagsChanged, keyCode: kVK_Shift, modifiers: [.command, .shift]))
        #expect(KeystrokeFormatter.format(event: pressCmdShift) == "⇧ ⌘")

        let pressS = try #require(makeKeyEvent(keyCode: kVK_ANSI_S, characters: "s", modifiers: [.command, .shift]))
        #expect(KeystrokeFormatter.format(event: pressS) == "⇧ ⌘ S")

        // Отпускание Shift при удержании Cmd не должно сбрасывать показанный бейдж
        let releaseShift = try #require(makeKeyEvent(type: .flagsChanged, keyCode: kVK_Shift, modifiers: [.command]))
        #expect(KeystrokeFormatter.format(event: releaseShift) == nil)
    }
}

// MARK: - End-to-End Video & Animated Export Tests

@Suite("End-to-End Video & Animated Export Tests")
struct VideoAndAnimatedExportTests {

    @Test @MainActor func testMP4ExportWithCropBlurAndSmartZoom() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("VideoExportE2E-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceURL = tempDir.appendingPathComponent("src.mp4")
        let destURL = tempDir.appendingPathComponent("out.mp4")
        try await writeSyntheticMP4(to: sourceURL, width: 160, height: 120, fps: 15, durationSeconds: 1.0)

        let blurAnno = VideoAnnotationItem(
            type: .blur,
            rect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        )
        let options = VideoExportOptions(
            trimStart: 0.0,
            trimEnd: 1.0,
            playbackRate: 1.0,
            cropRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            gifFPS: 15,
            annotations: [blurAnno],
            smartZoom: true,
            smartZoomScale: .subtle
        )

        try await VideoExportService.shared.exportVideo(
            sourceURL: sourceURL,
            destinationURL: destURL,
            options: options,
            progressHandler: { _ in }
        )

        let outAsset = AVURLAsset(url: destURL)
        let outTrack = try #require(try await outAsset.loadTracks(withMediaType: .video).first)
        let outNaturalSize = try await outTrack.load(.naturalSize)
        #expect(Int(outNaturalSize.width.rounded()) == 80)
        #expect(Int(outNaturalSize.height.rounded()) == 60)

        // Проверяем реальное CoreImage размытие на границе красного и синего полукадров
        let generator = AVAssetImageGenerator(asset: outAsset)
        generator.appliesPreferredTrackTransform = true
        let frameCG = try await generator.image(at: .zero).image
        let sampler = ScreenPixelSampler(image: frameCG)
        let centerHex = sampler.getPixelHex(
            at: CGPoint(x: Double(frameCG.width) / 2.0, y: Double(frameCG.height) / 2.0),
            viewBounds: CGRect(x: 0, y: 0, width: frameCG.width, height: frameCG.height)
        )
        // В середине границы после GaussianBlur красный и синий смешались — пиксель не может оставаться чистым #FF0000 или #0000FF
        #expect(centerHex != "#FF0000" && centerHex != "#0000FF")
    }

    @Test func testMP4ExportShortClipAndInPlaceOverwrite() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("VideoShortOverwrite-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let clipURL = tempDir.appendingPathComponent("short.mp4")
        try await writeSyntheticMP4(to: clipURL, width: 160, height: 120, fps: 15, durationSeconds: 0.35)

        let options = VideoExportOptions(
            playbackRate: 1.0,
            cropRect: CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5),
            smartZoom: true
        )

        // Запись поверх самого sourceURL не должна повреждать читаемый файл
        try await VideoExportService.shared.exportVideo(
            sourceURL: clipURL,
            destinationURL: clipURL,
            options: options,
            progressHandler: { _ in }
        )

        let outAsset = AVURLAsset(url: clipURL)
        let outTrack = try #require(try await outAsset.loadTracks(withMediaType: .video).first)
        let size = try await outTrack.load(.naturalSize)
        #expect(Int(size.width.rounded()) == 80)
        #expect(Int(size.height.rounded()) == 60)
    }

    @Test func testGIFAndWebPExportEndToEnd() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AnimatedExportE2E-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceURL = tempDir.appendingPathComponent("src.mp4")
        let gifURL = tempDir.appendingPathComponent("out.gif")
        let webpURL = tempDir.appendingPathComponent("out.webp")
        try await writeSyntheticMP4(to: sourceURL, width: 160, height: 120, fps: 15, durationSeconds: 0.8)

        let options = VideoExportOptions(
            trimStart: 0.0,
            trimEnd: 0.8,
            playbackRate: 1.5,
            cropRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            gifFPS: 10
        )

        try await VideoExportService.shared.exportGIF(
            sourceURL: sourceURL,
            destinationURL: gifURL,
            options: options,
            progressHandler: { _ in }
        )

        let gifSource = try #require(CGImageSourceCreateWithURL(gifURL as CFURL, nil))
        let frameCount = CGImageSourceGetCount(gifSource)
        #expect(frameCount >= 2)
        let firstGifFrame = try #require(CGImageSourceCreateImageAtIndex(gifSource, 0, nil))
        #expect(firstGifFrame.width == 80)
        #expect(firstGifFrame.height == 60)

        try await VideoExportService.shared.exportWebP(
            sourceURL: sourceURL,
            destinationURL: webpURL,
            options: options,
            progressHandler: { _ in }
        )

        let webpData = try Data(contentsOf: webpURL)
        #expect(webpData.count > 20)
        #expect(String(data: webpData.prefix(4), encoding: .ascii) == "RIFF")
        #expect(String(data: webpData.subdata(in: 8..<12), encoding: .ascii) == "WEBP")
    }
}
