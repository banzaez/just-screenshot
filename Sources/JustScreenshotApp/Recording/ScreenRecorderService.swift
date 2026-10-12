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
        self.outputURL = destinationURL
        
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "ScreenRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Экран не найден"])
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
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
        
        self.assetWriter = writer
        self.videoInput = input
        self.pixelBufferAdaptor = adaptor
        self.recordingStartTime = nil
        self.pauseStartTime = nil
        self.totalPausedDuration = .zero
        self.isPaused = false
        self.isRecording = true
        
        // Запуск потока ScreenCaptureKit
        let scStream = SCStream(filter: filter, configuration: config, delegate: self)
        try scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: recordingQueue)
        try await scStream.startCapture()
        self.stream = scStream
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
        guard isRecording, let scStream = stream else { return nil }
        
        try await scStream.stopCapture()
        self.stream = nil
        self.isRecording = false
        self.isPaused = false
        
        guard let writer = self.assetWriter, let input = self.videoInput else {
            return self.outputURL
        }
        
        input.markAsFinished()
        
        return await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume(returning: self.outputURL)
            }
        }
    }
    
    /// Отмена записи с удалением неполного файла
    public func cancelRecording() async {
        guard isRecording, let scStream = stream else { return }
        
        try? await scStream.stopCapture()
        self.stream = nil
        self.isRecording = false
        self.isPaused = false
        
        self.assetWriter?.cancelWriting()
        self.assetWriter = nil
        self.videoInput = nil
        self.pixelBufferAdaptor = nil
        
        if let outputURL = self.outputURL {
            try? FileManager.default.removeItem(at: outputURL)
            self.outputURL = nil
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
            adaptor.append(imageBuffer, withPresentationTime: adjustedPts)
        }
    }
}
