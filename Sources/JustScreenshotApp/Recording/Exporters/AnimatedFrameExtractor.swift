import Foundation
import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo

/// Единый конвейер извлечения и CoreImage-обработки кадров для GIF и WebP
enum AnimatedFrameExtractor {

    private struct ConsumerFrameError: Error {
        let underlying: Error
    }

    struct Plan: Sendable {
        let startTime: Double
        let endTime: Double
        let totalDuration: Double
        let fps: Int
        let rate: Double
        let frameDelay: Double
        let sourceSampleInterval: Double
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
        let totalDuration = endTime - startTime

        guard totalDuration > 0 else {
            throw VideoExportError.invalidTrimRange
        }

        let rawFPS = options.gifFPS > 0 ? options.gifFPS : defaultFPS
        let fps = max(5, min(30, rawFPS))
        let rate = max(0.1, Double(options.playbackRate > 0 ? options.playbackRate : 1.0))
        // Задержка кадра в выходной анимации зависит только от FPS выходного потока
        let frameDelay = 1.0 / Double(fps)
        // Шаг выборки вдоль исходного времени видео пропорционален playbackRate
        let sourceSampleInterval = rate / Double(fps)
        let expectedFrames = max(1, Int(ceil((totalDuration / rate) * Double(fps))))
        let burnIn = BurnInAnnotation.from(options.annotations)

        return Plan(
            startTime: startTime,
            endTime: endTime,
            totalDuration: totalDuration,
            fps: fps,
            rate: rate,
            frameDelay: frameDelay,
            sourceSampleInterval: sourceSampleInterval,
            expectedFrames: expectedFrames,
            burnIn: burnIn
        )
    }

    /// Декодирует кадры с hold-сэмплированием VFR-источника и обработкой через VideoAnnotationBurnIn
    static func extractFrames(
        asset: AVURLAsset,
        plan: Plan,
        options: VideoExportOptions,
        maxDimension: CGFloat,
        onFrame: (CGImage, Int) throws -> Void
    ) async throws -> Int {
        var decodedFrames = 0
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let blurMask: CIImage?

        if let firstTrack = tracks.first {
            let naturalSize = try await firstTrack.load(.naturalSize)
            let preferredTransform = try await firstTrack.load(.preferredTransform)
            let displaySize = VideoAnnotationBurnIn.displaySize(
                naturalSize: naturalSize,
                preferredTransform: preferredTransform
            )
            blurMask = VideoAnnotationBurnIn.makeBlurMask(annotations: plan.burnIn, frameSize: displaySize)

            let orientTransform = VideoAnnotationBurnIn.orientingTransform(
                naturalSize: naturalSize,
                preferredTransform: preferredTransform
            )

            do {
                let reader = try AVAssetReader(asset: asset)
                reader.timeRange = CMTimeRange(
                    start: CMTime(seconds: plan.startTime, preferredTimescale: 600),
                    duration: CMTime(seconds: plan.totalDuration, preferredTimescale: 600)
                )
                let outputSettings: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                let trackOutput = AVAssetReaderTrackOutput(track: firstTrack, outputSettings: outputSettings)
                trackOutput.alwaysCopiesSampleData = false
                reader.add(trackOutput)

                if reader.startReading() {
                    defer {
                        if reader.status == .reading {
                            reader.cancelReading()
                        }
                    }

                    let maxSlots = max(plan.expectedFrames + 2, 1)
                    var nextSampleTime = plan.startTime
                    var heldPixelBuffer: CVPixelBuffer?

                    func emitHeldBuffer(_ pixelBuffer: CVPixelBuffer, at sourceTime: Double) throws {
                        try autoreleasepool {
                            let baseCI = CIImage(cvPixelBuffer: pixelBuffer).transformed(by: orientTransform)
                            let processed = VideoAnnotationBurnIn.processCIImage(
                                baseCI,
                                blurMask: blurMask,
                                sourceTime: sourceTime,
                                compositionTime: (sourceTime - plan.startTime) / plan.rate,
                                compositionDuration: plan.totalDuration / plan.rate,
                                options: options,
                                maxDimension: maxDimension
                            )
                            guard let cgImage = VideoAnnotationBurnIn.renderCGImage(processed) else { return }
                            decodedFrames += 1
                            do {
                                try onFrame(cgImage, decodedFrames)
                            } catch {
                                throw ConsumerFrameError(underlying: error)
                            }
                        }
                    }

                    while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
                        try Task.checkCancellation()
                        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
                        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

                        if let prev = heldPixelBuffer {
                            while nextSampleTime + 1e-6 < pts && nextSampleTime < plan.endTime - 1e-6 && decodedFrames < maxSlots {
                                try emitHeldBuffer(prev, at: nextSampleTime)
                                nextSampleTime += plan.sourceSampleInterval
                            }
                        } else {
                            // Если первый кадр в триме начинается чуть позже startTime, заполняем начальные слоты первым буфером
                            while nextSampleTime + 1e-6 < pts && nextSampleTime < plan.endTime - 1e-6 && decodedFrames < maxSlots {
                                try emitHeldBuffer(pixelBuffer, at: nextSampleTime)
                                nextSampleTime += plan.sourceSampleInterval
                            }
                        }

                        heldPixelBuffer = pixelBuffer
                        if nextSampleTime <= pts + 1e-6 && nextSampleTime < plan.endTime - 1e-6 && decodedFrames < maxSlots {
                            try emitHeldBuffer(pixelBuffer, at: nextSampleTime)
                            nextSampleTime += plan.sourceSampleInterval
                        }
                    }

                    // VFR tail hold до конца обрезанного диапазона
                    if let tailBuffer = heldPixelBuffer {
                        while nextSampleTime < plan.endTime - 1e-6 && decodedFrames < maxSlots {
                            try Task.checkCancellation()
                            try emitHeldBuffer(tailBuffer, at: nextSampleTime)
                            nextSampleTime += plan.sourceSampleInterval
                        }
                        if decodedFrames == 0 {
                            try emitHeldBuffer(tailBuffer, at: plan.startTime)
                        }
                    }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch let consumerError as ConsumerFrameError {
                throw consumerError.underlying
            } catch {
                // Если поток чтения упал до декодирования первого кадра, пробуем fallback ниже
                if decodedFrames > 0 {
                    throw error
                }
            }
        } else {
            blurMask = nil
        }

        // Резервный механизм (Fallback): AVAssetImageGenerator
        if decodedFrames == 0 {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            if !options.smartZoom && options.cropRect == nil && plan.burnIn.isEmpty && !options.showKeystrokes && !options.showClicks {
                generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
            }
            let tolerance = CMTime(seconds: 0.05, preferredTimescale: 600)
            generator.requestedTimeToleranceBefore = tolerance
            generator.requestedTimeToleranceAfter = tolerance

            var cmTimes: [CMTime] = []
            cmTimes.reserveCapacity(plan.expectedFrames)
            var t = plan.startTime
            while t < plan.endTime - 1e-6 && cmTimes.count < plan.expectedFrames + 2 {
                cmTimes.append(CMTime(seconds: min(plan.endTime - 0.001, t), preferredTimescale: 600))
                t += plan.sourceSampleInterval
            }
            if cmTimes.isEmpty {
                cmTimes.append(CMTime(seconds: plan.startTime, preferredTimescale: 600))
            }

            var cachedFallbackMask = blurMask
            for try await result in generator.images(for: cmTimes) {
                try Task.checkCancellation()
                try autoreleasepool {
                    let rawCGImage = try result.image
                    let ci = CIImage(cgImage: rawCGImage)
                    if cachedFallbackMask == nil && !plan.burnIn.isEmpty {
                        cachedFallbackMask = VideoAnnotationBurnIn.makeBlurMask(
                            annotations: plan.burnIn,
                            frameSize: ci.extent.size
                        )
                    }
                    let actualSeconds = (try? result.actualTime.seconds).flatMap { $0.isFinite ? $0 : nil }
                        ?? result.requestedTime.seconds
                    let processed = VideoAnnotationBurnIn.processCIImage(
                        ci,
                        blurMask: cachedFallbackMask,
                        sourceTime: actualSeconds,
                        compositionTime: (actualSeconds - plan.startTime) / plan.rate,
                        compositionDuration: plan.totalDuration / plan.rate,
                        options: options,
                        maxDimension: maxDimension
                    )
                    guard let cgImage = VideoAnnotationBurnIn.renderCGImage(processed) else { return }
                    decodedFrames += 1
                    try onFrame(cgImage, decodedFrames)
                }
            }
        }

        return decodedFrames
    }
}
