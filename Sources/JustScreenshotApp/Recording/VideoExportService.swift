import Foundation
import AVFoundation
import CoreGraphics

/// Сервис экспорта видео: обрезка (trimming), изменение скорости, кадрирование (crop), экспорт в MP4 и анимированный GIF
public final class VideoExportService: @unchecked Sendable {
    public static let shared = VideoExportService()
    
    // Typealias для обратной совместимости вызовов
    public typealias ExportOptions = VideoExportOptions
    
    private init() {}
    
    /// Экспорт в MP4 с обрезкой, масштабированием скорости и кадрированием
    public func exportVideo(
        sourceURL: URL,
        destinationURL: URL,
        options: VideoExportOptions,
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
        
        let tracker = ExportProgressTracker(exportSession: exportSession, progressHandler: progressHandler)
        tracker.start()
        
        await exportSession.export()
        tracker.stop()
        
        if exportSession.status == .completed {
            progressHandler(1.0)
        } else if let error = exportSession.error {
            throw error
        } else {
            throw NSError(domain: "VideoExport", code: -3, userInfo: [NSLocalizedDescriptionKey: "Экспорт завершился с ошибкой или был отменен"])
        }
    }
    
    /// Экспорт в анимированный GIF делегируется GIFExportService
    public func exportGIF(
        sourceURL: URL,
        destinationURL: URL,
        options: VideoExportOptions,
        progressHandler: @Sendable @escaping (Double) -> Void
    ) async throws {
        try await GIFExportService.shared.exportGIF(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            options: options,
            progressHandler: progressHandler
        )
    }
}
