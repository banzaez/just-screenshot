import Foundation
import os

/// Централизованный структурированный логгер приложения на базе os.Logger
enum AppLogger {
    private static let subsystem = "com.justscreenshot.app"

    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let recording = Logger(subsystem: subsystem, category: "recording")
    static let export = Logger(subsystem: subsystem, category: "export")
    static let history = Logger(subsystem: subsystem, category: "history")
    static let hotkeys = Logger(subsystem: subsystem, category: "hotkeys")
    static let updater = Logger(subsystem: subsystem, category: "updater")
    static let general = Logger(subsystem: subsystem, category: "general")
}
