import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreGraphics
import Cocoa

public enum ScreenRecorderError: LocalizedError, Sendable {
    case recordingAlreadyStarting
    case displayNotFound
    case failedToAddVideoInput
    case failedToStartWriting
    case zeroFramesCaptured
    case finalizeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .recordingAlreadyStarting:
            return "Screen recording is already starting."
        case .displayNotFound:
            return "Display not found."
        case .failedToAddVideoInput:
            return "Failed to attach video writer input."
        case .failedToStartWriting:
            return "Failed to start AVAssetWriter."
        case .zeroFramesCaptured:
            return "No video frames were captured."
        case .finalizeFailed(let message):
            return message
        }
    }
}

/// Сервис записи выбранной области экрана через ScreenCaptureKit Stream + AVAssetWriter
public final class ScreenRecorderService: NSObject, @unchecked Sendable, SCStreamOutput, SCStreamDelegate {
    public static let shared = ScreenRecorderService()

    private let recordingQueue = DispatchQueue(label: "com.justscreenshot.recorder.queue")

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var isStarting = false
    private var isRecording = false
    private var isPaused = false
    private var outputURL: URL?
    private var recordingStartTime: CMTime?
    private var pauseStartTime: CMTime?
    private var lastAppendedPTS: CMTime?
    private var appendedFrameCount = 0
    private var totalPausedDuration: CMTime = .zero
    private var _onUnexpectedStop: (@Sendable (Error) -> Void)?

    public var onUnexpectedStop: (@Sendable (Error) -> Void)? {
        get { recordingQueue.sync { _onUnexpectedStop } }
        set { recordingQueue.sync { _onUnexpectedStop = newValue } }
    }

    public override init() {
        super.init()
    }

    /// Запуск записи выбранной области экрана
    public func startRecording(rect: CGRect, destinationURL: URL) async throws {
        enum StartGate {
            case busy
            case needsCancelFirst
            case ready
        }

        let gate: StartGate = recordingQueue.sync {
            if self.isStarting { return .busy }
            if self.isRecording { return .needsCancelFirst }
            self.isStarting = true
            return .ready
        }

        switch gate {
        case .busy:
            throw ScreenRecorderError.recordingAlreadyStarting
        case .needsCancelFirst:
            await cancelRecording()
            let canProceed: Bool = recordingQueue.sync {
                guard !self.isStarting, !self.isRecording else { return false }
                self.isStarting = true
                return true
            }
            guard canProceed else {
                throw ScreenRecorderError.recordingAlreadyStarting
            }
        case .ready:
            break
        }

        var didHandOffToStream = false
        defer {
            if !didHandOffToStream {
                recordingQueue.sync {
                    self.isStarting = false
                }
            }
        }

        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let display = ScreenCaptureService.matchingDisplay(in: content, for: rect) else {
            throw ScreenRecorderError.displayNotFound
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let excludedWindows = content.windows.filter {
            JustScreenshotWindowTitles.shouldExcludeFromCapture($0, currentPID: currentPID)
        }
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

        // Преобразуем глобальные координаты в локальные координаты выбранного монитора и ограничиваем его границами
        let rawLocalRect = CGRect(
            x: rect.origin.x - CGFloat(display.frame.origin.x),
            y: rect.origin.y - CGFloat(display.frame.origin.y),
            width: rect.width,
            height: rect.height
        )
        let displayBounds = CGRect(origin: .zero, size: display.frame.size)
        let clamped = rawLocalRect.intersection(displayBounds)
        let localRect = (!clamped.isNull && clamped.width >= 2 && clamped.height >= 2) ? clamped : rawLocalRect

        let scale = ScreenCaptureService.displayScale(for: display, fallback: 2.0)
        let config = SCStreamConfiguration()
        config.sourceRect = localRect
        let targetWidth = max(2, Int(round(localRect.width * scale)))
        let targetHeight = max(2, Int(round(localRect.height * scale)))
        // Размеры должны быть четными и >= 2 для H.264
        config.width = targetWidth % 2 == 0 ? targetWidth : targetWidth + 1
        config.height = targetHeight % 2 == 0 ? targetHeight : targetHeight + 1
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA

        // Настройка AVAssetWriter
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mp4)
        let pixelCount = config.width * config.height
        let averageBitRate = min(40_000_000, max(4_000_000, pixelCount * 6))
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.width,
            AVVideoHeightKey: config.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: averageBitRate,
                AVVideoExpectedSourceFrameRateKey: 60
            ]
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

        guard writer.canAdd(input) else {
            throw ScreenRecorderError.failedToAddVideoInput
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? ScreenRecorderError.failedToStartWriting
        }

        let scStream = SCStream(filter: filter, configuration: config, delegate: self)

        recordingQueue.sync {
            self.outputURL = destinationURL
            self.assetWriter = writer
            self.videoInput = input
            self.pixelBufferAdaptor = adaptor
            self.recordingStartTime = nil
            self.pauseStartTime = nil
            self.lastAppendedPTS = nil
            self.appendedFrameCount = 0
            self.totalPausedDuration = .zero
            self.isPaused = false
            self.isRecording = true
            self.isStarting = false
            self.stream = scStream
        }
        didHandOffToStream = true

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
            self.pauseStartTime = CMClockGetTime(CMClockGetHostTimeClock())
        }
    }

    /// Возобновление записи
    public func resumeRecording() {
        recordingQueue.async {
            guard self.isRecording, self.isPaused else { return }
            if let pauseStart = self.pauseStartTime {
                let now = CMClockGetTime(CMClockGetHostTimeClock())
                let delta = CMTimeSubtract(now, pauseStart)
                if CMTimeCompare(delta, .zero) > 0 {
                    self.totalPausedDuration = CMTimeAdd(self.totalPausedDuration, delta)
                }
                self.pauseStartTime = nil
            }
            self.isPaused = false
        }
    }

    /// Остановка записи и сохранение файла
    public func stopRecording() async throws -> URL? {
        let activeStream: SCStream? = recordingQueue.sync {
            guard self.isRecording else { return nil }
            self.isRecording = false
            self.isPaused = false
            let current = self.stream
            self.stream = nil
            return current
        }
        guard let scStream = activeStream else { return nil }

        do {
            try await scStream.stopCapture()
        } catch {
            let urlToRemove = cleanupWriterAndState(cancelWriter: true)
            if let urlToRemove {
                try? FileManager.default.removeItem(at: urlToRemove)
            }
            throw error
        }

        let finalizeContext: (writer: AVAssetWriter?, url: URL?, frameCount: Int) = recordingQueue.sync {
            let writer = self.assetWriter
            let input = self.videoInput
            let url = self.outputURL
            let frameCount = self.appendedFrameCount
            if frameCount > 0 {
                input?.markAsFinished()
            } else {
                writer?.cancelWriting()
            }
            self.assetWriter = nil
            self.videoInput = nil
            self.pixelBufferAdaptor = nil
            self.outputURL = nil
            self.recordingStartTime = nil
            self.pauseStartTime = nil
            self.lastAppendedPTS = nil
            self.appendedFrameCount = 0
            self.totalPausedDuration = .zero
            return (writer, url, frameCount)
        }

        guard finalizeContext.frameCount > 0 else {
            if let url = finalizeContext.url {
                try? FileManager.default.removeItem(at: url)
            }
            throw ScreenRecorderError.zeroFramesCaptured
        }

        guard let writer = finalizeContext.writer else {
            return finalizeContext.url
        }

        let outputURL = finalizeContext.url
        nonisolated(unsafe) let finishingWriter = writer
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL?, Error>) in
            finishingWriter.finishWriting {
                let status = finishingWriter.status
                let writerError = finishingWriter.error
                if status == .completed, let url = outputURL {
                    continuation.resume(returning: url)
                } else {
                    if let outputURL {
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                    continuation.resume(throwing: writerError ?? ScreenRecorderError.finalizeFailed("Recording finalize failed"))
                }
            }
        }
    }

    /// Отмена записи с удалением неполного файла
    public func cancelRecording() async {
        let activeStream: SCStream? = recordingQueue.sync {
            guard self.isRecording else { return nil }
            self.isRecording = false
            self.isPaused = false
            let current = self.stream
            self.stream = nil
            return current
        }
        if let scStream = activeStream {
            try? await scStream.stopCapture()
        }

        if let urlToRemove = cleanupWriterAndState(cancelWriter: true) {
            try? FileManager.default.removeItem(at: urlToRemove)
        }
    }

    @discardableResult
    private func cleanupWriterAndState(cancelWriter: Bool) -> URL? {
        recordingQueue.sync {
            if cancelWriter {
                self.assetWriter?.cancelWriting()
            }
            self.assetWriter = nil
            self.videoInput = nil
            self.pixelBufferAdaptor = nil
            self.recordingStartTime = nil
            self.pauseStartTime = nil
            self.lastAppendedPTS = nil
            self.appendedFrameCount = 0
            self.totalPausedDuration = .zero
            self.isRecording = false
            self.isPaused = false
            self.isStarting = false
            self.stream = nil
            let url = self.outputURL
            self.outputURL = nil
            return url
        }
    }

    // MARK: - SCStreamDelegate

    public func stream(_ stream: SCStream, didStopWithError error: any Error) {
        nonisolated(unsafe) let stoppedStream = stream
        recordingQueue.async {
            guard self.stream === stoppedStream else { return }
            self.stream = nil
            self.isRecording = false
            self.isPaused = false
            self.isStarting = false
            self.assetWriter?.cancelWriting()
            self.assetWriter = nil
            self.videoInput = nil
            self.pixelBufferAdaptor = nil
            self.recordingStartTime = nil
            self.pauseStartTime = nil
            self.lastAppendedPTS = nil
            self.appendedFrameCount = 0
            self.totalPausedDuration = .zero
            let url = self.outputURL
            self.outputURL = nil
            let handler = self._onUnexpectedStop

            if let url {
                try? FileManager.default.removeItem(at: url)
            }
            AppLogger.recording.error("ScreenRecorderService stream stopped with error: \(error.localizedDescription, privacy: .public)")
            handler?(error)
        }
    }

    // MARK: - SCStreamOutput

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard isRecording, !isPaused, let writer = assetWriter, writer.status == .writing else { return }

        // Игнорируем неполные/пустые системные буферы (idle / suspended / blank)
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[String: Any]],
           let statusRaw = attachments.first?[SCStreamFrameInfo.status.rawValue] as? Int,
           let status = SCFrameStatus(rawValue: statusRaw),
           status != .complete {
            return
        }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let adjustedPts = CMTimeSubtract(pts, totalPausedDuration)

        if let lastPTS = lastAppendedPTS, CMTimeCompare(adjustedPts, lastPTS) <= 0 {
            return
        }

        if recordingStartTime == nil {
            recordingStartTime = adjustedPts
            writer.startSession(atSourceTime: adjustedPts)
        }

        if let input = videoInput, input.isReadyForMoreMediaData, let adaptor = pixelBufferAdaptor {
            if adaptor.append(imageBuffer, withPresentationTime: adjustedPts) {
                lastAppendedPTS = adjustedPts
                appendedFrameCount += 1
            } else if let err = writer.error {
                AppLogger.recording.error("ScreenRecorderService frame append error: \(err.localizedDescription, privacy: .public)")
            }
        }
    }
}
