import Foundation
import CoreGraphics

/// Настройки экспорта видео и анимации
public struct VideoExportOptions: Sendable {
    public var trimStart: Double // секунды
    public var trimEnd: Double   // секунды
    public var playbackRate: Float // 0.5, 1.0, 1.5, 2.0
    public var cropRect: CGRect?  // нормализованные координаты [0...1]
    public var gifFPS: Int
    public var annotations: [VideoAnnotationItem]
    public var smartZoom: Bool
    public var smartZoomScale: SmartZoomScale
    public var smartZoomMode: SmartZoomMode
    public var autoZoomOutOnIdle: Bool
    public var cursorTrack: CursorTrack?
    
    public init(
        trimStart: Double = 0,
        trimEnd: Double = 0,
        playbackRate: Float = 1.0,
        cropRect: CGRect? = nil,
        gifFPS: Int = 15,
        annotations: [VideoAnnotationItem] = [],
        smartZoom: Bool = false,
        smartZoomScale: SmartZoomScale = .balanced,
        smartZoomMode: SmartZoomMode = .onClicks,
        autoZoomOutOnIdle: Bool = true,
        cursorTrack: CursorTrack? = nil
    ) {
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.playbackRate = playbackRate
        self.cropRect = cropRect
        self.gifFPS = gifFPS
        self.annotations = annotations
        self.smartZoom = smartZoom
        self.smartZoomScale = smartZoomScale
        self.smartZoomMode = smartZoomMode
        self.autoZoomOutOnIdle = autoZoomOutOnIdle
        self.cursorTrack = cursorTrack
    }
}

/// Нормализованный диапазон обрезки по длительности ассета
enum VideoExportTrim {
    static func range(duration: Double, options: VideoExportOptions) -> (start: Double, end: Double) {
        guard duration.isFinite, duration > 0 else { return (0, 0) }
        let rawStart = options.trimStart.isFinite ? options.trimStart : 0
        let rawEnd = options.trimEnd.isFinite ? options.trimEnd : 0
        let start = min(max(0, rawStart), duration)
        if rawEnd > start {
            return (start, min(duration, rawEnd))
        }
        return (start, duration)
    }
}
