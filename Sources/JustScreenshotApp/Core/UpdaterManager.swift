import Foundation
import AppKit
import Sparkle
import Combine
import Observation

@Observable
@MainActor
public final class UpdaterManager: NSObject, SPUUpdaterDelegate {
    public static let shared = UpdaterManager()
    
    public var canCheckForUpdates: Bool = false
    public var isChecking: Bool = false
    public var lastStatus: String? = nil
    
    @ObservationIgnored public private(set) var updaterController: SPUStandardUpdaterController!
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    
    override private init() {
        super.init()
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
            .store(in: &cancellables)
    }
    
    public func checkForUpdates() {
        guard canCheckForUpdates else { return }
        isChecking = true
        lastStatus = nil
        // Запускаем проверку обновлений в фоне:
        // не показывает промежуточное окно поиска, но отображает диалог обновления, если оно найдено
        updaterController.updater.checkForUpdatesInBackground()
    }
    
    // MARK: - SPUUpdaterDelegate
    
    nonisolated public func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in
            self.isChecking = false
            self.lastStatus = nil
        }
    }
    
    nonisolated public func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in
            self.handleCheckResult(upToDate: true)
        }
    }
    
    nonisolated public func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        Task { @MainActor in
            let nsError = error as NSError
            // Sparkle возвращает SUNoUpdateError (код 1001), когда версия приложения является актуальной
            if nsError.code == 1001 {
                self.handleCheckResult(upToDate: true)
            } else if nsError.code == 4002 {
                // SUInstallationCanceledError — пользователь отменил действие
                self.handleCheckResult(upToDate: false, error: nil)
            } else {
                self.handleCheckResult(upToDate: false, error: error)
            }
        }
    }
    
    @MainActor
    private func handleCheckResult(upToDate: Bool, error: Error? = nil) {
        guard isChecking else { return }
        isChecking = false
        
        if upToDate {
            lastStatus = L("menu.up_to_date")
            presentUpToDateAlert()
        } else if let error {
            lastStatus = error.localizedDescription
            presentErrorAlert(error.localizedDescription)
        }
    }
    
    @MainActor
    private func presentUpToDateAlert() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.0"
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L("update.up_to_date_title")
        alert.informativeText = L("update.up_to_date_desc", version)
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    
    @MainActor
    private func presentErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("update.failed_title")
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
