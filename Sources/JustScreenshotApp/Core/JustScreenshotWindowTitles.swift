import Foundation

/// Стабильные title окон приложения для исключения из ScreenCaptureKit
enum JustScreenshotWindowTitles {
    static let areaOverlay = "JustScreenshotAreaOverlay"
    static let countdownOverlay = "JustScreenshotCountdownOverlay"
    static let recordingFrame = "JustScreenshotRecordingFrame"
    static let recordingBar = "JustScreenshotRecordingBar"
    
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
}
