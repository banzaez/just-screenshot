import Foundation

/// Режимы работы оверлея
public enum OverlayMode: Sendable {
    case windowOnly      // Режим захвата только окна (подсветка + клик)
    case areaOnly        // Режим произвольного размера (drag to select)
    case recordingArea   // Режим выбора области для видеозаписи
}
