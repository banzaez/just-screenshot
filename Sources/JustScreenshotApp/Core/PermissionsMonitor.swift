import AppKit
import ApplicationServices
import Foundation
import Observation

/// Наблюдатель за системными разрешениями macOS (Запись экрана и Универсальный доступ).
/// Автоматически обновляет статусы при возврате в приложение из «Системных настроек».
@MainActor
@Observable
public final class PermissionsMonitor {
    public static let shared = PermissionsMonitor()

    public private(set) var screenRecordingGranted: Bool
    public private(set) var accessibilityGranted: Bool
    public private(set) var didOpenScreenRecordingSettings = false

    public var allGranted: Bool {
        screenRecordingGranted && accessibilityGranted
    }

    public var grantedCount: Int {
        (screenRecordingGranted ? 1 : 0) + (accessibilityGranted ? 1 : 0)
    }

    @ObservationIgnored
    nonisolated(unsafe) private var activationObserver: NSObjectProtocol?

    private init() {
        self.screenRecordingGranted = CGPreflightScreenCaptureAccess()
        self.accessibilityGranted = AXIsProcessTrusted()

        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    /// Обновляет текущие статусы разрешений из системы.
    public func refresh() {
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
        accessibilityGranted = AXIsProcessTrusted()
        if screenRecordingGranted {
            didOpenScreenRecordingSettings = false
        }
    }

    /// Запрашивает разрешение на запись экрана и открывает соответствующий раздел Системных настроек.
    public func requestScreenRecording() {
        didOpenScreenRecordingSettings = true
        if #available(macOS 14.4, *) {
            _ = CGRequestScreenCaptureAccess()
        }
        ScreenCaptureService.shared.openSystemSettings()
        refresh()
    }

    /// Запрашивает разрешение «Универсальный доступ» и при необходимости открывает Системные настройки.
    public func requestAccessibility() {
        _ = AccessibilityPermissionHelper.requestAccess()
        refresh()
    }

    /// Перезапускает приложение (macOS часто требует перезапуск после выдачи прав на запись экрана).
    public func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }
}
