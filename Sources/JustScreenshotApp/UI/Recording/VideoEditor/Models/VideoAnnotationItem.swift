import SwiftUI

/// Элемент наложения поверх видео
public struct VideoAnnotationItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var type: VideoAnnotationType
    public var rect: CGRect // В нормализованных координатах [0...1] от размера видео
    public var text: String
    public var color: Color
    public var lineWidth: CGFloat
    public var fontSize: CGFloat
    public var rotationAngle: Double // В градусах (-180...180)
    
    public init(
        id: UUID = UUID(),
        type: VideoAnnotationType = .rect,
        rect: CGRect? = nil,
        text: String = "Текст",
        color: Color = .red,
        lineWidth: CGFloat = 3,
        fontSize: CGFloat = 20,
        rotationAngle: Double = 0
    ) {
        self.id = id
        self.type = type
        if let rect = rect {
            self.rect = rect
        } else {
            switch type {
            case .text:
                self.rect = CGRect(x: 0.35, y: 0.45, width: 0.3, height: 0.08)
            case .arrow:
                self.rect = CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.2)
            case .rect:
                self.rect = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.3)
            case .blur:
                self.rect = CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.2)
            }
        }
        self.text = text
        self.color = color
        self.lineWidth = lineWidth
        self.fontSize = fontSize
        self.rotationAngle = rotationAngle
    }
}
