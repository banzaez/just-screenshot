import Foundation
import AVFoundation
import CoreGraphics
import QuartzCore

/// Сервис экспорта видео: обрезка, скорость, кадрирование, burn-in аннотаций, MP4/GIF
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
        let duration = try await asset.load(.duration).seconds
        let trim = VideoExportTrim.range(duration: duration, options: options)
        let startTime = trim.start
        let endTime = trim.end
        
        let composition = AVMutableComposition()
        
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video track not found"])
        }
        
        let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )!
        
        let trimTimeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: endTime - startTime, preferredTimescale: 600)
        )
        
        try compVideoTrack.insertTimeRange(trimTimeRange, of: videoTrack, at: .zero)
        
        if options.playbackRate != 1.0 && options.playbackRate > 0 {
            let scaledDuration = CMTime(
                seconds: (endTime - startTime) / Double(options.playbackRate),
                preferredTimescale: 600
            )
            compVideoTrack.scaleTimeRange(
                CMTimeRange(start: .zero, duration: trimTimeRange.duration),
                toDuration: scaledDuration
            )
        }
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let isRotated = abs(preferredTransform.b) == 1.0 || abs(preferredTransform.c) == 1.0
        let displaySize = isRotated
            ? CGSize(width: naturalSize.height, height: naturalSize.width)
            : naturalSize
        
        let burnIn = await MainActor.run { BurnInAnnotation.from(options.annotations) }
        let needsComposition = options.cropRect != nil || !burnIn.isEmpty || options.smartZoom
        
        var videoComposition: AVMutableVideoComposition?
        
        if needsComposition {
            let crop = options.cropRect
            let renderWidth: CGFloat
            let renderHeight: CGFloat
            if let crop, crop.width > 0, crop.height > 0 {
                renderWidth = floor(displaySize.width * crop.width / 2) * 2
                renderHeight = floor(displaySize.height * crop.height / 2) * 2
            } else {
                renderWidth = floor(displaySize.width / 2) * 2
                renderHeight = floor(displaySize.height / 2) * 2
            }
            
            let vComp = AVMutableVideoComposition()
            vComp.renderSize = CGSize(width: max(2, renderWidth), height: max(2, renderHeight))
            vComp.frameDuration = CMTime(value: 1, timescale: 30)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
            var transform = preferredTransform
            if let crop, crop.width > 0, crop.height > 0 {
                let tx = -(crop.origin.x * displaySize.width)
                let ty = -(crop.origin.y * displaySize.height)
                transform = transform.concatenating(CGAffineTransform(translationX: tx, y: ty))
            }
            if options.smartZoom {
                applySmartZoom(
                    layerInstruction: layerInstruction,
                    baseTransform: transform,
                    displaySize: displaySize,
                    duration: composition.duration.seconds,
                    options: options
                )
            } else {
                layerInstruction.setTransform(transform, at: .zero)
            }
            
            instruction.layerInstructions = [layerInstruction]
            vComp.instructions = [instruction]
            
            if !burnIn.isEmpty {
                // CoreAnimationTool требует вызова с MainActor
                let tool = await MainActor.run {
                    VideoAnnotationBurnIn.makeAnimationTool(
                        annotations: burnIn,
                        renderSize: vComp.renderSize
                    )
                }
                vComp.animationTool = tool
            }
            
            videoComposition = vComp
        }
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "VideoExport", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
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
            throw NSError(domain: "VideoExport", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export failed or was cancelled"])
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
    
    // MARK: - Smart Zoom Animation
    
    private func applySmartZoom(
        layerInstruction: AVMutableVideoCompositionLayerInstruction,
        baseTransform: CGAffineTransform,
        displaySize: CGSize,
        duration: Double,
        options: VideoExportOptions
    ) {
        let makeTransform: (CGPoint, CGFloat) -> CGAffineTransform = { focus, scale in
            let fx = min(1.0, max(0.0, focus.x)) * displaySize.width
            let fy = min(1.0, max(0.0, 1.0 - focus.y)) * displaySize.height
            var zt = baseTransform
            zt = zt.translatedBy(x: fx, y: fy)
            zt = zt.scaledBy(x: scale, y: scale)
            zt = zt.translatedBy(x: -fx, y: -fy)
            return zt
        }
        
        guard let track = options.cursorTrack, !track.keyframes.isEmpty, duration > 1.0 else {
            // Фолбэк на точку первой аннотации или центр
            let focusCenter: CGPoint
            if let firstAnno = options.annotations.first {
                focusCenter = CGPoint(x: firstAnno.rect.midX, y: 1.0 - firstAnno.rect.midY)
            } else {
                focusCenter = CGPoint(x: 0.5, y: 0.5)
            }
            let zoomTransform = makeTransform(focusCenter, 1.25)
            let tIn = CMTime(seconds: min(1.0, duration * 0.2), preferredTimescale: 600)
            let tOut = CMTime(seconds: max(0.5, duration - 0.7), preferredTimescale: 600)
            layerInstruction.setTransformRamp(fromStart: baseTransform, toEnd: zoomTransform, timeRange: CMTimeRange(start: .zero, duration: tIn))
            layerInstruction.setTransform(zoomTransform, at: tIn)
            layerInstruction.setTransformRamp(fromStart: zoomTransform, toEnd: baseTransform, timeRange: CMTimeRange(start: tOut, duration: CMTime(seconds: duration - tOut.seconds, preferredTimescale: 600)))
            return
        }
        
        // Генерация путевых точек (waypoints) по треку курсора с учетом выбранного режима и масштаба
        var waypoints: [(time: Double, transform: CGAffineTransform)] = []
        let step: Double = 1.0
        var t: Double = 0.0
        while t <= duration {
            let state = track.cameraState(
                at: t,
                scale: options.smartZoomScale,
                mode: options.smartZoomMode,
                autoZoomOutOnIdle: options.autoZoomOutOnIdle
            )
            let trans = makeTransform(state.focus, state.zoom)
            waypoints.append((time: t, transform: trans))
            t += step
        }
        if let last = waypoints.last, last.time < duration {
            let state = track.cameraState(
                at: duration,
                scale: options.smartZoomScale,
                mode: options.smartZoomMode,
                autoZoomOutOnIdle: options.autoZoomOutOnIdle
            )
            waypoints.append((time: duration, transform: makeTransform(state.focus, state.zoom)))
        }
        
        guard waypoints.count >= 2 else {
            layerInstruction.setTransform(waypoints.first?.transform ?? baseTransform, at: .zero)
            return
        }
        
        for i in 0..<(waypoints.count - 1) {
            let wp0 = waypoints[i]
            let wp1 = waypoints[i + 1]
            let startCM = CMTime(seconds: wp0.time, preferredTimescale: 600)
            let durCM = CMTime(seconds: max(0.01, wp1.time - wp0.time), preferredTimescale: 600)
            layerInstruction.setTransformRamp(
                fromStart: wp0.transform,
                toEnd: wp1.transform,
                timeRange: CMTimeRange(start: startCM, duration: durCM)
            )
        }
    }
}
