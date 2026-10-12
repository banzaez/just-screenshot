import SwiftUI

/// Пресеты "красивого фона"
public enum BackdropPreset: String, CaseIterable, Identifiable, Sendable {
    case aurora = "Аврора"
    case ocean = "Океан"
    case sunset = "Закат"
    case forest = "Лес"
    case graphite = "Графит"
    case snow = "Снег"
    
    public var id: String { rawValue }
    
    public var colors: [Color] {
        switch self {
        case .aurora: return [Color(red: 0.36, green: 0.28, blue: 0.95), Color(red: 0.75, green: 0.30, blue: 0.85)]
        case .ocean: return [Color(red: 0.10, green: 0.45, blue: 0.95), Color(red: 0.20, green: 0.85, blue: 0.90)]
        case .sunset: return [Color(red: 1.0, green: 0.55, blue: 0.20), Color(red: 0.95, green: 0.25, blue: 0.55)]
        case .forest: return [Color(red: 0.07, green: 0.50, blue: 0.40), Color(red: 0.55, green: 0.85, blue: 0.45)]
        case .graphite: return [Color(white: 0.18), Color(white: 0.38)]
        case .snow: return [Color(white: 0.92), Color(red: 0.80, green: 0.86, blue: 0.97)]
        }
    }
    
    public var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
