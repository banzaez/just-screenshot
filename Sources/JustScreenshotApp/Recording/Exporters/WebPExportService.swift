import Foundation
import AVFoundation
import CoreGraphics
import AppKit
import webp

/// Сервис создания анимированной WebP-анимации из видео
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

        try await VideoExportFileHelper.withTemporaryDestination(for: destinationURL) { tempURL in
            let encoder = WebPAnimatedEncoder()
            var initializedSize: (width: Int, height: Int)?

            _ = try await AnimatedFrameExtractor.extractFrames(
                asset: asset,
                plan: plan,
                options: options,
                maxDimension: 1280
            ) { cgImage, frameIndex in
                let width = cgImage.width
                let height = cgImage.height
                if let expected = initializedSize {
                    guard expected.width == width, expected.height == height else {
                        throw VideoExportError.exportFailed("Inconsistent WebP frame dimensions")
                    }
                } else {
                    let config = WebpEncoderConfig.preset(.picture, quality: 80)
                    try encoder.create(config: config, width: width, height: height)
                    initializedSize = (width, height)
                }
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
                try encoder.addImage(image: nsImage, duration: durationMs)
                progressHandler(min(0.99, Double(frameIndex) / Double(plan.expectedFrames)))
            }

            guard initializedSize != nil else {
                throw VideoExportError.exportFailed("No frames processed")
            }

            let webpData = try encoder.encode(loopCount: 0)
            try webpData.write(to: tempURL, options: .atomic)
        }

        progressHandler(1.0)
    }
}
