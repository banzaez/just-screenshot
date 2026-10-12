import Foundation

/// Статус сессии записи экрана
public enum RecordingState: Sendable, Equatable {
    case idle
    case preparing
    case recording(duration: TimeInterval)
    case paused
    case finishing
}
