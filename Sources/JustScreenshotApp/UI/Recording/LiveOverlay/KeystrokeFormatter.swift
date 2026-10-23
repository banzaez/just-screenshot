import AppKit
import Carbon

/// Преобразование событий NSEvent в текстовые обозначения нажатых клавиш
@MainActor
enum KeystrokeFormatter {
    static func format(event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var symbols: [String] = []
        if flags.contains(.control) { symbols.append("⌃") }
        if flags.contains(.option) { symbols.append("⌥") }
        if flags.contains(.shift) { symbols.append("⇧") }
        if flags.contains(.command) { symbols.append("⌘") }
        
        if event.type == .flagsChanged {
            guard !symbols.isEmpty else { return nil }
            return symbols.joined(separator: " ")
        }
        
        switch Int(event.keyCode) {
        case kVK_Space: symbols.append(L("keystroke.space"))
        case kVK_Return: symbols.append(L("keystroke.return"))
        case kVK_Escape: symbols.append("Esc")
        case kVK_Delete: symbols.append("⌫")
        case kVK_ForwardDelete: symbols.append("⌦")
        case kVK_Tab: symbols.append("⇥")
        case kVK_LeftArrow: symbols.append("←")
        case kVK_RightArrow: symbols.append("→")
        case kVK_DownArrow: symbols.append("↓")
        case kVK_UpArrow: symbols.append("↑")
        case kVK_F1: symbols.append("F1")
        case kVK_F2: symbols.append("F2")
        case kVK_F3: symbols.append("F3")
        case kVK_F4: symbols.append("F4")
        case kVK_F5: symbols.append("F5")
        case kVK_F6: symbols.append("F6")
        case kVK_F7: symbols.append("F7")
        case kVK_F8: symbols.append("F8")
        case kVK_F9: symbols.append("F9")
        case kVK_F10: symbols.append("F10")
        case kVK_F11: symbols.append("F11")
        case kVK_F12: symbols.append("F12")
        default:
            if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
                let first = chars.uppercased()
                if let scalar = first.unicodeScalars.first, scalar.value >= 32 && scalar.value != 127 {
                    symbols.append(first)
                }
            }
        }
        
        guard !symbols.isEmpty else { return nil }
        return symbols.joined(separator: " ")
    }
}
