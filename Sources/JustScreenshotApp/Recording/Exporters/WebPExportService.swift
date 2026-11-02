import Foundation
import AVFoundation
import CoreGraphics
import AppKit
import webp

/// Сервис создания плавной анимированной WebP-анимации из видео (миллионы цветов, сжатие, меньший размер)
public final class WebPExportService: @unchecked Sendable {
    public static let shared = WebPExportService()
    
    private init() {}
    
    public func exportWebP(
        sourceURL: URL,
        destinationURL: URL,
        options: VideoExportOptions,
        progressHandler: @Sendable @escaping (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let plan = try await AnimatedFrameExtractor.preparePlan(asset: asset, options: options, defaultFPS: 15)
        let durationMs = max(10, Int(plan.frameDelay * 1000))
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        let encoder = WebPAnimatedEncoder()
        var isEncoderInitialized = false
        
        _ = try await AnimatedFrameExtractor.extractFrames(
            asset: asset,
            plan: plan,
            options: options,
            maxDimension: 1280
        ) { cgImage, frameIndex in
            let width = cgImage.width
            let height = cgImage.height
            if !isEncoderInitialized {
                let config = WebpEncoderConfig.preset(.picture, quality: 80)
                try encoder.create(config: config, width: width, height: height)
                isEncoderInitialized = true
            }
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
            try encoder.addImage(image: nsImage, duration: durationMs)
            progressHandler(min(0.99, Double(frameIndex) / Double(plan.expectedFrames)))
        }
        
        guard isEncoderInitialized else {
            throw NSError(domain: "WebPExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "No frames processed"])
        }
        
        let webpData = try encoder.encode(loopCount: 0)
        try webpData.write(to: destinationURL)
        progressHandler(1.0)
    }
}
