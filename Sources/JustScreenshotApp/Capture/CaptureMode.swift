import Foundation

/// Тип захвата экрана
public enum CaptureMode: Sendable {
    case area
    case window
    case fullScreen
    case recordingArea
}
