import Foundation
import Carbon
import SwiftUI

/// Модель шортката клавиш для сохранения в UserDefaults и регистрации в Carbon
public struct ShortcutKey: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var keyChar: String
    public var modifiers: UInt32 // Carbon modifiers: cmdKey, shiftKey, optionKey, controlKey
    
    public init(keyCode: UInt32, keyChar: String = "", modifiers: UInt32 = UInt32(cmdKey | shiftKey)) {
        self.keyCode = keyCode
        let resolved = Self.keyName(for: keyCode, fallback: keyChar)
        self.keyChar = resolved
        self.modifiers = modifiers
    }
    
    /// Массив отдельных символов/названий клавиш для рендеринга бейджей (например: ["⌃", "⌥", "⇧", "⌘", "F5"] или ["⌘", "⇧", "Space"])
    public var keySymbols: [String] {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        let label = Self.keyName(for: keyCode, fallback: keyChar)
        if !label.isEmpty {
            parts.append(label)
        }
        return parts
    }
    
    public var displayString: String {
        keySymbols.joined(separator: " ")
    }
    
    /// Является ли клавиша функциональной (F1–F20).
    /// Важно: в Carbon коды kVK_F1..kVK_F20 идут НЕ по порядку (например kVK_F1 = 0x7A, а kVK_F5 = 0x60).
    public static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        switch Int(keyCode) {
        case kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
             kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
             kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18,
             kVK_F19, kVK_F20:
            return true
        default:
            return false
        }
    }
    
    /// Клавиши, которые можно назначать в качестве глобального хоткея даже без модификаторов (⌘/⌥/⌃)
    public static func canBeUsedWithoutModifiers(_ keyCode: UInt32) -> Bool {
        if isFunctionKey(keyCode) { return true }
        switch Int(keyCode) {
        case kVK_Help, kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown, kVK_ForwardDelete,
             kVK_ANSI_KeypadClear,
             kVK_ANSI_Keypad0, kVK_ANSI_Keypad1, kVK_ANSI_Keypad2, kVK_ANSI_Keypad3,
             kVK_ANSI_Keypad4, kVK_ANSI_Keypad5, kVK_ANSI_Keypad6, kVK_ANSI_Keypad7,
             kVK_ANSI_Keypad8, kVK_ANSI_Keypad9,
             kVK_ANSI_KeypadDecimal, kVK_ANSI_KeypadMultiply, kVK_ANSI_KeypadPlus,
             kVK_ANSI_KeypadDivide, kVK_ANSI_KeypadMinus, kVK_ANSI_KeypadEnter, kVK_ANSI_KeypadEquals:
            return true
        default:
            return false
        }
    }
    
    /// Возвращает точное, независимое от текущей раскладки название клавиши по виртуальному коду Carbon `keyCode`
    public static func keyName(for keyCode: UInt32, fallback: String = "") -> String {
        switch Int(keyCode) {
        // Функциональные клавиши F1–F20
        case kVK_F1:  return "F1"
        case kVK_F2:  return "F2"
        case kVK_F3:  return "F3"
        case kVK_F4:  return "F4"
        case kVK_F5:  return "F5"
        case kVK_F6:  return "F6"
        case kVK_F7:  return "F7"
        case kVK_F8:  return "F8"
        case kVK_F9:  return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
            
        // Специальные и навигационные клавиши
        case kVK_Space:         return "Space"
        case kVK_Return:        return "↩ Return"
        case kVK_Tab:           return "⇥ Tab"
        case kVK_Delete:        return "⌫ Delete"
        case kVK_ForwardDelete: return "⌦ Fwd Del"
        case kVK_Escape:        return "Esc"
        case kVK_LeftArrow:     return "←"
        case kVK_RightArrow:    return "→"
        case kVK_DownArrow:     return "↓"
        case kVK_UpArrow:       return "↑"
        case kVK_Home:          return "↖ Home"
        case kVK_End:           return "↘ End"
        case kVK_PageUp:        return "⇞ PgUp"
        case kVK_PageDown:      return "⇟ PgDn"
        case kVK_Help:          return "Ins / Help"
        case kVK_CapsLock:      return "⇪ Caps"
            
        // Цифровой блок (Numpad / Keypad)
        case kVK_ANSI_KeypadClear:    return "Num Clear"
        case kVK_ANSI_KeypadEnter:    return "⌤ Num Enter"
        case kVK_ANSI_KeypadDecimal:  return "Num ."
        case kVK_ANSI_KeypadMultiply: return "Num *"
        case kVK_ANSI_KeypadPlus:     return "Num +"
        case kVK_ANSI_KeypadDivide:   return "Num /"
        case kVK_ANSI_KeypadMinus:    return "Num −"
        case kVK_ANSI_KeypadEquals:   return "Num ="
        case kVK_ANSI_Keypad0:        return "Num 0"
        case kVK_ANSI_Keypad1:        return "Num 1"
        case kVK_ANSI_Keypad2:        return "Num 2"
        case kVK_ANSI_Keypad3:        return "Num 3"
        case kVK_ANSI_Keypad4:        return "Num 4"
        case kVK_ANSI_Keypad5:        return "Num 5"
        case kVK_ANSI_Keypad6:        return "Num 6"
        case kVK_ANSI_Keypad7:        return "Num 7"
        case kVK_ANSI_Keypad8:        return "Num 8"
        case kVK_ANSI_Keypad9:        return "Num 9"
            
        // Буквенные клавиши ANSI (A–Z)
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
            
        // Цифровой ряд (0–9)
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
            
        // Знаки препинания и дополнительные символьные клавиши
        case kVK_ANSI_Grave:        return "` ~"
        case kVK_ANSI_Minus:        return "−"
        case kVK_ANSI_Equal:        return "="
        case kVK_ANSI_LeftBracket:  return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash:    return "\\"
        case kVK_ANSI_Semicolon:    return ";"
        case kVK_ANSI_Quote:        return "'"
        case kVK_ANSI_Comma:        return ","
        case kVK_ANSI_Period:       return "."
        case kVK_ANSI_Slash:        return "/"
        case kVK_ISO_Section:       return "§"
        case kVK_JIS_Yen:           return "¥"
        case kVK_JIS_Underscore:    return "_"
            
        default:
            let cleaned = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            if let scalar = cleaned.unicodeScalars.first,
               scalar.value >= 32,
               scalar.value != 127,
               !(0xF700...0xF8FF).contains(scalar.value) {
                return cleaned.uppercased()
            }
            return "Key \(keyCode)"
        }
    }
    
    /// Список зарезервированных критических системных сочетаний macOS, которые нельзя переназначать
    public static func isProtectedSystemShortcut(keyCode: UInt32, modifiers: UInt32) -> Bool {
        let hasCmd = (modifiers & UInt32(cmdKey)) != 0
        let hasShift = (modifiers & UInt32(shiftKey)) != 0
        let hasOpt = (modifiers & UInt32(optionKey)) != 0
        let hasCtrl = (modifiers & UInt32(controlKey)) != 0
        
        // ⌘Q (Quit), ⌘W (Close), ⌘H (Hide), ⌘M (Minimize), ⌘Tab (App Switcher), ⌘Space (Spotlight)
        if hasCmd && !hasShift && !hasOpt && !hasCtrl {
            switch Int(keyCode) {
            case kVK_ANSI_Q: return true // ⌘Q
            case kVK_ANSI_W: return true // ⌘W
            case kVK_ANSI_H: return true // ⌘H
            case kVK_ANSI_M: return true // ⌘M
            case kVK_Space:  return true // ⌘Space
            case kVK_Tab:    return true // ⌘Tab
            default: break
            }
        }
        // ⌘⌥Esc (Force Quit)
        if hasCmd && hasOpt && Int(keyCode) == kVK_Escape {
            return true
        }
        return false
    }
}
