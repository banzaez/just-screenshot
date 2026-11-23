import SwiftUI

/// Визуальный стиль размытия для скрытия данных на видео
public enum VideoBlurStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case frostedGlass = "frosted_glass"
    case darkGlass = "dark_glass"
    case gaussian = "gaussian"
    case pixelate = "pixelate"

    public var id: String { rawValue }
}

/// Плотность (интенсивность) размытия
public enum VideoBlurIntensity: Double, CaseIterable, Identifiable, Codable, Sendable {
    case light = 0.6
    case medium = 1.0
    case heavy = 1.55
    case ultra = 2.2

    public var id: Double { rawValue }
}

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
        type: VideoAnnotationType = .blur,
        rect: CGRect? = nil,
        text: String = "",
        color: Color = .clear,
        lineWidth: CGFloat = 1,
        fontSize: CGFloat = 14,
        rotationAngle: Double = 0
    ) {
        self.id = id
        self.type = type
        self.rect = rect ?? CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.2)
        self.text = text
        self.color = color
        self.lineWidth = lineWidth
        self.fontSize = fontSize
        self.rotationAngle = rotationAngle
    }
}
