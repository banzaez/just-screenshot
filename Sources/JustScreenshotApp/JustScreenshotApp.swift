import SwiftUI
import AppKit

@main
struct JustScreenshotApp: App {
    @StateObject private var windowManager = AppWindowManager.shared
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    
    var body: some Scene {
        MenuBarExtra("Just Screenshot", systemImage: windowManager.isRecording ? "record.circle.fill" : "camera.viewfinder") {
            VStack(alignment: .leading, spacing: 4) {
                if windowManager.isRecording {
                    HStack {
                        Circle().fill(windowManager.isRecordingPaused ? Color.orange : Color.red).frame(width: 8, height: 8)
                        Text(windowManager.isRecordingPaused ? "Запись на паузе: \(Int(windowManager.recordingDuration))с" : "Идет запись: \(Int(windowManager.recordingDuration))с")
                            .font(.headline)
                    }
                    
                    Button(windowManager.isRecordingPaused ? "Продолжить запись" : "Приостановить запись") {
                        windowManager.togglePauseResumeScreenRecording()
                    }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    
                    Button("Остановить запись и сохранить") {
                        windowManager.stopScreenRecording()
                    }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    
                    Button("Отменить запись (удалить)") {
                        windowManager.cancelScreenRecording()
                    }
                    
                    Divider()
                } else {
                    Button {
                        windowManager.startScreenRecording()
                    } label: {
                        Label("Запись экрана", systemImage: "record.circle")
                    }
                    .keyboardShortcut("3", modifiers: [.command, .shift])
                    
                    Button {
                        windowManager.startWindowCapture()
                    } label: {
                        Label("Скриншот окна", systemImage: "macwindow")
                    }
                    .keyboardShortcut("4", modifiers: [.command, .shift])
                    
                    Button {
                        windowManager.startAreaCapture()
                    } label: {
                        Label("Скриншот произвольного размера", systemImage: "crop")
                    }
                    .keyboardShortcut("5", modifiers: [.command, .shift])
                    
                    Divider()
                }
                
                Button {
                    windowManager.showHistory()
                } label: {
                    Label("История снимков", systemImage: "clock.arrow.circlepath")
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                
                Button {
                    windowManager.openImageFromDisk()
                } label: {
                    Label("Открыть изображение…", systemImage: "photo")
                }
                
                Button {
                    windowManager.openImageFromClipboard()
                } label: {
                    Label("Редактировать из буфера обмена", systemImage: "doc.on.clipboard")
                }
                
                Divider()
                
                Toggle("Запускать при входе в систему", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setLaunchAtLogin($0) }
                ))
                
                Button("Проверить разрешения записи экрана") {
                    Task {
                        _ = await ScreenCaptureService.shared.checkAndRequestPermissions()
                    }
                }
                
                Divider()
                
                Button("Выход") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }
    }
}
