import SwiftUI
import AppKit

@main
struct JustScreenshotApp: App {
    private var windowManager = AppWindowManager.shared
    private var settings = AppSettings.shared
    private var localization = LocalizationManager.shared
    private var updaterManager = UpdaterManager.shared
    private var permissions = PermissionsMonitor.shared

    var body: some Scene {
        MenuBarExtra(
            "Just Screenshot",
            systemImage: windowManager.isRecording
                ? "record.circle.fill"
                : (windowManager.isRecordingPreparing ? "viewfinder.circle.fill" : "camera.viewfinder")
        ) {
            let _ = localization.currentLanguage
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
                } else if windowManager.isRecordingPreparing {
                    HStack {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("\(L("recording.bar.start_record")): \(Int(windowManager.recordingRect.width)) × \(Int(windowManager.recordingRect.height))")
                            .font(.headline)
                    }

                    Button(L("recording.bar.start_record")) {
                        windowManager.startActiveRecording()
                    }
                    .keyboardShortcut(.return, modifiers: [])

                    Button(L("alert.cancel")) {
                        windowManager.cancelRecordingSetup()
                    }
                    .keyboardShortcut(.escape, modifiers: [])

                    Divider()
                } else {
                    Button {
                        windowManager.startScreenRecording()
                    } label: {
                        Label(L("menu.record_screen"), systemImage: "record.circle")
                    }
                    .optionalKeyboardShortcut(settings.shortcutRecording)

                    Button {
                        windowManager.startWindowCapture()
                    } label: {
                        Label(L("menu.capture_window"), systemImage: "macwindow")
                    }
                    .optionalKeyboardShortcut(settings.shortcutWindow)

                    Button {
                        windowManager.startAreaCapture()
                    } label: {
                        Label(L("menu.capture_area"), systemImage: "crop")
                    }
                    .optionalKeyboardShortcut(settings.shortcutArea)

                    Button {
                        windowManager.repeatLastCapture()
                    } label: {
                        Label(L("menu.repeat_capture"), systemImage: "arrow.counterclockwise")
                    }
                    .optionalKeyboardShortcut(settings.shortcutRepeat)

                    Button {
                        windowManager.startTextCapture()
                    } label: {
                        Label(L("menu.capture_text"), systemImage: "text.viewfinder")
                    }
                    .optionalKeyboardShortcut(settings.shortcutOCR)

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

                if windowManager.hasLockedPins {
                    Button {
                        windowManager.unlockAllPins()
                    } label: {
                        Label(L("pin.unlock_pins"), systemImage: "lock.open")
                    }

                    Divider()
                }

                Button {
                    windowManager.showHistory()
                } label: {
                    Label(L("menu.history"), systemImage: "clock.arrow.circlepath")
                }
                .optionalKeyboardShortcut(settings.shortcutHistory)

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

                Button {
                    permissions.refresh()
                    windowManager.showSettings()
                } label: {
                    Label(
                        L("menu.check_permissions"),
                        systemImage: permissions.screenRecordingGranted ? "checkmark.shield" : "exclamationmark.triangle"
                    )
                }

                Button {
                    updaterManager.checkForUpdates()
                } label: {
                    Label(
                        updaterManager.isChecking ? L("updater.checking") : L("menu.check_updates"),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .disabled(!updaterManager.canCheckForUpdates || updaterManager.isChecking)

                Divider()

                Button(L("menu.quit")) {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func optionalKeyboardShortcut(_ shortcut: ShortcutKey?) -> some View {
        if let resolved = shortcut?.swiftUIKeyboardShortcut {
            self.keyboardShortcut(resolved.key, modifiers: resolved.modifiers)
        } else {
            self
        }
    }
}
