import Foundation
import AVFoundation

/// Потокобезопасный трекер прогресса экспорта для AVAssetExportSession
final class ExportProgressTracker: @unchecked Sendable {
    private weak var exportSession: AVAssetExportSession?
    private let progressHandler: @Sendable (Double) -> Void
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.justscreenshot.export.tracker")
    
    init(exportSession: AVAssetExportSession, progressHandler: @Sendable @escaping (Double) -> Void) {
        self.exportSession = exportSession
        self.progressHandler = progressHandler
    }
    
    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
        timer.setEventHandler { [weak self] in
            guard let self, let session = self.exportSession else { return }
            let prog = Double(session.progress)
            self.progressHandler(prog)
        }
        self.timer = timer
        timer.resume()
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
    }
}
