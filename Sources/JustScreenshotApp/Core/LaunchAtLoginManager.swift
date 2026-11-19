import Foundation
import ServiceManagement
import Observation

/// Сервис управления автозапуском приложения при входе в систему (macOS 14+)
@Observable
@MainActor
public final class LaunchAtLoginManager {
    public static let shared = LaunchAtLoginManager()

    public private(set) var isEnabled: Bool = false
    public private(set) var requiresApproval: Bool = false

    private init() {
        refreshStatus()
    }

    public func refreshStatus() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    public func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status == .enabled {
                    refreshStatus()
                    return
                }
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshStatus()
        } catch {
            AppLogger.general.error("Failed to toggle launch at login: \(error.localizedDescription, privacy: .public)")
            refreshStatus()
        }
    }
}
