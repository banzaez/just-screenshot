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
        let start = max(0, options.trimStart)
        let end = options.trimEnd > start ? min(duration, options.trimEnd) : duration
        return (start, end)
    }
}
