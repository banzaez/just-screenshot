import Foundation
import CoreGraphics
import AppKit

/// Ключевой кадр траектории курсора мыши во время записи видео
public struct CursorKeyframe: Codable, Sendable, Equatable {
    public let timestamp: Double
    /// Нормализованная координата (0...1 по X, 0...1 по Y, где 0,0 - верхний левый угол)
    public let point: CGPoint
    public let isClick: Bool
    public let isRightClick: Bool
    
    public init(timestamp: Double, point: CGPoint, isClick: Bool = false, isRightClick: Bool = false) {
        self.timestamp = timestamp
        self.point = point
        self.isClick = isClick
        self.isRightClick = isRightClick
    }
}

/// Активная анимация клика мыши для постпроцессинга
public struct ActiveClickRipple: Equatable, Sendable {
    public let point: CGPoint
    public let progress: CGFloat
    public let isRightClick: Bool
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
    public var keyframes: [CursorKeyframe] {
        didSet {
            clickKeyframes = keyframes.filter(\.isClick)
        }
    }
    
    /// Предвычисленный индекс кликов для O(log N) поиска без аллокаций на каждый кадр
    private var clickKeyframes: [CursorKeyframe]

    /// Временные метки всех кликов (для отображения маркеров на таймлайне)
    public var clickTimestamps: [Double] {
        clickKeyframes.map(\.timestamp)
    }
    
    private enum CodingKeys: String, CodingKey {
        case keyframes
    }
    
    public init(keyframes: [CursorKeyframe] = []) {
        self.keyframes = keyframes
        self.clickKeyframes = keyframes.filter(\.isClick)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try container.decode([CursorKeyframe].self, forKey: .keyframes)
        self.keyframes = decoded
        self.clickKeyframes = decoded.filter(\.isClick)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyframes, forKey: .keyframes)
    }
    
    /// Бинарный поиск индекса последнего ключевого кадра с `timestamp <= targetTime` за O(log N)
    private static func lastKeyframeIndex(in list: [CursorKeyframe], atOrBefore targetTime: Double) -> Int? {
        guard !list.isEmpty, list[0].timestamp <= targetTime else { return nil }
        var low = 0
        var high = list.count - 1
        var best = 0
        while low <= high {
            let mid = (low + high) / 2
            if list[mid].timestamp <= targetTime {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return best
    }
    
    private static func smoothstep(_ t: CGFloat) -> CGFloat {
        let c = min(1.0, max(0.0, t))
        return c * c * (3.0 - 2.0 * c)
    }

    /// Непрерывная интерполированная позиция курсора в момент `time`
    nonisolated public func cursorPoint(at time: Double) -> CGPoint {
        continuousPoint(at: time)
    }

    /// Непрерывная интерполированная позиция курсора в момент `time`
    nonisolated private func continuousPoint(at time: Double) -> CGPoint {
        guard !keyframes.isEmpty else { return CGPoint(x: 0.5, y: 0.5) }
        if time <= keyframes[0].timestamp {
            return keyframes[0].point
        }
        if let last = keyframes.last, time >= last.timestamp {
            return last.point
        }

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
        let smooth = Self.smoothstep(factor)
        let px = k0.point.x + (k1.point.x - k0.point.x) * smooth
        let py = k0.point.y + (k1.point.y - k0.point.y) * smooth
        return CGPoint(x: min(1.0, max(0.0, px)), y: min(1.0, max(0.0, py)))
    }

    /// Проверяет непрерывность удержания курсора рядом с `currentPoint` и плавно возвращает масштаб для `continuous`
    private func continuousIdleAdjustedZoom(
        at time: Double,
        currentPoint: CGPoint,
        restingZoom: CGFloat,
        autoZoomOutOnIdle: Bool
    ) -> CGFloat {
        guard autoZoomOutOnIdle, !keyframes.isEmpty else { return restingZoom }

        // Бинарный поиск последнего ключевого кадра <= time
        guard keyframes[0].timestamp <= time else { return restingZoom }
        var low = 0
        var high = keyframes.count - 1
        var lastIdx = 0
        while low <= high {
            let mid = (low + high) / 2
            if keyframes[mid].timestamp <= time {
                lastIdx = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        // Сканируем назад, пока все кадры лежат в радиусе < 0.02 от текущей позиции
        var stationaryStartIdx = lastIdx
        while stationaryStartIdx > 0 {
            let prev = keyframes[stationaryStartIdx - 1]
            let dist = hypot(currentPoint.x - prev.point.x, currentPoint.y - prev.point.y)
            if dist >= 0.02 {
                break
            }
            stationaryStartIdx -= 1
        }

        let currentDist = hypot(currentPoint.x - keyframes[lastIdx].point.x, currentPoint.y - keyframes[lastIdx].point.y)
        guard currentDist < 0.02 else { return restingZoom }

        let stationaryDuration = time - keyframes[stationaryStartIdx].timestamp
        guard stationaryDuration >= 2.0 else { return restingZoom }

        let fadeProgress = Self.smoothstep(CGFloat((stationaryDuration - 2.0) / 0.4))
        return restingZoom - (restingZoom - 1.0) * fadeProgress
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
        
        // 1. Базовая траектория вне активного клика
        let baseFocus: CGPoint
        let baseZoom: CGFloat
        if mode == .onClicks {
            baseFocus = CGPoint(x: 0.5, y: 0.5)
            baseZoom = 1.0
        } else {
            let point = continuousPoint(at: time)
            baseFocus = point
            baseZoom = continuousIdleAdjustedZoom(
                at: time,
                currentPoint: point,
                restingZoom: restingZoom,
                autoZoomOutOnIdle: autoZoomOutOnIdle
            )
        }
        
        // 2. Плавный вход/выход клика без резких скачков фокуса (0...1.6с)
        if let clickIdx = Self.lastKeyframeIndex(in: clickKeyframes, atOrBefore: time) {
            let recentClick = clickKeyframes[clickIdx]
            let elapsed = time - recentClick.timestamp
            if elapsed < 1.6 {
                if elapsed < 0.25 {
                    // Если предыдущий клик ещё не завершился, плавно переходим из его состояния вместо сброса в baseFocus
                    var startFocus = baseFocus
                    var startZoom = baseZoom
                    if clickIdx > 0 {
                        let prevClick = clickKeyframes[clickIdx - 1]
                        let gap = recentClick.timestamp - prevClick.timestamp
                        if gap < 1.6 {
                            if gap < 0.25 {
                                let pw = Self.smoothstep(CGFloat(gap / 0.25))
                                startFocus = CGPoint(
                                    x: baseFocus.x + (prevClick.point.x - baseFocus.x) * pw,
                                    y: baseFocus.y + (prevClick.point.y - baseFocus.y) * pw
                                )
                                startZoom = baseZoom + (maxZoom - baseZoom) * pw
                            } else if gap > 1.2 {
                                let pw = Self.smoothstep(CGFloat((gap - 1.2) / 0.4))
                                startFocus = CGPoint(
                                    x: prevClick.point.x + (baseFocus.x - prevClick.point.x) * pw,
                                    y: prevClick.point.y + (baseFocus.y - prevClick.point.y) * pw
                                )
                                startZoom = maxZoom + (baseZoom - maxZoom) * pw
                            } else {
                                startFocus = prevClick.point
                                startZoom = maxZoom
                            }
                        }
                    }

                    let w = Self.smoothstep(CGFloat(elapsed / 0.25))
                    let fx = startFocus.x + (recentClick.point.x - startFocus.x) * w
                    let fy = startFocus.y + (recentClick.point.y - startFocus.y) * w
                    let zoom = startZoom + (maxZoom - startZoom) * w
                    return (CGPoint(x: fx, y: fy), zoom)
                } else if elapsed > 1.2 {
                    let w = Self.smoothstep(CGFloat((elapsed - 1.2) / 0.4))
                    let fx = recentClick.point.x + (baseFocus.x - recentClick.point.x) * w
                    let fy = recentClick.point.y + (baseFocus.y - recentClick.point.y) * w
                    let zoom = maxZoom + (baseZoom - maxZoom) * w
                    return (CGPoint(x: fx, y: fy), zoom)
                } else {
                    return (recentClick.point, maxZoom)
                }
            }
        }
        
        return (baseFocus, baseZoom)
    }

    /// Активные анимации кликов мыши в момент времени `time` (для постпроцессинга)
    nonisolated public func activeClickRipples(at time: Double, duration: Double = 0.45) -> [ActiveClickRipple] {
        guard !clickKeyframes.isEmpty, duration > 0 else { return [] }
        guard let lastIdx = Self.lastKeyframeIndex(in: clickKeyframes, atOrBefore: time) else { return [] }

        var result: [ActiveClickRipple] = []
        var idx = lastIdx
        while idx >= 0 {
            let kf = clickKeyframes[idx]
            let age = time - kf.timestamp
            if age > duration {
                break
            }
            if age >= 0 {
                let progress = CGFloat(min(1.0, max(0.0, age / duration)))
                result.append(ActiveClickRipple(point: kf.point, progress: progress, isRightClick: kf.isRightClick))
            }
            idx -= 1
        }
        return result
    }
}

/// Сервис непрерывной записи координат курсора и кликов во время активной видеозаписи
@MainActor
public final class CursorTrackRecorder {
    public static let shared = CursorTrackRecorder()
    
    private var recordingRect: CGRect = .zero
    private var startUptime: TimeInterval?
    private var pauseStartUptime: TimeInterval?
    private var totalPausedDuration: TimeInterval = 0
    private var keyframes: [CursorKeyframe] = []
    private var sampleTimer: Timer?
    private var clickMonitor: Any?
    private var isRecording = false
    private var isPaused = false
    
    private init() {}
    
    /// Запуск сэмплирования курсора (30 Гц) и фиксации кликов мыши
    public func start(recordingRect: CGRect) {
        _ = stop()
        self.recordingRect = recordingRect
        self.startUptime = ProcessInfo.processInfo.systemUptime
        self.pauseStartUptime = nil
        self.totalPausedDuration = 0
        self.keyframes = []
        self.isRecording = true
        self.isPaused = false
        
        // Глобальный мониторинг кликов ЛКМ и ПКМ
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let isRight = event.type == .rightMouseDown
            Task { @MainActor [weak self] in
                self?.recordPoint(isClick: true, isRightClick: isRight)
            }
        }
        
        // Сэмплирование позиции курсора (scheduledTimer уже выполняется на main runloop)
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.recordPoint(isClick: false)
            }
        }
        
        // Запись нулевой точки
        recordPoint(isClick: false)
    }
    
    /// Приостановка записи трека курсора синхронно с паузой видеозаписи
    public func pause() {
        guard isRecording, !isPaused else { return }
        isPaused = true
        pauseStartUptime = ProcessInfo.processInfo.systemUptime
    }
    
    /// Возобновление записи трека курсора
    public func resume() {
        guard isRecording, isPaused else { return }
        if let pauseStart = pauseStartUptime {
            totalPausedDuration += max(0, ProcessInfo.processInfo.systemUptime - pauseStart)
            pauseStartUptime = nil
        }
        isPaused = false
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
        isPaused = false
        pauseStartUptime = nil
        totalPausedDuration = 0
        let track = CursorTrack(keyframes: keyframes)
        keyframes = []
        startUptime = nil
        return track
    }
    
    private func recordPoint(isClick: Bool, isRightClick: Bool = false) {
        guard isRecording, !isPaused, let startUptime else { return }
        guard recordingRect.width > 0, recordingRect.height > 0 else { return }
        
        let mouseLoc = NSEvent.mouseLocation
        // Внешние клики за пределами области записи игнорируются, чтобы не сбивать Smart Zoom
        if isClick, !recordingRect.contains(mouseLoc) {
            return
        }
        
        let rawElapsed = max(0, ProcessInfo.processInfo.systemUptime - startUptime - totalPausedDuration)
        let elapsed = max(keyframes.last?.timestamp ?? 0, rawElapsed)
        
        // В AppKit y=0 находится снизу экрана, в видеокоординатах y=0 сверху
        let normX = (mouseLoc.x - recordingRect.origin.x) / recordingRect.width
        let normY = 1.0 - ((mouseLoc.y - recordingRect.origin.y) / recordingRect.height)
        
        let clampedX = min(1.0, max(0.0, normX))
        let clampedY = min(1.0, max(0.0, normY))
        let newPoint = CGPoint(x: clampedX, y: clampedY)
        
        // Дедупликация покоя: если две последние точки не были кликами и совпадают с текущей,
        // обновляем timestamp последней точки вместо раздувания массива (сохраняя начало и конец паузы)
        if !isClick, keyframes.count >= 2 {
            let last = keyframes[keyframes.count - 1]
            let prev = keyframes[keyframes.count - 2]
            if !last.isClick && !prev.isClick {
                let dLast = hypot(newPoint.x - last.point.x, newPoint.y - last.point.y)
                let dPrev = hypot(last.point.x - prev.point.x, last.point.y - prev.point.y)
                if dLast < 0.0005 && dPrev < 0.0005 {
                    keyframes[keyframes.count - 1] = CursorKeyframe(timestamp: elapsed, point: newPoint, isClick: false)
                    return
                }
            }
        }
        
        keyframes.append(
            CursorKeyframe(
                timestamp: elapsed,
                point: newPoint,
                isClick: isClick,
                isRightClick: isRightClick
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
            AppLogger.recording.error("Failed to save cursor track: \(error.localizedDescription, privacy: .public)")
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
    
    public static func companionTrackURL(for videoURL: URL) -> URL {
        videoURL.deletingPathExtension().appendingPathExtension("track.json")
    }
}
