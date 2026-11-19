import AppKit
import ApplicationServices
import Foundation
import Observation

/// Наблюдатель за системными разрешениями macOS (Запись экрана и Универсальный доступ).
@MainActor
@Observable
public final class PermissionsMonitor {
    public static let shared = PermissionsMonitor()

    public private(set) var screenRecordingGranted: Bool
    public private(set) var accessibilityGranted: Bool

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
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    /// Обновляет статусы разрешений из системы только при реальном изменении (без лишних redraw)
    public func refresh() {
        let newScreen = CGPreflightScreenCaptureAccess()
        if newScreen != screenRecordingGranted {
            screenRecordingGranted = newScreen
        }

        let newAccessibility = AXIsProcessTrusted()
        if newAccessibility != accessibilityGranted {
            accessibilityGranted = newAccessibility
            GlobalHotKeyManager.shared.handleAccessibilityStatusChanged(trusted: newAccessibility)
        } else if newAccessibility && !GlobalHotKeyManager.shared.isEventTapActive {
            GlobalHotKeyManager.shared.ensureEventTapIfTrusted()
        }
    }

    /// Запрашивает разрешение на запись экрана и открывает соответствующий раздел Системных настроек
    public func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        ScreenCaptureService.shared.openSystemSettings()
        refresh()
    }

    /// Запрашивает разрешение «Универсальный доступ» и открывает Системные настройки при необходимости
    public func requestAccessibility() {
        _ = AccessibilityPermissionHelper.requestAccess(openSettings: true)
        refresh()
    }

    /// Безопасный перезапуск приложения: завершает текущий экземпляр только при успешном запуске нового
    public func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { app, error in
            Task { @MainActor in
                if let error {
                    AppLogger.general.error("Failed to relaunch app: \(error.localizedDescription, privacy: .public)")
                    return
                }
                if app != nil {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
