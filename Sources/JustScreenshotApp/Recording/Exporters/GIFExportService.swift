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
        let startTime = max(0, options.trimStart)
        let endTime = options.trimEnd > startTime ? min(duration, options.trimEnd) : duration
        let totalDuration = endTime - startTime
        
        let fps = max(5, min(30, options.gifFPS))
        let frameCount = max(1, Int(totalDuration * Double(fps)))
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
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
