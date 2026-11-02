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
        case kVK_Space:
            symbols.append(L("keystroke.space"))
        case kVK_Return:
            symbols.append(L("keystroke.return"))
        default:
            let keyLabel = ShortcutKey.keyName(
                for: UInt32(event.keyCode),
                fallback: event.charactersIgnoringModifiers ?? ""
            )
            if !keyLabel.isEmpty {
                symbols.append(keyLabel)
            }
        }
        
        guard !symbols.isEmpty else { return nil }
        return symbols.joined(separator: " ")
    }
}
