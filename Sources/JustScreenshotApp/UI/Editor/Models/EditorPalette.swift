import SwiftUI
import AppKit

/// Палитра цветов редактора и стандартные толщины линий
public enum EditorPalette {
    public static let colors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .cyan, .blue, .indigo, .purple, .pink, .white, .gray, .black
    ]
    public static let widths: [CGFloat] = [1, 2, 3, 4, 6, 8, 12, 16]

    /// Сравнивает цвета по sRGB-компонентам, чтобы сохранённые цвета совпадали с системными семантическими
    @MainActor
    public static func colorsMatch(_ lhs: Color, _ rhs: Color, tolerance: CGFloat = 0.02) -> Bool {
        guard let c1 = rgbaComponents(for: lhs), let c2 = rgbaComponents(for: rhs) else {
            return lhs == rhs
        }
        return abs(c1.r - c2.r) <= tolerance
            && abs(c1.g - c2.g) <= tolerance
            && abs(c1.b - c2.b) <= tolerance
            && abs(c1.a - c2.a) <= tolerance
    }

    @MainActor
    private static func rgbaComponents(for color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        let ns = NSColor(color)
        guard let converted = ns.usingColorSpace(.sRGB) ?? ns.usingColorSpace(.deviceRGB) else {
            return nil
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}
