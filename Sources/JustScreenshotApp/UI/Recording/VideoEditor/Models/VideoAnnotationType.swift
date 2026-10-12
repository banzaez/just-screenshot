import SwiftUI

/// Типы аннотаций в видеоредакторе
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
