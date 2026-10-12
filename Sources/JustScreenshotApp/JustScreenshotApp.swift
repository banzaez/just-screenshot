import SwiftUI
import AppKit

@main
struct JustScreenshotApp: App {
    @StateObject private var windowManager = AppWindowManager.shared
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    @StateObject private var localization = LocalizationManager.shared
    
    var body: some Scene {
        MenuBarExtra("Just Screenshot", systemImage: windowManager.isRecording ? "record.circle.fill" : "camera.viewfinder") {
            VStack(alignment: .leading, spacing: 4) {
                if windowManager.isRecording {
                    HStack {
                        Circle().fill(windowManager.isRecordingPaused ? Color.orange : Color.red).frame(width: 8, height: 8)
                        Text(windowManager.isRecordingPaused ? L("menu.recording_paused", Int(windowManager.recordingDuration)) : L("menu.recording_active", Int(windowManager.recordingDuration)))
                            .font(.headline)
                    }
                    
                    Button(windowManager.isRecordingPaused ? L("menu.resume_recording") : L("menu.pause_recording")) {
                        windowManager.togglePauseResumeScreenRecording()
                    }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    
                    Button(L("menu.stop_save_recording")) {
                        windowManager.stopScreenRecording()
                    }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    
                    Button(L("menu.cancel_recording")) {
                        windowManager.cancelScreenRecording()
                    }
                    
                    Divider()
                } else {
                    Button {
                        windowManager.startScreenRecording()
                    } label: {
                        Label(L("menu.record_screen"), systemImage: "record.circle")
                    }
                    .keyboardShortcut("3", modifiers: [.command, .shift])
                    
                    Button {
                        windowManager.startWindowCapture()
                    } label: {
                        Label(L("menu.capture_window"), systemImage: "macwindow")
                    }
                    .keyboardShortcut("4", modifiers: [.command, .shift])
                    
                    Button {
                        windowManager.startAreaCapture()
                    } label: {
                        Label(L("menu.capture_area"), systemImage: "crop")
                    }
                    .keyboardShortcut("5", modifiers: [.command, .shift])
                    
                    Button {
                        windowManager.repeatLastCapture()
                    } label: {
                        Label(L("menu.repeat_capture"), systemImage: "arrow.counterclockwise")
                    }
                    .keyboardShortcut("5", modifiers: [.command, .option])
                    
                    Menu {
                        Button(L("menu.delay_3s")) {
                            windowManager.startAreaCapture(delaySeconds: 3)
                        }
                        Button(L("menu.delay_5s")) {
                            windowManager.startAreaCapture(delaySeconds: 5)
                        }
                        Button(L("menu.delay_10s")) {
                            windowManager.startAreaCapture(delaySeconds: 10)
                        }
                    } label: {
                        Label(L("menu.timed_screenshot"), systemImage: "timer")
                    }
                    
                    Divider()
                }
                
                Button {
                    windowManager.showHistory()
                } label: {
                    Label(L("menu.history"), systemImage: "clock.arrow.circlepath")
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                
                Button {
                    windowManager.openImageFromDisk()
                } label: {
                    Label(L("menu.open_image"), systemImage: "photo")
                }
                
                Button {
                    windowManager.openImageFromClipboard()
                } label: {
                    Label(L("menu.edit_clipboard"), systemImage: "doc.on.clipboard")
                }
                
                Divider()
                
                Button {
                    windowManager.showSettings()
                } label: {
                    Label(L("menu.settings"), systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: [.command])
                
                Button(L("menu.check_permissions")) {
                    Task {
                        _ = await ScreenCaptureService.shared.checkAndRequestPermissions()
                    }
                }
                
                Divider()
                
                Button(L("menu.quit")) {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }
    }
}
