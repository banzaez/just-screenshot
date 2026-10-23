import Foundation
import ScreenCaptureKit

/// Стабильные title окон приложения для исключения из ScreenCaptureKit
enum JustScreenshotWindowTitles {
    static let areaOverlay = "JustScreenshotAreaOverlay"
    static let countdownOverlay = "JustScreenshotCountdownOverlay"
    static let recordingFrame = "JustScreenshotRecordingFrame"
    static let recordingBar = "JustScreenshotRecordingBar"
    static let recordingEffects = "JustScreenshotRecordingEffects"
    
    static let allOverlayTitles: Set<String> = [
        areaOverlay,
        countdownOverlay,
        recordingFrame,
        recordingBar
    ]
    
    static func isOverlayTitle(_ title: String?) -> Bool {
        guard let title else { return false }
        return allOverlayTitles.contains(title)
    }
    
    /// Окно нашего процесса, которое не должно попадать в захват/запись
    nonisolated static func shouldExcludeFromCapture(_ window: SCWindow, currentPID: pid_t? = nil) -> Bool {
        let pid = currentPID ?? ProcessInfo.processInfo.processIdentifier
        guard window.owningApplication?.processID == pid else { return false }
        if window.title == recordingEffects {
            return false
        }
        return isOverlayTitle(window.title) || window.windowLayer >= 1000
    }
}
