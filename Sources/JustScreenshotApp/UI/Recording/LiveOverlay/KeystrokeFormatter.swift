import AppKit

/// Преобразование событий NSEvent в текстовые обозначения нажатых клавиш (например, "⌘ ⇧ S", "Esc")
@MainActor
enum KeystrokeFormatter {
    static func format(event: NSEvent) -> String? {
        var symbols: [String] = []
        let flags = event.modifierFlags
        if flags.contains(.control) { symbols.append("⌃") }
        if flags.contains(.option) { symbols.append("⌥") }
        if flags.contains(.shift) { symbols.append("⇧") }
        if flags.contains(.command) { symbols.append("⌘") }
        
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            let first = chars.uppercased()
            switch event.keyCode {
            case 49: symbols.append("Space")
            case 36: symbols.append("Return")
            case 53: symbols.append("Esc")
            case 51: symbols.append("⌫")
            case 123: symbols.append("←")
            case 124: symbols.append("→")
            case 125: symbols.append("↓")
            case 126: symbols.append("↑")
            default:
                if !symbols.isEmpty || chars.count == 1 {
                    symbols.append(first)
                }
            }
        }
        
        guard !symbols.isEmpty else { return nil }
        return symbols.joined(separator: " ")
    }
}
