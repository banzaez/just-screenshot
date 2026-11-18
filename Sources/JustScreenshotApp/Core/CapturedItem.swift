import Foundation
import Cocoa

/// Модель полученного скриншота
public struct CapturedItem: Identifiable, Sendable {
    public let id: UUID
    public let image: NSImage
    public let timestamp: Date
    public let rect: CGRect
    
    public init(id: UUID = UUID(), image: NSImage, timestamp: Date = Date(), rect: CGRect) {
        self.id = id
        self.image = image
        self.timestamp = timestamp
        self.rect = rect
    }
}
