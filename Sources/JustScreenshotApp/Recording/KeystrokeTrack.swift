import Foundation
import AppKit
import CoreGraphics

/// Фильтр отображаемых нажатий клавиш
public enum KeystrokeDisplayFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "all"
    case shortcutsOnly = "shortcuts_only"

    public var id: String { rawValue }
}

/// Позиция бейджа нажатых клавиш поверх видео
public enum KeystrokePosition: String, CaseIterable, Identifiable, Codable, Sendable {
    case bottomCenter = "bottom_center"
    case bottomLeft = "bottom_left"
    case bottomRight = "bottom_right"
    case topCenter = "top_center"

    public var id: String { rawValue }

    /// Автоматически сдвигает бейдж на противоположный край, только если Smart Zoom сфокусирован прямо на области плашки
    nonisolated public func resolved(cameraFocus: CGPoint, cameraZoom: CGFloat) -> KeystrokePosition {
        guard cameraZoom > 1.05 else { return self }
        switch self {
        case .bottomCenter:
            return (cameraFocus.y > 0.82 && abs(cameraFocus.x - 0.5) < 0.25) ? .topCenter : self
        case .bottomLeft:
            return (cameraFocus.y > 0.82 && cameraFocus.x < 0.35) ? .topCenter : self
        case .bottomRight:
            return (cameraFocus.y > 0.82 && cameraFocus.x > 0.65) ? .topCenter : self
        case .topCenter:
            return (cameraFocus.y < 0.18 && abs(cameraFocus.x - 0.5) < 0.25) ? .bottomCenter : self
        }
    }
}

/// Размер бейджа нажатых клавиш
public enum KeystrokeSize: Double, CaseIterable, Identifiable, Codable, Sendable {
    case compact = 0.85
    case standard = 1.0
    case large = 1.25

    public var id: Double { rawValue }
}

/// Активный красный эффект ввода текста в позиции курсора
public struct ActiveTypingEffect: Equatable, Sendable {
    public let point: CGPoint
    public let progress: CGFloat
}

/// Записанное событие нажатия клавиши/комбинации во время видеозаписи
public struct KeystrokeEvent: Codable, Sendable, Equatable {
    public let timestamp: Double
    public let text: String

    public init(timestamp: Double, text: String) {
        self.timestamp = timestamp
        self.text = text
    }

    public var isShortcut: Bool {
        text.contains("⌘") || text.contains("⌥") || text.contains("⌃") || text.contains("⇧")
    }
}

/// Трек нажатых клавиш и шорткатов для постпроцессинга в видеоредакторе
public struct KeystrokeTrack: Codable, Sendable, Equatable {
    public var events: [KeystrokeEvent] {
        didSet {
            shortcutEvents = events.filter(\.isShortcut)
        }
    }

    /// Предвычисленный индекс шорткатов для O(log N) поиска без аллокаций на каждый кадр
    private var shortcutEvents: [KeystrokeEvent]

    private enum CodingKeys: String, CodingKey {
        case events
    }

    public init(events: [KeystrokeEvent] = []) {
        self.events = events
        self.shortcutEvents = events.filter(\.isShortcut)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try container.decode([KeystrokeEvent].self, forKey: .events)
        self.events = decoded
        self.shortcutEvents = decoded.filter(\.isShortcut)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(events, forKey: .events)
    }

    /// Временные метки нажатых клавиш с учётом фильтра (для маркеров на таймлайне)
    public func timestamps(filter: KeystrokeDisplayFilter = .all) -> [Double] {
        let source = filter == .shortcutsOnly ? shortcutEvents : events
        return source.map(\.timestamp)
    }

    /// Активный бейдж клавиш и его прозрачность в момент времени `time` (в секундах)
    nonisolated public func activeKeystroke(
        at time: Double,
        filter: KeystrokeDisplayFilter = .all,
        displayDuration: Double = 1.4,
        fadeDuration: Double = 0.4
    ) -> (text: String, alpha: CGFloat)? {
        let filtered = filter == .shortcutsOnly ? shortcutEvents : events
        guard !filtered.isEmpty, filtered[0].timestamp <= time else { return nil }
        var low = 0
        var high = filtered.count - 1
        var best = 0
        while low <= high {
            let mid = (low + high) / 2
            if filtered[mid].timestamp <= time {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        let event = filtered[best]
        let age = time - event.timestamp
        guard age >= 0, age <= displayDuration else { return nil }

        let fadeStart = max(0, displayDuration - fadeDuration)
        let alpha: CGFloat
        if age < fadeStart {
            alpha = 1.0
        } else {
            let progress = (age - fadeStart) / max(0.001, fadeDuration)
            alpha = CGFloat(max(0.0, 1.0 - progress))
        }
        return alpha > 0.001 ? (event.text, alpha) : nil
    }

    /// Активные красные индикаторы ввода текста в позиции курсора в момент времени `time`
    nonisolated public func activeTypingEffects(
        at time: Double,
        cursorTrack: CursorTrack,
        duration: Double = 0.45
    ) -> [ActiveTypingEffect] {
        guard !events.isEmpty, duration > 0, events[0].timestamp <= time else { return [] }
        var low = 0
        var high = events.count - 1
        var best = 0
        while low <= high {
            let mid = (low + high) / 2
            if events[mid].timestamp <= time {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        var result: [ActiveTypingEffect] = []
        var idx = best
        while idx >= 0 {
            let ev = events[idx]
            let age = time - ev.timestamp
            if age > duration {
                break
            }
            if age >= 0, !ev.isShortcut {
                let progress = CGFloat(min(1.0, max(0.0, age / duration)))
                let point = cursorTrack.cursorPoint(at: ev.timestamp)
                result.append(ActiveTypingEffect(point: point, progress: progress))
            }
            idx -= 1
        }
        return result
    }
}

/// Сервис записи нажатий клавиш и комбинаций синхронно с видеозаписью (без отрисовки поверх экрана)
@MainActor
public final class KeystrokeTrackRecorder {
    public static let shared = KeystrokeTrackRecorder()

    private var startUptime: TimeInterval?
    private var pauseStartUptime: TimeInterval?
    private var totalPausedDuration: TimeInterval = 0
    private var events: [KeystrokeEvent] = []
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var isRecording = false
    private var isPaused = false

    private init() {}

    public func start() {
        _ = stop()
        self.startUptime = ProcessInfo.processInfo.systemUptime
        self.pauseStartUptime = nil
        self.totalPausedDuration = 0
        self.events = []
        self.isRecording = true
        self.isPaused = false

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.record(event: event)
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.record(event: event)
            }
            return event
        }
    }

    public func pause() {
        guard isRecording, !isPaused else { return }
        isPaused = true
        pauseStartUptime = ProcessInfo.processInfo.systemUptime
    }

    public func resume() {
        guard isRecording, isPaused else { return }
        if let pauseStart = pauseStartUptime {
            totalPausedDuration += max(0, ProcessInfo.processInfo.systemUptime - pauseStart)
            pauseStartUptime = nil
        }
        isPaused = false
    }

    @discardableResult
    public func stop() -> KeystrokeTrack {
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        isRecording = false
        isPaused = false
        pauseStartUptime = nil
        totalPausedDuration = 0
        let track = KeystrokeTrack(events: events)
        events = []
        startUptime = nil
        return track
    }

    private func record(event: NSEvent) {
        guard isRecording, !isPaused, let startUptime else { return }
        guard let text = KeystrokeFormatter.format(event: event) else { return }

        let rawElapsed = max(0, ProcessInfo.processInfo.systemUptime - startUptime - totalPausedDuration)
        let elapsed = max(events.last?.timestamp ?? 0, rawElapsed)
        events.append(KeystrokeEvent(timestamp: elapsed, text: text))
    }

    public static func saveTrack(_ track: KeystrokeTrack, forVideoURL videoURL: URL) {
        guard !track.events.isEmpty else { return }
        let trackURL = companionTrackURL(for: videoURL)
        do {
            let data = try JSONEncoder().encode(track)
            try data.write(to: trackURL, options: .atomic)
        } catch {
            AppLogger.recording.error("Failed to save keystroke track: \(error.localizedDescription, privacy: .public)")
        }
    }

    public static func loadTrack(forVideoURL videoURL: URL) -> KeystrokeTrack? {
        let trackURL = companionTrackURL(for: videoURL)
        guard FileManager.default.fileExists(atPath: trackURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: trackURL)
            return try JSONDecoder().decode(KeystrokeTrack.self, from: data)
        } catch {
            return nil
        }
    }

    public static func companionTrackURL(for videoURL: URL) -> URL {
        videoURL.deletingPathExtension().appendingPathExtension("keys.json")
    }
}
