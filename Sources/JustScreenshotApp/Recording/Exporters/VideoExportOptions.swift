import Foundation
import CoreGraphics

/// Настройки экспорта видео и анимации
public struct VideoExportOptions: Sendable {
    public var trimStart: Double // секунды
    public var trimEnd: Double   // секунды
    public var playbackRate: Float // 0.5, 1.0, 1.5, 2.0
    public var cropRect: CGRect?  // нормализованные координаты [0...1]
    public var exportGIF: Bool
    public var gifFPS: Int
    public var annotations: [VideoAnnotationItem]
    
    public init(
        trimStart: Double = 0,
        trimEnd: Double = 0,
        playbackRate: Float = 1.0,
        cropRect: CGRect? = nil,
        exportGIF: Bool = false,
        gifFPS: Int = 15,
        annotations: [VideoAnnotationItem] = []
    ) {
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.playbackRate = playbackRate
        self.cropRect = cropRect
        self.exportGIF = exportGIF
        self.gifFPS = gifFPS
        self.annotations = annotations
    }
}
