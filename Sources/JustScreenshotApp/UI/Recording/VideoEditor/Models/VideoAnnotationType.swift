import SwiftUI

/// Типы аннотаций в видеоредакторе (для видео оставлено только защитное размытие конфиденциальных данных)
public enum VideoAnnotationType: String, CaseIterable, Identifiable, Sendable {
    case blur = "Размытие"
    
    public var id: String { rawValue }
    
    public var icon: String { "eye.slash" }
    
    @MainActor
    public var localizedTitle: String {
        L("video_editor.type_blur")
    }
}
