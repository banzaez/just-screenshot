import Cocoa
import ApplicationServices

/// Помощник проверки и запроса системного разрешения «Универсальный доступ» (Accessibility).
@MainActor
public enum AccessibilityPermissionHelper {
    public static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public static func requestAccess(openSettings: Bool = false) -> Bool {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted && openSettings {
            openSystemSettings()
        }
        return trusted
    }

    public static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
