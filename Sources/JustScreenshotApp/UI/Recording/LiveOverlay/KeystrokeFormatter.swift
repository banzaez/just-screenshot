import AppKit
import Carbon

/// Преобразование событий NSEvent в текстовые обозначения нажатых клавиш
@MainActor
enum KeystrokeFormatter {
    private static var previousModifiers: NSEvent.ModifierFlags = []

    static func format(event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        var symbols: [String] = []
        if flags.contains(.control) { symbols.append("⌃") }
        if flags.contains(.option) { symbols.append("⌥") }
        if flags.contains(.shift) { symbols.append("⇧") }
        if flags.contains(.command) { symbols.append("⌘") }

        if event.type == .flagsChanged {
            let added = flags.subtracting(previousModifiers)
            previousModifiers = flags
            // Отпускание модификатора после аккорда не должно затирать бейдж сочетания клавиш
            guard !added.isEmpty, !symbols.isEmpty else { return nil }
            return symbols.joined(separator: " ")
        }

        previousModifiers = flags

        switch Int(event.keyCode) {
        case kVK_Space:
            symbols.append(L("keystroke.space"))
        case kVK_Return:
            symbols.append(L("keystroke.return"))
        default:
            let keyLabel = resolveKeyLabel(for: event, flags: flags)
            if !keyLabel.isEmpty {
                symbols.append(keyLabel)
            }
        }

        guard !symbols.isEmpty else { return nil }
        return symbols.joined(separator: " ")
    }

    private static func resolveKeyLabel(for event: NSEvent, flags: NSEvent.ModifierFlags) -> String {
        let keyCode = UInt32(event.keyCode)
        if isNonLayoutKey(keyCode) {
            return ShortcutKey.keyName(for: keyCode, fallback: event.charactersIgnoringModifiers ?? "")
        }

        let preferredChars: String?
        if flags.contains(.control) || flags.contains(.option) {
            preferredChars = event.charactersIgnoringModifiers ?? event.characters
        } else {
            preferredChars = event.characters ?? event.charactersIgnoringModifiers
        }

        if let localized = printableKeyLabel(from: preferredChars) {
            return localized
        }

        if let fallback = printableKeyLabel(from: event.charactersIgnoringModifiers) {
            return fallback
        }

        return ShortcutKey.keyName(for: keyCode, fallback: "")
    }

    private static func printableKeyLabel(from raw: String?) -> String? {
        guard let raw else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let scalar = cleaned.unicodeScalars.first,
              scalar.value >= 32,
              scalar.value != 127,
              !(0xF700...0xF8FF).contains(scalar.value) else {
            return nil
        }
        return cleaned.uppercased()
    }

    private static func isNonLayoutKey(_ keyCode: UInt32) -> Bool {
        if ShortcutKey.canBeUsedWithoutModifiers(keyCode) {
            return true
        }
        switch Int(keyCode) {
        case kVK_Tab, kVK_Delete, kVK_Escape,
             kVK_LeftArrow, kVK_RightArrow, kVK_DownArrow, kVK_UpArrow:
            return true
        default:
            return false
        }
    }
}
