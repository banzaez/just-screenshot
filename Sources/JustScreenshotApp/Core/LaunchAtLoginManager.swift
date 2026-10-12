import Foundation
import ServiceManagement

/// Сервис управления автозапуском приложения при входе в систему (macOS 13+)
@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    @Published public private(set) var isEnabled: Bool = false
    
    private init() {
        refreshStatus()
    }
    
    public func refreshStatus() {
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
    
    public func toggle() {
        setLaunchAtLogin(!isEnabled)
    }
    
    public func setLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status == .enabled {
                        isEnabled = true
                        return
                    }
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                refreshStatus()
            } catch {
                print("Failed to toggle launch at login: \(error.localizedDescription)")
                refreshStatus()
            }
        }
    }
}
