import SwiftUI
import AVKit
import Combine
import Observation

/// Модель состояния профессионального редактора видео
@Observable
@MainActor
public final class VideoEditorModel {
    public let videoURL: URL
    public let player: AVPlayer

    public var isPlaying: Bool = false
    public var currentTime: Double = 0.0
    public var duration: Double = 1.0

    // Обрезка (Trim In / Trim Out)
    public var trimStart: Double = 0.0
    public var trimEnd: Double = 1.0
    public var hasUserEditedTrim: Bool = false

    // Скорость воспроизведения (0.5x, 1x, 1.5x, 2x)
    public var playbackRate: Float = EditorPreferences.videoPlaybackRate {
        didSet { EditorPreferences.videoPlaybackRate = playbackRate }
    }

    // Кадрирование (Crop) и Умный Зум (Smart Zoom)
    public var isCropping: Bool = false
    public var cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1) // [0...1]
    public var isSmartZoomEnabled: Bool = false {
        didSet { updateCameraState() }
    }

    // Настройки умного зума (масштаб, режим слежения, отъезд при бездействии)
    public var smartZoomScale: SmartZoomScale = .balanced {
        didSet { updateCameraState() }
    }
    public var smartZoomMode: SmartZoomMode = .onClicks {
        didSet { updateCameraState() }
    }
    public var autoZoomOutOnIdle: Bool = true {
        didSet { updateCameraState() }
    }

    // Траектория курсора мыши и динамическая камера (Smart Zoom / Camera Follow)
    public var cursorTrack: CursorTrack
    public var currentCameraFocus: CGPoint = CGPoint(x: 0.5, y: 0.5)
    public var currentCameraZoom: CGFloat = 1.0

    // Аннотации
    public var annotations: [VideoAnnotationItem] = []
    public var selectedAnnotationID: UUID?

    // Экспорт
    public var isExporting: Bool = false
    public var exportProgress: Double = 0.0
    public var exportStatusText: String = ""

    // Превью-кадры таймлайна (thumbnails)
    public var thumbnails: [NSImage] = []

    // Истинный размер видео (пиксели)
    public var naturalSize: CGSize = .zero

    @ObservationIgnored private var timeObserverToken: Any?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private nonisolated(unsafe) var metadataTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var exportTask: Task<Void, Never>?

    public var hasCustomCrop: Bool {
        abs(cropRect.origin.x) > 0.002 ||
        abs(cropRect.origin.y) > 0.002 ||
        abs(cropRect.width - 1.0) > 0.002 ||
        abs(cropRect.height - 1.0) > 0.002
    }

    public var hasEdits: Bool {
        hasUserEditedTrim ||
        abs(playbackRate - 1.0) > 0.01 ||
        hasCustomCrop ||
        !annotations.isEmpty ||
        isSmartZoomEnabled
    }

    public init(videoURL: URL, cursorTrack: CursorTrack? = nil) {
        self.videoURL = videoURL
        let loaded = cursorTrack ?? CursorTrackRecorder.loadTrack(forVideoURL: videoURL) ?? CursorTrack()
        self.cursorTrack = loaded
        let playerItem = AVPlayerItem(url: videoURL)
        self.player = AVPlayer(playerItem: playerItem)

        setupPlayerObserver()
        loadVideoMetadata()
        updateCameraState()
    }

    deinit {
        metadataTask?.cancel()
        exportTask?.cancel()
    }

    public func currentExportOptions(gifFPS: Int = 15) -> VideoExportOptions {
        VideoExportOptions(
            trimStart: trimStart,
            trimEnd: trimEnd,
            playbackRate: playbackRate,
            cropRect: hasCustomCrop ? cropRect : nil,
            gifFPS: gifFPS,
            annotations: annotations,
            smartZoom: isSmartZoomEnabled,
            smartZoomScale: smartZoomScale,
            smartZoomMode: smartZoomMode,
            autoZoomOutOnIdle: autoZoomOutOnIdle,
            cursorTrack: cursorTrack
        )
    }

    public func updateCameraState() {
        let newFocus: CGPoint
        let newZoom: CGFloat
        if isSmartZoomEnabled {
            let state = cursorTrack.cameraState(
                at: currentTime,
                scale: smartZoomScale,
                mode: smartZoomMode,
                autoZoomOutOnIdle: autoZoomOutOnIdle
            )
            newFocus = state.focus
            newZoom = state.zoom
        } else {
            newFocus = CGPoint(x: 0.5, y: 0.5)
            newZoom = 1.0
        }

        if abs(currentCameraFocus.x - newFocus.x) > 0.0005 || abs(currentCameraFocus.y - newFocus.y) > 0.0005 {
            currentCameraFocus = newFocus
        }
        if abs(currentCameraZoom - newZoom) > 0.0005 {
            currentCameraZoom = newZoom
        }
    }

    public func videoContentRect(in containerSize: CGSize) -> CGRect {
        guard naturalSize.width > 0, naturalSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = min(containerSize.width / naturalSize.width, containerSize.height / naturalSize.height)
        let w = naturalSize.width * scale
        let h = naturalSize.height * scale
        let x = (containerSize.width - w) / 2
        let y = (containerSize.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    public func registerExportTask(_ task: Task<Void, Never>) {
        exportTask?.cancel()
        exportTask = task
    }

    public func clearExportTask() {
        exportTask = nil
    }

    public func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        isExporting = false
        exportProgress = 0.0
        exportStatusText = ""
    }

    public func cleanup() {
        metadataTask?.cancel()
        metadataTask = nil
        exportTask?.cancel()
        exportTask = nil
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        cancellables.removeAll()
        player.pause()
    }

    private func setupPlayerObserver() {
        let interval = CMTime(value: 1, timescale: 30)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                let sec = time.seconds
                guard sec.isFinite else { return }
                if abs(self.currentTime - sec) > 0.002 {
                    self.currentTime = sec
                    self.updateCameraState()
                }
                // Зацикливание внутри диапазона trimStart...trimEnd только во время воспроизведения
                if self.isPlaying && sec >= self.trimEnd {
                    self.seek(to: self.trimStart, exact: true)
                    self.player.play()
                    self.player.rate = self.playbackRate
                }
            }
        }

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.seek(to: self.trimStart, exact: true)
                if self.isPlaying {
                    self.player.play()
                    self.player.rate = self.playbackRate
                }
            }
            .store(in: &cancellables)
    }

    private func loadVideoMetadata() {
        metadataTask?.cancel()
        metadataTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let asset = AVURLAsset(url: self.videoURL)
            if let track = try? await asset.loadTracks(withMediaType: .video).first,
               let size = try? await track.load(.naturalSize) {
                let transform = (try? await track.load(.preferredTransform)) ?? .identity
                guard !Task.isCancelled else { return }
                self.naturalSize = VideoAnnotationBurnIn.displaySize(
                    naturalSize: size,
                    preferredTransform: transform
                )
            }
            if let dur = try? await asset.load(.duration).seconds, dur.isFinite, dur > 0 {
                guard !Task.isCancelled else { return }
                self.duration = dur
                if !self.hasUserEditedTrim {
                    self.trimEnd = dur
                } else {
                    self.trimEnd = min(dur, max(self.trimStart + 0.1, self.trimEnd))
                }
                await self.generateThumbnails(count: 10)
            }
        }
    }

    private func generateThumbnails(count: Int) async {
        let duration = self.duration
        let url = self.videoURL
        let thumbs: [NSImage] = await Task.detached(priority: .utility) {
            guard !Task.isCancelled else { return [] }
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 160, height: 100)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

            var times: [CMTime] = []
            for i in 0..<count {
                times.append(CMTime(seconds: (duration / Double(count)) * Double(i), preferredTimescale: 600))
            }

            var result: [NSImage] = []
            result.reserveCapacity(count)
            do {
                for try await imageResult in generator.images(for: times) {
                    if Task.isCancelled { break }
                    let cgImage = try imageResult.image
                    result.append(NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
                }
            } catch {
                // Частичный filmstrip допустим
            }
            return result
        }.value

        guard !Task.isCancelled else { return }
        self.thumbnails = thumbs
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        if currentTime >= trimEnd {
            seek(to: trimStart, exact: true)
        }
        player.play()
        player.rate = playbackRate
        isPlaying = true
    }

    public func pause() {
        player.pause()
        isPlaying = false
    }

    public func seek(to time: Double, exact: Bool = true) {
        let clamped = max(0, min(duration, time))
        currentTime = clamped
        updateCameraState()
        player.currentItem?.cancelPendingSeeks()
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        let tolerance = exact ? CMTime.zero : CMTime(seconds: 0.03, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
    }

    public func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player.rate = rate
        }
    }

    // Размытие конфиденциальных данных (Blur / Redact)
    public var hasBlurAnnotations: Bool {
        annotations.contains(where: { $0.type == .blur })
    }

    public func addAnnotation(type: VideoAnnotationType = .blur) {
        let offset = CGFloat(annotations.count % 5) * 0.035
        let rect = CGRect(
            x: min(0.65, 0.30 + offset),
            y: min(0.65, 0.30 + offset),
            width: 0.25,
            height: 0.16
        )
        let newItem = VideoAnnotationItem(type: .blur, rect: rect)
        annotations.append(newItem)
        selectedAnnotationID = newItem.id
    }

    public func updateAnnotation(_ item: VideoAnnotationItem) {
        if let idx = annotations.firstIndex(where: { $0.id == item.id }) {
            annotations[idx] = item
        }
    }

    public func removeAnnotation(id: UUID) {
        if selectedAnnotationID == id {
            selectedAnnotationID = nil
        }
        annotations.removeAll { $0.id == id }
    }
}
