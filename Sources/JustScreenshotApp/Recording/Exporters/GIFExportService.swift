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
        let plan = try await AnimatedFrameExtractor.preparePlan(asset: asset, options: options, defaultFPS: 15)
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            UTType.gif.identifier as CFString,
            plan.expectedFrames,
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
                kCGImagePropertyGIFDelayTime as String: plan.frameDelay
            ]
        ]
        
        let decodedFrames = try await AnimatedFrameExtractor.extractFrames(
            asset: asset,
            plan: plan,
            options: options,
            maxDimension: 800
        ) { image, frameIndex in
            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
            progressHandler(min(0.99, Double(frameIndex) / Double(plan.expectedFrames)))
        }
        
        guard decodedFrames > 0 else {
            throw NSError(domain: "GIFExport", code: -3, userInfo: [NSLocalizedDescriptionKey: "No frames were decoded from video"])
        }
        
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "GIFExport", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize GIF"])
        }
        progressHandler(1.0)
    }
}
