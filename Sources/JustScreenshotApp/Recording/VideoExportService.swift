import Foundation
import AVFoundation
import CoreGraphics
import CoreImage

/// Сервис экспорта видео: обрезка, скорость, кадрирование, Smart Zoom, burn-in размытия, MP4/GIF/WebP
public final class VideoExportService: @unchecked Sendable {
    public static let shared = VideoExportService()

    public typealias ExportOptions = VideoExportOptions

    private init() {}

    public func exportVideo(
        sourceURL: URL,
        destinationURL: URL,
        options: VideoExportOptions,
        progressHandler: @Sendable @escaping (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let durationCM = try await asset.load(.duration)
        let duration = durationCM.seconds
        let trim = VideoExportTrim.range(duration: duration, options: options)
        let startTime = trim.start
        let endTime = trim.end

        guard endTime > startTime else {
            throw VideoExportError.invalidTrimRange
        }

        let composition = AVMutableComposition()

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoExportError.videoTrackNotFound
        }

        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoExportError.compositionTrackFailed
        }

        let trimTimeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: endTime - startTime, preferredTimescale: 600)
        )

        try compVideoTrack.insertTimeRange(trimTimeRange, of: videoTrack, at: .zero)

        // Сохраняем и масштабируем аудиодорожку, если она присутствует в исходном файле
        let rate = Double(options.playbackRate > 0 ? options.playbackRate : 1.0)
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compAudioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            let audioTimeRange = try? await audioTrack.load(.timeRange)
            let audioEnd = audioTimeRange.map { CMTimeRangeGetEnd($0).seconds } ?? endTime
            if audioEnd > startTime {
                let validAudioDuration = min(endTime, audioEnd) - startTime
                let audioTrimRange = CMTimeRange(
                    start: CMTime(seconds: startTime, preferredTimescale: 600),
                    duration: CMTime(seconds: validAudioDuration, preferredTimescale: 600)
                )
                try? compAudioTrack.insertTimeRange(audioTrimRange, of: audioTrack, at: .zero)
                if rate != 1.0 {
                    let scaledAudioDuration = CMTime(seconds: validAudioDuration / rate, preferredTimescale: 600)
                    compAudioTrack.scaleTimeRange(
                        CMTimeRange(start: .zero, duration: audioTrimRange.duration),
                        toDuration: scaledAudioDuration
                    )
                }
            }
        }

        if rate != 1.0 {
            let scaledDuration = CMTime(
                seconds: (endTime - startTime) / rate,
                preferredTimescale: 600
            )
            compVideoTrack.scaleTimeRange(
                CMTimeRange(start: .zero, duration: trimTimeRange.duration),
                toDuration: scaledDuration
            )
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFPS = try await videoTrack.load(.nominalFrameRate)
        let displaySize = VideoAnnotationBurnIn.displaySize(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform
        )

        let burnIn = BurnInAnnotation.from(options.annotations)
        let hasCrop = options.cropRect.map { $0.width > 0 && $0.height > 0 } ?? false
        let needsComposition = hasCrop || !burnIn.isEmpty || options.smartZoom || options.showKeystrokes || options.showClicks || options.showTypingHighlight

        var videoComposition: AVMutableVideoComposition?

        if needsComposition {
            let cropTargetSize: CGSize?
            let renderWidth: CGFloat
            let renderHeight: CGFloat
            if let crop = options.cropRect, crop.width > 0, crop.height > 0 {
                let cw = max(2, floor(displaySize.width * min(1, crop.width) / 2) * 2)
                let ch = max(2, floor(displaySize.height * min(1, crop.height) / 2) * 2)
                cropTargetSize = CGSize(width: cw, height: ch)
                renderWidth = cw
                renderHeight = ch
            } else {
                cropTargetSize = nil
                renderWidth = max(2, floor(displaySize.width / 2) * 2)
                renderHeight = max(2, floor(displaySize.height / 2) * 2)
            }

            let targetRenderSize = CGSize(width: renderWidth, height: renderHeight)
            let compositionDuration = composition.duration.seconds
            let blurMask = VideoAnnotationBurnIn.makeBlurMask(annotations: burnIn, frameSize: displaySize)

            let vComp = AVMutableVideoComposition(asset: composition) { request in
                let sourceTime = startTime + request.compositionTime.seconds * rate
                let outputImage = VideoAnnotationBurnIn.processCIImage(
                    request.sourceImage,
                    blurMask: blurMask,
                    sourceTime: sourceTime,
                    compositionTime: request.compositionTime.seconds,
                    compositionDuration: compositionDuration,
                    options: options,
                    cropTargetSize: cropTargetSize
                )
                request.finish(with: outputImage, context: VideoAnnotationBurnIn.ciContext)
            }

            vComp.renderSize = targetRenderSize
            let effectiveFPS: Int32
            if nominalFPS.isFinite && nominalFPS >= 15 {
                effectiveFPS = min(60, Int32(nominalFPS.rounded()))
            } else {
                effectiveFPS = 30
            }
            vComp.frameDuration = CMTime(value: 1, timescale: effectiveFPS)
            videoComposition = vComp
        }

        let capturedComposition = composition
        let capturedVideoComposition = videoComposition

        try await VideoExportFileHelper.withTemporaryDestination(for: destinationURL) { tempURL in
            guard let exportSession = AVAssetExportSession(
                asset: capturedComposition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                throw VideoExportError.exportSessionCreationFailed
            }

            exportSession.outputURL = tempURL
            exportSession.outputFileType = .mp4
            exportSession.videoComposition = capturedVideoComposition

            let tracker = ExportProgressTracker(exportSession: exportSession, progressHandler: progressHandler)
            tracker.start()
            defer { tracker.stop() }

            nonisolated(unsafe) let session = exportSession
            await withTaskCancellationHandler {
                await session.export()
            } onCancel: {
                session.cancelExport()
            }

            try Task.checkCancellation()

            if exportSession.status == .completed {
                progressHandler(1.0)
            } else if let error = exportSession.error {
                throw error
            } else {
                throw VideoExportError.exportFailed("Export failed or was cancelled")
            }
        }
    }

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

    public func exportWebP(
        sourceURL: URL,
        destinationURL: URL,
        options: VideoExportOptions,
        progressHandler: @Sendable @escaping (Double) -> Void
    ) async throws {
        try await WebPExportService.shared.exportWebP(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            options: options,
            progressHandler: progressHandler
        )
    }
}
