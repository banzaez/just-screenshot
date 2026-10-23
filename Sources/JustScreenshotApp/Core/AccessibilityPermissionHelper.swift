import Cocoa
import ApplicationServices

/// Помощник проверки и запроса системного разрешения «Универсальный доступ» (Accessibility).
/// Данное разрешение необходимо в macOS для глобального перехвата нажатий клавиш (NSEvent.addGlobalMonitorForEvents).
@MainActor
public enum AccessibilityPermissionHelper {
    public static var isGranted: Bool {
        AXIsProcessTrusted()
    }
    
    @discardableResult
    public static func requestAccess() -> Bool {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
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
