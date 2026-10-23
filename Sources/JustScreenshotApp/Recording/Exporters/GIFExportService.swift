import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import VideoToolbox
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
        let totalDuration = max(0.01, endTime - startTime)
        
        let fps = max(5, min(30, options.gifFPS))
        let rate = max(0.01, Double(options.playbackRate > 0 ? options.playbackRate : 1))
        // Длительность кадра в GIF с учётом скорости воспроизведения
        let frameDelay = (1.0 / Double(fps)) / rate
        let sampleInterval = 1.0 / Double(fps)
        let expectedFrames = max(1, Int((totalDuration / rate) * Double(fps)))
        
        let burnIn = await MainActor.run { BurnInAnnotation.from(options.annotations) }
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            UTType.gif.identifier as CFString,
            expectedFrames,
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
                kCGImagePropertyGIFDelayTime as String: frameDelay
            ]
        ]
        
        // Попытка быстрого потокового чтения через AVAssetReader (без исчерпания декодеров VideoToolbox)
        var decodedFrames = 0
        let tracks = try await asset.loadTracks(withMediaType: .video)
        
        if let videoTrack = tracks.first {
            do {
                let reader = try AVAssetReader(asset: asset)
                reader.timeRange = CMTimeRange(
                    start: CMTime(seconds: startTime, preferredTimescale: 600),
                    duration: CMTime(seconds: totalDuration, preferredTimescale: 600)
                )
                let outputSettings: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
                reader.add(trackOutput)
                
                if reader.startReading() {
                    var nextSampleTime = startTime
                    while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
                        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                        if pts >= nextSampleTime || decodedFrames == 0 {
                            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                                var cgImage: CGImage?
                                VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
                                if var image = cgImage {
                                    if !burnIn.isEmpty {
                                        image = VideoAnnotationBurnIn.composite(image, annotations: burnIn)
                                    }
                                    if let crop = options.cropRect, crop.width > 0, crop.height > 0 {
                                        let w = CGFloat(image.width)
                                        let h = CGFloat(image.height)
                                        let cropPixelRect = CGRect(
                                            x: crop.origin.x * w,
                                            y: crop.origin.y * h,
                                            width: crop.width * w,
                                            height: crop.height * h
                                        )
                                        if let cropped = image.cropping(to: cropPixelRect) {
                                            image = cropped
                                        }
                                    }
                                    image = Self.downscale(image: image, maxDimension: 800)
                                    CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
                                    decodedFrames += 1
                                    progressHandler(min(0.99, Double(decodedFrames) / Double(expectedFrames)))
                                }
                            }
                            nextSampleTime += sampleInterval
                        }
                    }
                }
            } catch {
                // Если AVAssetReader не удался, fallback на AVAssetImageGenerator ниже
                decodedFrames = 0
            }
        }
        
        // Резервный механизм (Fallback): AVAssetImageGenerator с мягкими допусками по времени (без .zero)
        if decodedFrames == 0 {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let tolerance = CMTime(seconds: 0.05, preferredTimescale: 600)
            generator.requestedTimeToleranceBefore = tolerance
            generator.requestedTimeToleranceAfter = tolerance
            
            var cmTimes: [CMTime] = []
            for i in 0..<expectedFrames {
                let timeSec = startTime + (Double(i) / Double(max(expectedFrames - 1, 1))) * totalDuration
                cmTimes.append(CMTime(seconds: min(endTime - 0.001, timeSec), preferredTimescale: 600))
            }
            
            for try await result in generator.images(for: cmTimes) {
                var cgImage = try result.image
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
                cgImage = Self.downscale(image: cgImage, maxDimension: 800)
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
                decodedFrames += 1
                progressHandler(min(0.99, Double(decodedFrames) / Double(expectedFrames)))
            }
        }
        
        guard decodedFrames > 0 else {
            throw NSError(domain: "GIFExport", code: -3, userInfo: [NSLocalizedDescriptionKey: "No frames were decoded from video"])
        }
        
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "GIFExport", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize GIF"])
        }
        progressHandler(1.0)
    }
    
    private static func downscale(image: CGImage, maxDimension: CGFloat) -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let maxSide = max(width, height)
        guard maxSide > maxDimension else { return image }
        
        let scale = maxDimension / maxSide
        let targetWidth = max(1, Int(width * scale))
        let targetHeight = max(1, Int(height * scale))
        
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage() ?? image
    }
}
