import Foundation
import Sparkle
import Combine

@MainActor
public final class UpdaterManager: ObservableObject {
    public static let shared = UpdaterManager()
    
    @Published public var canCheckForUpdates: Bool = false
    
    public let updaterController: SPUStandardUpdaterController
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }
    
    public func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
