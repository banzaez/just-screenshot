import SwiftUI

/// Инструменты аннотаций Just Screenshot
public enum AnnotationTool: String, CaseIterable, Identifiable, Sendable {
    case select = "Выбор / Перемещение"
    case arrow = "Стрелка"
    case rectangle = "Прямоугольник"
    case roundedRect = "Скругленный"
    case ellipse = "Овал"
    case text = "Текст"
    case counter = "Счетчик (1-2-3)"
    case blur = "Размытие"
    case highlighter = "Маркер"
    case magnifier = "Лупа"
    
    public var id: String { rawValue }
    
    /// Стабильный ключ для UserDefaults (не зависит от локализованного rawValue)
    public var storageKey: String {
        switch self {
        case .select: return "select"
        case .arrow: return "arrow"
        case .rectangle: return "rectangle"
        case .roundedRect: return "roundedRect"
        case .ellipse: return "ellipse"
        case .text: return "text"
        case .counter: return "counter"
        case .blur: return "blur"
        case .highlighter: return "highlighter"
        case .magnifier: return "magnifier"
        }
    }
    
    public static func from(storageKey: String) -> AnnotationTool? {
        allCases.first { $0.storageKey == storageKey }
    }
    
    /// Группы для тулбара
    public static let selectGroup: [AnnotationTool] = [.select]
    public static let shapesGroup: [AnnotationTool] = [.arrow, .rectangle, .roundedRect, .ellipse]
    public static let annotateGroup: [AnnotationTool] = [.text, .counter, .highlighter]
    public static let redactGroup: [AnnotationTool] = [.blur, .magnifier]
    
    public var iconName: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "square"
        case .roundedRect: return "square.dashed"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .counter: return "1.circle.fill"
        case .blur: return "checkerboard.rectangle"
        case .highlighter: return "highlighter"
        case .magnifier: return "plus.magnifyingglass"
        }
    }
    
    @MainActor
    public var localizedTitle: String {
        switch self {
        case .select: return L("editor.tool.select")
        case .arrow: return L("editor.tool.arrow")
        case .rectangle: return L("editor.tool.rectangle")
        case .roundedRect: return L("editor.tool.rounded_rect")
        case .ellipse: return L("editor.tool.ellipse")
        case .text: return L("editor.tool.text")
        case .counter: return L("editor.tool.counter")
        case .blur: return L("editor.tool.blur")
        case .highlighter: return L("editor.tool.highlighter")
        case .magnifier: return L("editor.tool.magnifier")
        }
    }
}
