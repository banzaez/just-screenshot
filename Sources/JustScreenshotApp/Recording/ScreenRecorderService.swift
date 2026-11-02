import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreGraphics
import Cocoa

/// Сервис записи выбранной области экрана через ScreenCaptureKit Stream + AVAssetWriter
public final class ScreenRecorderService: NSObject, @unchecked Sendable, SCStreamOutput, SCStreamDelegate {
    public static let shared = ScreenRecorderService()
    
    private let recordingQueue = DispatchQueue(label: "com.justscreenshot.recorder.queue")
    
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private var isRecording = false
    private var isPaused = false
    private var outputURL: URL?
    private var recordingStartTime: CMTime?
    private var pauseStartTime: CMTime?
    private var totalPausedDuration: CMTime = .zero
    
    public override init() {
        super.init()
    }
    
    /// Запуск записи выбранной области экрана
    public func startRecording(rect: CGRect, destinationURL: URL) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { disp in
            let dispRect = CGRect(x: CGFloat(disp.frame.origin.x),
                                  y: CGFloat(disp.frame.origin.y),
                                  width: CGFloat(disp.frame.width),
                                  height: CGFloat(disp.frame.height))
            return dispRect.intersects(rect)
        }) ?? content.displays.first else {
            throw NSError(domain: "ScreenRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Display not found"])
        }
        
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let excludedWindows = content.windows.filter {
            JustScreenshotWindowTitles.shouldExcludeFromCapture($0, currentPID: currentPID)
        }
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        
        // Преобразуем глобальные координаты в локальные координаты выбранного монитора
        let localRect = CGRect(
            x: rect.origin.x - CGFloat(display.frame.origin.x),
            y: rect.origin.y - CGFloat(display.frame.origin.y),
            width: rect.width,
            height: rect.height
        )
        
        let scale: CGFloat = display.frame.width > 0 ? CGFloat(display.width) / CGFloat(display.frame.width) : 2.0
        let config = SCStreamConfiguration()
        config.sourceRect = localRect
        let targetWidth = Int(rect.width * scale)
        let targetHeight = Int(rect.height * scale)
        // Размеры должны быть четными для H.264
        config.width = targetWidth % 2 == 0 ? targetWidth : targetWidth + 1
        config.height = targetHeight % 2 == 0 ? targetHeight : targetHeight + 1
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        
        // Настройка AVAssetWriter
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.width,
            AVVideoHeightKey: config.height
        ]
        
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: config.width,
                kCVPixelBufferHeightKey as String: config.height
            ]
        )
        
        if writer.canAdd(input) {
            writer.add(input)
        }
        
        writer.startWriting()
        
        let scStream = SCStream(filter: filter, configuration: config, delegate: self)
        
        recordingQueue.sync {
            self.outputURL = destinationURL
            self.assetWriter = writer
            self.videoInput = input
            self.pixelBufferAdaptor = adaptor
            self.recordingStartTime = nil
            self.pauseStartTime = nil
            self.totalPausedDuration = .zero
            self.isPaused = false
            self.isRecording = true
            self.stream = scStream
        }
        
        // Запуск потока ScreenCaptureKit с отказоустойчивым откатом при ошибке
        do {
            try scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: recordingQueue)
            try await scStream.startCapture()
        } catch {
            await cancelRecording()
            throw error
        }
    }
    
    /// Приостановка записи
    public func pauseRecording() {
        recordingQueue.async {
            guard self.isRecording, !self.isPaused else { return }
            self.isPaused = true
        }
    }
    
    /// Возобновление записи
    public func resumeRecording() {
        recordingQueue.async {
            guard self.isRecording, self.isPaused else { return }
            self.isPaused = false
        }
    }
    
    /// Остановка записи и сохранение файла
    public func stopRecording() async throws -> URL? {
        let activeStream: SCStream? = recordingQueue.sync {
            guard self.isRecording else { return nil }
            return self.stream
        }
        guard let scStream = activeStream else { return nil }
        
        try await scStream.stopCapture()
        
        let finalizeContext: (writer: AVAssetWriter?, url: URL?) = recordingQueue.sync {
            self.stream = nil
            self.isRecording = false
            self.isPaused = false
            let writer = self.assetWriter
            let input = self.videoInput
            let url = self.outputURL
            if self.recordingStartTime != nil {
                input?.markAsFinished()
            }
            self.assetWriter = nil
            self.videoInput = nil
            self.pixelBufferAdaptor = nil
            return (writer, url)
        }
        
        guard let writer = finalizeContext.writer else {
            return finalizeContext.url
        }
        
        let outputURL = finalizeContext.url
        // AVAssetWriter не Sendable; finishWriting вызывает completion на своей очереди после завершения.
        nonisolated(unsafe) let finishingWriter = writer
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL?, Error>) in
            finishingWriter.finishWriting {
                let status = finishingWriter.status
                let writerError = finishingWriter.error
                if status == .completed, let url = outputURL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: writerError ?? NSError(
                        domain: "ScreenRecorder",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Recording finalize failed"]
                    ))
                }
            }
        }
    }
    
    /// Отмена записи с удалением неполного файла
    public func cancelRecording() async {
        let activeStream: SCStream? = recordingQueue.sync {
            guard self.isRecording else { return nil }
            return self.stream
        }
        if let scStream = activeStream {
            try? await scStream.stopCapture()
        }
        
        let urlToRemove: URL? = recordingQueue.sync {
            self.stream = nil
            self.isRecording = false
            self.isPaused = false
            self.assetWriter?.cancelWriting()
            self.assetWriter = nil
            self.videoInput = nil
            self.pixelBufferAdaptor = nil
            let url = self.outputURL
            self.outputURL = nil
            return url
        }
        
        if let urlToRemove {
            try? FileManager.default.removeItem(at: urlToRemove)
        }
    }
    
    // MARK: - SCStreamOutput
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard isRecording, let writer = assetWriter, writer.status == .writing else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if isPaused {
            if pauseStartTime == nil {
                pauseStartTime = pts
            }
            return
        }
        
        if let pauseStart = pauseStartTime {
            let pauseDuration = CMTimeSubtract(pts, pauseStart)
            totalPausedDuration = CMTimeAdd(totalPausedDuration, pauseDuration)
            pauseStartTime = nil
        }
        
        let adjustedPts = CMTimeSubtract(pts, totalPausedDuration)
        
        if recordingStartTime == nil {
            recordingStartTime = adjustedPts
            writer.startSession(atSourceTime: adjustedPts)
        }
        
        if let input = videoInput, input.isReadyForMoreMediaData, let adaptor = pixelBufferAdaptor {
            if !adaptor.append(imageBuffer, withPresentationTime: adjustedPts) {
                if let err = writer.error {
                    print("ScreenRecorderService frame append error: \(err.localizedDescription)")
                }
            }
        }
    }
}
