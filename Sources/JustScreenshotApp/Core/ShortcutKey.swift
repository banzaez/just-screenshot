import Foundation
import Carbon

/// Модель шортката клавиш для сохранения в UserDefaults и регистрации в Carbon
public struct ShortcutKey: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var keyChar: String
    public var modifiers: UInt32 // Carbon modifiers: cmdKey, shiftKey, etc.
    
    public init(keyCode: UInt32, keyChar: String, modifiers: UInt32 = UInt32(cmdKey | shiftKey)) {
        self.keyCode = keyCode
        self.keyChar = keyChar
        self.modifiers = modifiers
    }
    
    public var keySymbols: [String] {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if !keyChar.isEmpty {
            parts.append(keyChar.uppercased())
        }
        return parts
    }
    
    public var displayString: String {
        keySymbols.joined()
    }
    
    /// Список зарезервированных критических системных сочетаний macOS, которые нельзя переназначать
    public static func isProtectedSystemShortcut(keyCode: UInt32, modifiers: UInt32) -> Bool {
        let hasCmd = (modifiers & UInt32(cmdKey)) != 0
        let hasShift = (modifiers & UInt32(shiftKey)) != 0
        let hasOpt = (modifiers & UInt32(optionKey)) != 0
        let hasCtrl = (modifiers & UInt32(controlKey)) != 0
        
        // ⌘Q (Quit), ⌘W (Close), ⌘H (Hide), ⌘M (Minimize), ⌘Tab (App Switcher), ⌘Space (Spotlight)
        if hasCmd && !hasShift && !hasOpt && !hasCtrl {
            switch keyCode {
            case UInt32(kVK_ANSI_Q): return true // ⌘Q
            case UInt32(kVK_ANSI_W): return true // ⌘W
            case UInt32(kVK_ANSI_H): return true // ⌘H
            case UInt32(kVK_ANSI_M): return true // ⌘M
            case UInt32(kVK_Space): return true  // ⌘Space
            case UInt32(kVK_Tab): return true    // ⌘Tab
            default: break
            }
        }
        // ⌘⌥Esc (Force Quit)
        if hasCmd && hasOpt && keyCode == UInt32(kVK_Escape) {
            return true
        }
        return false
    }
}
