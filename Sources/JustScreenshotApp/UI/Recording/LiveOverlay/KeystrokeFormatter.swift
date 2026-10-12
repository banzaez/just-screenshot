import AppKit
import Carbon

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
            switch Int(event.keyCode) {
            case kVK_Space: symbols.append("Space")
            case kVK_Return: symbols.append("Return")
            case kVK_Escape: symbols.append("Esc")
            case kVK_Delete: symbols.append("⌫")
            case kVK_LeftArrow: symbols.append("←")
            case kVK_RightArrow: symbols.append("→")
            case kVK_DownArrow: symbols.append("↓")
            case kVK_UpArrow: symbols.append("↑")
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
