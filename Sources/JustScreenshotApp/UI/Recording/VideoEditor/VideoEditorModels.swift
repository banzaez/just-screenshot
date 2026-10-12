import SwiftUI
import AVFoundation

public enum VideoAnnotationType: String, CaseIterable, Identifiable, Sendable {
    case text = "Текст"
    case arrow = "Стрелка"
    case rect = "Рамка"
    case blur = "Размытие"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .text: return "textformat"
        case .arrow: return "arrow.up.right"
        case .rect: return "rectangle"
        case .blur: return "eye.slash"
        }
    }
    
    @MainActor
    public var localizedTitle: String {
        switch self {
        case .text: return L("video_editor.type_text")
        case .arrow: return L("video_editor.type_arrow")
        case .rect: return L("video_editor.type_rect")
        case .blur: return L("video_editor.type_blur")
        }
    }
}

public struct VideoAnnotationItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var type: VideoAnnotationType
    public var rect: CGRect // В нормализованных координатах [0...1] от размера видео
    public var text: String
    public var color: Color
    public var lineWidth: CGFloat
    
    public init(
        id: UUID = UUID(),
        type: VideoAnnotationType = .rect,
        rect: CGRect = CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.2),
        text: String = "Текст",
        color: Color = .red,
        lineWidth: CGFloat = 3
    ) {
        self.id = id
        self.type = type
        self.rect = rect
        self.text = text
        self.color = color
        self.lineWidth = lineWidth
    }
}
