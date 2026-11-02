import Foundation
import Sparkle
import Combine
import Observation

@Observable
@MainActor
public final class UpdaterManager {
    public static let shared = UpdaterManager()
    
    public var canCheckForUpdates: Bool = false
    
    @ObservationIgnored public let updaterController: SPUStandardUpdaterController
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
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
        updaterController.checkForUpdates(nil)
    }
}
