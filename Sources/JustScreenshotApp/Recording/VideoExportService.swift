import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Сервис экспорта видео: обрезка (trimming), изменение скорости, кадрирование (crop), экспорт в MP4 и анимированный GIF
public final class VideoExportService: @unchecked Sendable {
    public static let shared = VideoExportService()
    
    private init() {}
    
    public struct ExportOptions: Sendable {
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
    
    /// Экспорт в MP4 с обрезкой, масштабированием скорости и кадрированием
    public func exportVideo(
        sourceURL: URL,
        destinationURL: URL,
        options: ExportOptions,
        progressHandler: @Sendable @escaping (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration).seconds
        let startTime = max(0, options.trimStart)
        let endTime = options.trimEnd > startTime ? min(duration, options.trimEnd) : duration
        
        let composition = AVMutableComposition()
        
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Видеотрек не найден"])
        }
        
        let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        
        let trimTimeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: endTime - startTime, preferredTimescale: 600)
        )
        
        try compVideoTrack.insertTimeRange(trimTimeRange, of: videoTrack, at: .zero)
        
        // Регулировка скорости (playbackRate)
        if options.playbackRate != 1.0 && options.playbackRate > 0 {
            let scaledDuration = CMTime(seconds: (endTime - startTime) / Double(options.playbackRate), preferredTimescale: 600)
            compVideoTrack.scaleTimeRange(CMTimeRange(start: .zero, duration: trimTimeRange.duration), toDuration: scaledDuration)
        }
        
        // Настройка видеокомпозиции для кадрирования (Crop)
        let naturalSize = try await videoTrack.load(.naturalSize)
        var videoComposition: AVMutableVideoComposition?
        
        if let crop = options.cropRect, crop.width > 0, crop.height > 0 {
            let targetWidth = naturalSize.width * crop.width
            let targetHeight = naturalSize.height * crop.height
            
            let vComp = AVMutableVideoComposition()
            vComp.renderSize = CGSize(width: floor(targetWidth / 2) * 2, height: floor(targetHeight / 2) * 2)
            vComp.frameDuration = CMTime(value: 1, timescale: 30)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
            let tx = -(crop.origin.x * naturalSize.width)
            let ty = -(crop.origin.y * naturalSize.height)
            let transform = CGAffineTransform(translationX: tx, y: ty)
            layerInstruction.setTransform(transform, at: .zero)
            
            instruction.layerInstructions = [layerInstruction]
            vComp.instructions = [instruction]
            videoComposition = vComp
        }
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "VideoExport", code: -2, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать AVAssetExportSession"])
        }
        
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        
        // Мониторинг прогресса через фоновую задачу
        let tracker = ExportProgressTracker(exportSession: exportSession, progressHandler: progressHandler)
        tracker.start()
        
        await exportSession.export()
        tracker.stop()
        progressHandler(1.0)
        
        if let error = exportSession.error {
            throw error
        }
    }
    
    /// Экспорт выбранного диапазона в анимированный GIF
    public func exportGIF(
        sourceURL: URL,
        destinationURL: URL,
        options: ExportOptions,
        progressHandler: @Sendable @escaping (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration).seconds
        let startTime = max(0, options.trimStart)
        let endTime = options.trimEnd > startTime ? min(duration, options.trimEnd) : duration
        let totalDuration = endTime - startTime
        guard totalDuration > 0 else { return }
        
        let fps = max(5, min(30, options.gifFPS))
        let frameCount = Int(totalDuration * Double(fps))
        guard frameCount > 0 else { return }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: CMTimeScale(fps * 2))
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: CMTimeScale(fps * 2))
        
        // Кадрирование/размер
        generator.maximumSize = CGSize(width: 800, height: 800)
        
        var times: [NSValue] = []
        for i in 0..<frameCount {
            let timeSec = startTime + (Double(i) / Double(fps))
            let cmTime = CMTime(seconds: timeSec, preferredTimescale: 600)
            times.append(NSValue(time: cmTime))
        }
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
            throw NSError(domain: "GIFExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать GIF Destination"])
        }
        
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
        
        let frameDuration = 1.0 / Double(fps * (options.playbackRate > 0 ? Int(options.playbackRate) : 1))
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDuration
            ]
        ]
        
        var processed = 0
        for val in times {
            let time = val.timeValue
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                var finalCGImage = cgImage
                // Если есть Crop
                if let crop = options.cropRect, crop.width > 0, crop.height > 0 {
                    let w = CGFloat(cgImage.width)
                    let h = CGFloat(cgImage.height)
                    let cropPixelRect = CGRect(
                        x: crop.origin.x * w,
                        y: crop.origin.y * h,
                        width: crop.width * w,
                        height: crop.height * h
                    )
                    if let cropped = cgImage.cropping(to: cropPixelRect) {
                        finalCGImage = cropped
                    }
                }
                
                CGImageDestinationAddImage(destination, finalCGImage, frameProperties as CFDictionary)
            }
            processed += 1
            progressHandler(Double(processed) / Double(frameCount))
        }
        
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "GIFExport", code: -2, userInfo: [NSLocalizedDescriptionKey: "Ошибка финализации GIF файла"])
        }
        progressHandler(1.0)
    }
}

/// Потокобезопасный трекер прогресса экспорта для AVAssetExportSession
private final class ExportProgressTracker: @unchecked Sendable {
    private weak var exportSession: AVAssetExportSession?
    private let progressHandler: @Sendable (Double) -> Void
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.justscreenshot.export.tracker")
    
    init(exportSession: AVAssetExportSession, progressHandler: @Sendable @escaping (Double) -> Void) {
        self.exportSession = exportSession
        self.progressHandler = progressHandler
    }
    
    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
        timer.setEventHandler { [weak self] in
            guard let self, let session = self.exportSession else { return }
            let prog = Double(session.progress)
            self.progressHandler(prog)
        }
        self.timer = timer
        timer.resume()
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
    }
}
