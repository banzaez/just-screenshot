import Foundation
import CoreGraphics
import AppKit

/// Ключевой кадр траектории курсора мыши во время записи видео
public struct CursorKeyframe: Codable, Sendable, Equatable {
    public let timestamp: Double
    /// Нормализованная координата (0...1 по X, 0...1 по Y, где 0,0 - верхний левый угол)
    public let point: CGPoint
    public let isClick: Bool
    
    public init(timestamp: Double, point: CGPoint, isClick: Bool = false) {
        self.timestamp = timestamp
        self.point = point
        self.isClick = isClick
    }
}

/// Масштаб приближения умного зума (Zoom Intensity)
public enum SmartZoomScale: Double, CaseIterable, Identifiable, Codable, Sendable {
    case subtle = 1.2
    case balanced = 1.35
    case closeup = 1.5
    
    public var id: Double { rawValue }
    
    public var title: String {
        switch self {
        case .subtle: return "1.2x"
        case .balanced: return "1.35x"
        case .closeup: return "1.5x"
        }
    }
}

/// Режим работы умного зума (Follow Mode)
public enum SmartZoomMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case onClicks = "on_clicks"
    case continuous = "continuous"
    
    public var id: String { rawValue }
}

/// Траектория движения мыши и событий кликов для умного автозума (Smart Zoom / Camera Follow)
public struct CursorTrack: Codable, Sendable {
    public var keyframes: [CursorKeyframe]
    
    public init(keyframes: [CursorKeyframe] = []) {
        self.keyframes = keyframes
    }
    
    /// Состояние камеры (точка фокуса 0...1 и масштаб) в момент времени `time` (в секундах)
    public func cameraState(
        at time: Double,
        scale: SmartZoomScale = .balanced,
        mode: SmartZoomMode = .onClicks,
        autoZoomOutOnIdle: Bool = true
    ) -> (focus: CGPoint, zoom: CGFloat) {
        let maxZoom = CGFloat(scale.rawValue)
        let restingZoom = max(1.0, 1.0 + (maxZoom - 1.0) * 0.65)
        
        guard !keyframes.isEmpty else {
            return (CGPoint(x: 0.5, y: 0.5), mode == .onClicks ? 1.0 : restingZoom)
        }
        
        // 1. Проверяем клик в диапазоне [-0.2s ... +1.6s]
        let clickEvents = keyframes.filter { $0.isClick }
        if let recentClick = clickEvents.last(where: { $0.timestamp <= time && (time - $0.timestamp) < 1.6 }) {
            let elapsed = time - recentClick.timestamp
            let startZoom: CGFloat = mode == .onClicks ? 1.0 : restingZoom
            let zoom: CGFloat
            if elapsed < 0.25 {
                zoom = startZoom + (maxZoom - startZoom) * CGFloat(elapsed / 0.25)
            } else if elapsed > 1.2 {
                zoom = maxZoom - (maxZoom - startZoom) * CGFloat((elapsed - 1.2) / 0.4)
            } else {
                zoom = maxZoom
            }
            return (recentClick.point, zoom)
        }
        
        // 2. Если режим - только по кликам, вне клика держим общий план 1.0x
        if mode == .onClicks {
            return (CGPoint(x: 0.5, y: 0.5), 1.0)
        }
        
        // 3. Режим постоянного слежения (continuous)
        let interpolatedPoint: CGPoint
        if time <= keyframes[0].timestamp {
            interpolatedPoint = keyframes[0].point
        } else if let last = keyframes.last, time >= last.timestamp {
            interpolatedPoint = last.point
        } else {
            var low = 0
            var high = keyframes.count - 1
            while low <= high {
                let mid = (low + high) / 2
                if keyframes[mid].timestamp < time {
                    low = mid + 1
                } else {
                    high = mid - 1
                }
            }
            let idx1 = min(max(0, low), keyframes.count - 1)
            let idx0 = max(0, idx1 - 1)
            let k0 = keyframes[idx0]
            let k1 = keyframes[idx1]
            let dt = k1.timestamp - k0.timestamp
            let factor = dt > 0.0001 ? CGFloat((time - k0.timestamp) / dt) : 0
            let clamped = min(1.0, max(0.0, factor))
            let smooth = clamped * clamped * (3 - 2 * clamped)
            let px = k0.point.x + (k1.point.x - k0.point.x) * smooth
            let py = k0.point.y + (k1.point.y - k0.point.y) * smooth
            interpolatedPoint = CGPoint(x: min(1.0, max(0.0, px)), y: min(1.0, max(0.0, py)))
        }
        
        // Проверка на бездействие: если курсор неподвижен > 2.0с, отъезжаем к 1.0x
        var zoom = restingZoom
        if autoZoomOutOnIdle {
            let recentTime = max(0, time - 2.0)
            if let recentPastKf = keyframes.last(where: { $0.timestamp <= recentTime }) {
                let dist = hypot(interpolatedPoint.x - recentPastKf.point.x, interpolatedPoint.y - recentPastKf.point.y)
                if dist < 0.02 {
                    zoom = 1.0
                }
            }
        }
        
        return (interpolatedPoint, zoom)
    }
}

/// Сервис непрерывной записи координат курсора и кликов во время активной видеозаписи
@MainActor
public final class CursorTrackRecorder {
    public static let shared = CursorTrackRecorder()
    
    private var recordingRect: CGRect = .zero
    private var startTime: Date?
    private var keyframes: [CursorKeyframe] = []
    private var sampleTimer: Timer?
    private var clickMonitor: Any?
    private var isRecording = false
    
    private init() {}
    
    /// Запуск сэмплирования курсора (30 Гц) и фиксации кликов мыши
    public func start(recordingRect: CGRect) {
        _ = stop()
        self.recordingRect = recordingRect
        self.startTime = Date()
        self.keyframes = []
        self.isRecording = true
        
        // Глобальный мониторинг кликов ЛКМ и ПКМ
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.recordPoint(isClick: true)
            }
        }
        
        // Сэмплирование позиции курсора
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recordPoint(isClick: false)
            }
        }
        
        // Запись нулевой точки
        recordPoint(isClick: false)
    }
    
    /// Остановка сэмплирования и возврат итогового трека
    @discardableResult
    public func stop() -> CursorTrack {
        sampleTimer?.invalidate()
        sampleTimer = nil
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        isRecording = false
        let track = CursorTrack(keyframes: keyframes)
        keyframes = []
        startTime = nil
        return track
    }
    
    private func recordPoint(isClick: Bool) {
        guard isRecording, let startTime else { return }
        guard recordingRect.width > 0, recordingRect.height > 0 else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let mouseLoc = NSEvent.mouseLocation
        
        // В AppKit y=0 находится снизу экрана, в видеокоординатах y=0 сверху
        let normX = (mouseLoc.x - recordingRect.origin.x) / recordingRect.width
        let normY = 1.0 - ((mouseLoc.y - recordingRect.origin.y) / recordingRect.height)
        
        let clampedX = min(1.0, max(0.0, normX))
        let clampedY = min(1.0, max(0.0, normY))
        
        keyframes.append(
            CursorKeyframe(
                timestamp: elapsed,
                point: CGPoint(x: clampedX, y: clampedY),
                isClick: isClick
            )
        )
    }
    
    /// Сохранение трека в сопутствующий файл (companion .track.json)
    public static func saveTrack(_ track: CursorTrack, forVideoURL videoURL: URL) {
        let trackURL = companionTrackURL(for: videoURL)
        do {
            let data = try JSONEncoder().encode(track)
            try data.write(to: trackURL, options: .atomic)
        } catch {
            print("Failed to save cursor track: \(error.localizedDescription)")
        }
    }
    
    /// Загрузка сопутствующего трека, если он существует на диске
    public static func loadTrack(forVideoURL videoURL: URL) -> CursorTrack? {
        let trackURL = companionTrackURL(for: videoURL)
        guard FileManager.default.fileExists(atPath: trackURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: trackURL)
            return try JSONDecoder().decode(CursorTrack.self, from: data)
        } catch {
            return nil
        }
    }
    
    private static func companionTrackURL(for videoURL: URL) -> URL {
        videoURL.deletingPathExtension().appendingPathExtension("track.json")
    }
}
