import SwiftUI
import AVKit
import Combine

/// Модель состояния профессионального редактора видео
@MainActor
public final class VideoEditorModel: ObservableObject {
    public let videoURL: URL
    public let player: AVPlayer
    
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 1.0
    
    // Обрезка (Trim In / Trim Out)
    @Published public var trimStart: Double = 0.0
    @Published public var trimEnd: Double = 1.0
    
    // Скорость воспроизведения (0.5x, 1x, 1.5x, 2x)
    @Published public var playbackRate: Float = 1.0
    
    // Кадрирование (Crop)
    @Published public var isCropping: Bool = false
    @Published public var cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1) // [0...1]
    
    // Аннотации
    @Published public var annotations: [VideoAnnotationItem] = []
    @Published public var selectedAnnotationID: UUID?
    
    // Экспорт
    @Published public var isExporting: Bool = false
    @Published public var exportProgress: Double = 0.0
    @Published public var exportStatusText: String = ""
    
    // Превью-кадры таймлайна (thumbnails)
    @Published public var thumbnails: [NSImage] = []
    
    // Истинный размер видео (пиксели)
    @Published public var naturalSize: CGSize = .zero
    
    private var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    
    public init(videoURL: URL) {
        self.videoURL = videoURL
        let playerItem = AVPlayerItem(url: videoURL)
        self.player = AVPlayer(playerItem: playerItem)
        
        setupPlayerObserver()
        loadVideoMetadata()
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
    
    public func cleanup() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player.pause()
    }
    
    private func setupPlayerObserver() {
        let interval = CMTime(value: 1, timescale: 30)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let sec = time.seconds
                if !sec.isNaN {
                    self.currentTime = sec
                    // Зацикливание внутри диапазона trimStart...trimEnd
                    if sec >= self.trimEnd {
                        self.seek(to: self.trimStart)
                        if self.isPlaying {
                            self.player.play()
                            self.player.rate = self.playbackRate
                        }
                    }
                }
            }
        }
        
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.seek(to: self.trimStart)
                if self.isPlaying {
                    self.player.play()
                    self.player.rate = self.playbackRate
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadVideoMetadata() {
        Task {
            let asset = AVURLAsset(url: videoURL)
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                if let size = try? await track.load(.naturalSize) {
                    let transform = (try? await track.load(.preferredTransform)) ?? .identity
                    let isRotated = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
                    let actualSize = isRotated ? CGSize(width: size.height, height: size.width) : size
                    await MainActor.run {
                        self.naturalSize = actualSize
                    }
                }
            }
            if let dur = try? await asset.load(.duration).seconds, dur > 0 {
                await MainActor.run {
                    self.duration = dur
                    self.trimEnd = dur
                }
                await self.generateThumbnails(count: 10)
            }
        }
    }
    
    private func generateThumbnails(count: Int) async {
        let duration = self.duration
        let url = self.videoURL
        let thumbs: [NSImage] = await Task.detached(priority: .utility) {
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
                    let cgImage = try imageResult.image
                    result.append(NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
                }
            } catch {
                // Частичный filmstrip лучше, чем пустой
            }
            return result
        }.value
        
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
            seek(to: trimStart)
        }
        player.play()
        player.rate = playbackRate
        isPlaying = true
    }
    
    public func pause() {
        player.pause()
        isPlaying = false
    }
    
    public func seek(to time: Double) {
        let clamped = max(0, min(duration, time))
        currentTime = clamped
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    public func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player.rate = rate
        }
    }
    
    // Аннотации
    public func addAnnotation(type: VideoAnnotationType) {
        let text = type == .text ? L("video_editor.type_text") : ""
        let newItem = VideoAnnotationItem(type: type, text: text)
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
    
    public func duplicateAnnotation(id: UUID) {
        guard let item = annotations.first(where: { $0.id == id }) else { return }
        let copy = item
        let newID = UUID()
        // Смещаем немного вправо-вниз
        let offset: CGFloat = 0.03
        var newRect = copy.rect
        newRect.origin.x = min(0.9, newRect.origin.x + offset)
        newRect.origin.y = min(0.9, newRect.origin.y + offset)
        
        let duplicated = VideoAnnotationItem(
            id: newID,
            type: copy.type,
            rect: newRect,
            text: copy.text,
            color: copy.color,
            lineWidth: copy.lineWidth,
            fontSize: copy.fontSize,
            rotationAngle: copy.rotationAngle
        )
        annotations.append(duplicated)
        selectedAnnotationID = duplicated.id
    }
}
