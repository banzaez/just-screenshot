import Foundation
import Cocoa

/// Модель полученного скриншота
public struct CapturedItem: Identifiable, Sendable {
    public let id: UUID
    public let image: NSImage
    public let timestamp: Date
    public let rect: CGRect
    public var customBackdropColor: String?
    
    public init(id: UUID = UUID(), image: NSImage, timestamp: Date = Date(), rect: CGRect, customBackdropColor: String? = nil) {
        self.id = id
        self.image = image
        self.timestamp = timestamp
        self.rect = rect
        self.customBackdropColor = customBackdropColor
    }
}

/// Статус записи экрана
public enum RecordingState: Sendable, Equatable {
    case idle
    case preparing
    case recording(duration: TimeInterval)
    case paused
    case finishing
}

/// Тип захвата
public enum CaptureMode: Sendable {
    case area
    case window
    case fullScreen
    case recordingArea
}
