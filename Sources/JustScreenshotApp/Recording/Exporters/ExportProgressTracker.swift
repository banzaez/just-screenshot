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

    deinit {
        timer?.cancel()
        timer = nil
    }

    func start() {
        queue.sync {
            timer?.cancel()
            let newTimer = DispatchSource.makeTimerSource(queue: queue)
            newTimer.schedule(deadline: .now() + 0.1, repeating: 0.1)
            newTimer.setEventHandler { [weak self] in
                guard let self, let session = self.exportSession else { return }
                let prog = Double(session.progress)
                self.progressHandler(prog)
            }
            self.timer = newTimer
            newTimer.resume()
        }
    }

    func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
        }
    }
}
