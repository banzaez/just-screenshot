import Foundation
import CoreGraphics

/// Сериализуемая blur-аннотация для сохранения состояния редактирования видео
public struct SavedVideoAnnotation: Codable, Sendable, Equatable {
    public let id: UUID
    public let rect: CGRect
    public let rotationAngle: Double

    public init(id: UUID, rect: CGRect, rotationAngle: Double) {
        self.id = id
        self.rect = rect
        self.rotationAngle = rotationAngle
    }

    public init(from item: VideoAnnotationItem) {
        self.id = item.id
        self.rect = item.rect
        self.rotationAngle = item.rotationAngle
    }

    public func toAnnotationItem() -> VideoAnnotationItem {
        VideoAnnotationItem(
            id: id,
            type: .blur,
            rect: rect,
            rotationAngle: rotationAngle
        )
    }
}

/// Полное состояние редактирования конкретного видеофайла (.edits.json)
public struct VideoEditorState: Codable, Sendable, Equatable {
    public var trimStart: Double
    public var trimEnd: Double
    public var hasUserEditedTrim: Bool
    public var playbackRate: Float
    public var cropRect: CGRect

    public var isSmartZoomEnabled: Bool
    public var smartZoomScale: SmartZoomScale
    public var smartZoomMode: SmartZoomMode
    public var autoZoomOutOnIdle: Bool

    public var blurStyle: VideoBlurStyle
    public var blurIntensity: VideoBlurIntensity
    public var annotations: [SavedVideoAnnotation]

    public var isKeystrokesEnabled: Bool
    public var keystrokeFilter: KeystrokeDisplayFilter
    public var keystrokePosition: KeystrokePosition
    public var keystrokeSize: KeystrokeSize
    public var isTypingHighlightEnabled: Bool

    public var isClickHighlightsEnabled: Bool

    public init(
        trimStart: Double,
        trimEnd: Double,
        hasUserEditedTrim: Bool,
        playbackRate: Float,
        cropRect: CGRect,
        isSmartZoomEnabled: Bool,
        smartZoomScale: SmartZoomScale,
        smartZoomMode: SmartZoomMode,
        autoZoomOutOnIdle: Bool,
        blurStyle: VideoBlurStyle,
        blurIntensity: VideoBlurIntensity,
        annotations: [SavedVideoAnnotation],
        isKeystrokesEnabled: Bool,
        keystrokeFilter: KeystrokeDisplayFilter,
        keystrokePosition: KeystrokePosition,
        keystrokeSize: KeystrokeSize,
        isTypingHighlightEnabled: Bool,
        isClickHighlightsEnabled: Bool
    ) {
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.hasUserEditedTrim = hasUserEditedTrim
        self.playbackRate = playbackRate
        self.cropRect = cropRect
        self.isSmartZoomEnabled = isSmartZoomEnabled
        self.smartZoomScale = smartZoomScale
        self.smartZoomMode = smartZoomMode
        self.autoZoomOutOnIdle = autoZoomOutOnIdle
        self.blurStyle = blurStyle
        self.blurIntensity = blurIntensity
        self.annotations = annotations
        self.isKeystrokesEnabled = isKeystrokesEnabled
        self.keystrokeFilter = keystrokeFilter
        self.keystrokePosition = keystrokePosition
        self.keystrokeSize = keystrokeSize
        self.isTypingHighlightEnabled = isTypingHighlightEnabled
        self.isClickHighlightsEnabled = isClickHighlightsEnabled
    }
}

/// Хранилище сопутствующего состояния редактирования видео (.edits.json)
public enum VideoEditorStateStore {
    public static func companionEditsURL(for videoURL: URL) -> URL {
        videoURL.deletingPathExtension().appendingPathExtension("edits.json")
    }

    public static func save(_ state: VideoEditorState, forVideoURL videoURL: URL) {
        let url = companionEditsURL(for: videoURL)
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: url, options: .atomic)
        } catch {
            AppLogger.recording.error("Failed to save video editor state: \(error.localizedDescription, privacy: .public)")
        }
    }

    public static func load(forVideoURL videoURL: URL) -> VideoEditorState? {
        let url = companionEditsURL(for: videoURL)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VideoEditorState.self, from: data)
        } catch {
            return nil
        }
    }
}
