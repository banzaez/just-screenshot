import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Сервис покадрового создания анимированного GIF из видео
public final class GIFExportService: @unchecked Sendable {
    public static let shared = GIFExportService()
    
    private init() {}
    
    public func exportGIF(
        sourceURL: URL,
        destinationURL: URL,
        options: VideoExportOptions,
        progressHandler: @Sendable @escaping (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration).seconds
        let trim = VideoExportTrim.range(duration: duration, options: options)
        let startTime = trim.start
        let endTime = trim.end
        let totalDuration = endTime - startTime
        
        let fps = max(5, min(30, options.gifFPS))
        let rate = max(0.01, Double(options.playbackRate > 0 ? options.playbackRate : 1))
        // Длительность кадра с учётом скорости; timeline семплим по исходным секундам
        let frameDuration = (1.0 / Double(fps)) / rate
        let frameCount = max(1, Int((totalDuration / rate) * Double(fps)))
        
        let burnIn = await MainActor.run { BurnInAnnotation.from(options.annotations) }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 800, height: 800)
        
        var cmTimes: [CMTime] = []
        for i in 0..<frameCount {
            // В исходной шкале времени: при 2x берём кадры вдвое реже по source timeline? 
            // Пользователь ожидает ускоренное/замедленное воспроизведение GIF.
            // Семплируем source равномерно по trim, delay сжимаем/растягиваем через frameDuration.
            let timeSec = startTime + (Double(i) / Double(max(frameCount - 1, 1))) * totalDuration
            cmTimes.append(CMTime(seconds: min(endTime - 0.001, timeSec), preferredTimescale: 600))
        }
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw NSError(domain: "GIFExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create GIF destination"])
        }
        
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
        
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDuration
            ]
        ]
        
        var processed = 0
        for try await result in generator.images(for: cmTimes) {
            var cgImage = try result.image
            
            // Сначала burn-in в полной системе координат кадра, затем crop
            if !burnIn.isEmpty {
                cgImage = VideoAnnotationBurnIn.composite(cgImage, annotations: burnIn)
            }
            
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
                    cgImage = cropped
                }
            }
            
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            processed += 1
            progressHandler(Double(processed) / Double(frameCount))
        }
        
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "GIFExport", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize GIF"])
        }
        progressHandler(1.0)
    }
}
