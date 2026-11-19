import Foundation
import AppKit
import Sparkle
import Combine
import Observation

@Observable
@MainActor
public final class UpdaterManager: NSObject, SPUUpdaterDelegate {
    public static let shared = UpdaterManager()

    public enum UpdateStatus: Equatable, Sendable {
        case upToDate
        case error(String)
    }

    public var canCheckForUpdates: Bool = false
    public var isChecking: Bool = false
    public var status: UpdateStatus? = nil

    public var isLastStatusError: Bool {
        if case .error = status { return true }
        return false
    }

    public var lastStatus: String? {
        switch status {
        case .none:
            return nil
        case .upToDate:
            return L("menu.up_to_date")
        case .error(let message):
            return message
        }
    }

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
        guard canCheckForUpdates, !isChecking else { return }
        isChecking = true
        status = nil
        updaterController.updater.checkForUpdatesInBackground()
    }

    // MARK: - SPUUpdaterDelegate

    public func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        isChecking = false
        status = nil
    }

    public func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        handleCheckResult(upToDate: true)
    }

    public func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == SUSparkleErrorDomain {
            // 1001 = SUNoUpdateError, 4002 = SUInstallationCanceledError
            if nsError.code == 1001 {
                handleCheckResult(upToDate: true)
                return
            }
            if nsError.code == 4002 {
                handleCheckResult(upToDate: false, error: nil)
                return
            }
        }
        AppLogger.updater.error("Sparkle aborted update check: \(error.localizedDescription, privacy: .public)")
        handleCheckResult(upToDate: false, error: error)
    }

    public func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        if isChecking {
            isChecking = false
        }
    }

    private func handleCheckResult(upToDate: Bool, error: Error? = nil) {
        guard isChecking else { return }
        isChecking = false

        if upToDate {
            status = .upToDate
            presentUpToDateAlert()
        } else if let error {
            status = .error(error.localizedDescription)
            presentErrorAlert(error.localizedDescription)
        }
    }

    private func presentUpToDateAlert() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L("update.up_to_date_title")
        alert.informativeText = L("update.up_to_date_desc", version)
        alert.addButton(withTitle: L("alert.ok"))
        NSApp.activate()
        alert.runModal()
    }

    private func presentErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("update.failed_title")
        alert.informativeText = message
        alert.addButton(withTitle: L("alert.ok"))
        NSApp.activate()
        alert.runModal()
    }
}
