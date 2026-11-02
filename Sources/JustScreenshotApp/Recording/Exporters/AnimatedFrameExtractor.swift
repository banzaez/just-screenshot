import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import VideoToolbox

/// Единый высокопроизводительный конвейер извлечения и однопроходной обработки кадров для GIF и WebP
enum AnimatedFrameExtractor {
    
    struct Plan: Sendable {
        let startTime: Double
        let endTime: Double
        let totalDuration: Double
        let fps: Int
        let rate: Double
        let frameDelay: Double
        let sampleInterval: Double
        let expectedFrames: Int
        let burnIn: [BurnInAnnotation]
    }
    
    static func preparePlan(
        asset: AVURLAsset,
        options: VideoExportOptions,
        defaultFPS: Int = 15
    ) async throws -> Plan {
        let duration = try await asset.load(.duration).seconds
        let trim = VideoExportTrim.range(duration: duration, options: options)
        let startTime = trim.start
        let endTime = trim.end
        let totalDuration = max(0.01, endTime - startTime)
        
        let rawFPS = options.gifFPS > 0 ? options.gifFPS : defaultFPS
        let fps = max(5, min(30, rawFPS))
        let rate = max(0.01, Double(options.playbackRate > 0 ? options.playbackRate : 1))
        let frameDelay = (1.0 / Double(fps)) / rate
        let sampleInterval = 1.0 / Double(fps)
        let expectedFrames = max(1, Int((totalDuration / rate) * Double(fps)))
        let burnIn = await MainActor.run { BurnInAnnotation.from(options.annotations) }
        
        return Plan(
            startTime: startTime,
            endTime: endTime,
            totalDuration: totalDuration,
            fps: fps,
            rate: rate,
            frameDelay: frameDelay,
            sampleInterval: sampleInterval,
            expectedFrames: expectedFrames,
            burnIn: burnIn
        )
    }
    
    /// Декодирует кадры с применением кропа, Smart Zoom, даунскейла и burn-in аннотаций за один проход CGContext
    static func extractFrames(
        asset: AVURLAsset,
        plan: Plan,
        options: VideoExportOptions,
        maxDimension: CGFloat,
        onFrame: (CGImage, Int) throws -> Void
    ) async throws -> Int {
        var decodedFrames = 0
        let tracks = try await asset.loadTracks(withMediaType: .video)
        
        if let videoTrack = tracks.first {
            do {
                let reader = try AVAssetReader(asset: asset)
                reader.timeRange = CMTimeRange(
                    start: CMTime(seconds: plan.startTime, preferredTimescale: 600),
                    duration: CMTime(seconds: plan.totalDuration, preferredTimescale: 600)
                )
                let outputSettings: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
                trackOutput.alwaysCopiesSampleData = false
                reader.add(trackOutput)
                
                if reader.startReading() {
                    var nextSampleTime = plan.startTime
                    while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
                        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                        if pts >= nextSampleTime || decodedFrames == 0 {
                            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                                var rawCGImage: CGImage?
                                VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &rawCGImage)
                                if let rawCGImage {
                                    let processed = processFrameSinglePass(
                                        rawCGImage,
                                        at: max(0, pts - plan.startTime),
                                        burnIn: plan.burnIn,
                                        options: options,
                                        maxDimension: maxDimension
                                    )
                                    decodedFrames += 1
                                    try onFrame(processed, decodedFrames)
                                }
                            }
                            nextSampleTime += plan.sampleInterval
                        }
                    }
                }
            } catch {
                decodedFrames = 0
            }
        }
        
        // Резервный механизм (Fallback): AVAssetImageGenerator с мягкими допусками по времени
        if decodedFrames == 0 {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let tolerance = CMTime(seconds: 0.05, preferredTimescale: 600)
            generator.requestedTimeToleranceBefore = tolerance
            generator.requestedTimeToleranceAfter = tolerance
            
            var cmTimes: [CMTime] = []
            cmTimes.reserveCapacity(plan.expectedFrames)
            for i in 0..<plan.expectedFrames {
                let timeSec = plan.startTime + (Double(i) / Double(max(plan.expectedFrames - 1, 1))) * plan.totalDuration
                cmTimes.append(CMTime(seconds: min(plan.endTime - 0.001, timeSec), preferredTimescale: 600))
            }
            
            for try await result in generator.images(for: cmTimes) {
                let rawCGImage = try result.image
                let actualSeconds = (try? result.actualTime.seconds) ?? result.requestedTime.seconds
                let relTime = max(0, actualSeconds - plan.startTime)
                let processed = processFrameSinglePass(
                    rawCGImage,
                    at: relTime,
                    burnIn: plan.burnIn,
                    options: options,
                    maxDimension: maxDimension
                )
                decodedFrames += 1
                try onFrame(processed, decodedFrames)
            }
        }
        
        return decodedFrames
    }
    
    /// Однопроходная обработка кадра: аннотации + Smart Zoom + кроп + масштабирование в едином CGContext
    private static func processFrameSinglePass(
        _ image: CGImage,
        at relativeTime: Double,
        burnIn: [BurnInAnnotation],
        options: VideoExportOptions,
        maxDimension: CGFloat
    ) -> CGImage {
        let srcW = CGFloat(image.width)
        let srcH = CGFloat(image.height)
        guard srcW > 0, srcH > 0 else { return image }
        
        let cropNorm: CGRect
        if let c = options.cropRect, c.width > 0, c.height > 0 {
            cropNorm = c
        } else {
            cropNorm = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        
        let croppedW = max(1, srcW * cropNorm.width)
        let croppedH = max(1, srcH * cropNorm.height)
        let maxSide = max(croppedW, croppedH)
        let downscaleFactor = maxSide > maxDimension ? (maxDimension / maxSide) : 1.0
        
        let targetWidth = max(1, Int((croppedW * downscaleFactor).rounded()))
        let targetHeight = max(1, Int((croppedH * downscaleFactor).rounded()))
        
        // Быстрый путь: если нет аннотаций, кропа, Smart Zoom и даунскейла — возвращаем исходный CGImage без копирования
        if burnIn.isEmpty,
           !options.smartZoom,
           cropNorm == CGRect(x: 0, y: 0, width: 1, height: 1),
           targetWidth == image.width,
           targetHeight == image.height {
            return image
        }
        
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(
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
        
        ctx.interpolationQuality = .high
        
        // Масштабируем из пространства кропнутого исходника в целевой буфер
        let scaleX = CGFloat(targetWidth) / croppedW
        let scaleY = CGFloat(targetHeight) / croppedH
        ctx.scaleBy(x: scaleX, y: scaleY)
        
        // Сдвиг для учёта кропа (в CGContext origin внизу слева, а в cropNorm origin вверху слева)
        let cropOffsetX = cropNorm.origin.x * srcW
        let cropOffsetYBottom = (1.0 - cropNorm.origin.y - cropNorm.height) * srcH
        ctx.translateBy(x: -cropOffsetX, y: -cropOffsetYBottom)
        
        // Применение Smart Zoom вокруг точки фокуса
        if options.smartZoom, let track = options.cursorTrack, !track.keyframes.isEmpty {
            let state = track.cameraState(
                at: relativeTime,
                scale: options.smartZoomScale,
                mode: options.smartZoomMode,
                autoZoomOutOnIdle: options.autoZoomOutOnIdle
            )
            if state.zoom > 1.001 {
                let fx = min(1.0, max(0.0, state.focus.x)) * srcW
                let fy = min(1.0, max(0.0, 1.0 - state.focus.y)) * srcH
                ctx.translateBy(x: fx, y: fy)
                ctx.scaleBy(x: state.zoom, y: state.zoom)
                ctx.translateBy(x: -fx, y: -fy)
            }
        }
        
        // 1. Отрисовка исходного видеокадра
        let fullSize = CGSize(width: srcW, height: srcH)
        ctx.draw(image, in: CGRect(origin: .zero, size: fullSize))
        
        // 2. Отрисовка burn-in аннотаций в том же контексте (top-left координаты)
        if !burnIn.isEmpty {
            ctx.saveGState()
            ctx.translateBy(x: 0, y: srcH)
            ctx.scaleBy(x: 1, y: -1)
            VideoAnnotationBurnIn.draw(burnIn, in: ctx, videoSize: fullSize)
            ctx.restoreGState()
        }
        
        return ctx.makeImage() ?? image
    }
}
