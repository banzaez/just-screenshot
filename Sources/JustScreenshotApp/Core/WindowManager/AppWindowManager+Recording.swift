import AppKit
import ScreenCaptureKit

extension AppWindowManager {
    // MARK: - Запись экрана
    
    public func toggleRecording() {
        if isRecording { stopScreenRecording() } else { startScreenRecording() }
    }
    
    public func startScreenRecording() {
        Task { [weak self] in
            guard let self else { return }
            let hasPerm = await ScreenCaptureService.shared.ensurePermission()
            guard hasPerm else { return }
            
            self.closeAllOverlays()
            guard let screen = NSScreen.main else { return }
            self.overlayToken = UUID()
            self.presentOverlay(
                AreaOverlayWindow(
                    screen: screen, mode: .recordingArea, visibleWindows: [],
                    onCompleteRect: { [weak self] rect in
                        self?.closeAllOverlays()
                        Task { [weak self] in await self?.beginRecordingArea(rect: rect) }
                    },
                    onCompleteWindow: { _ in },
                    onCancel: { [weak self] in self?.closeAllOverlays() }
                )
            )
        }
    }
    
    func beginRecordingArea(rect: CGRect) async {
        let moviesDir = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        let outputURL = moviesDir.appendingPathComponent("ScreenRecording-\(Int(Date().timeIntervalSince1970)).mp4")
        
        do {
            try await ScreenRecorderService.shared.startRecording(rect: rect, destinationURL: outputURL)
            isRecording = true
            isRecordingPaused = false
            recordingDuration = 0
            if AppSettings.shared.playSound {
                NSSound(named: "Purr")?.play()
            }
            
            // Преобразуем координаты ScreenCaptureKit (origin вверху основного экрана) в координаты AppKit
            let screenHeight = NSScreen.main?.frame.height ?? 900
            let appKitRect = NSRect(
                x: rect.origin.x,
                y: screenHeight - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            )
            
            // 1. Показываем рамку выделения области
            let frameWin = RecordingFrameWindow(screenRect: appKitRect)
            frameWin.orderFrontRegardless()
            self.recordingFrameWindow = frameWin
            
            // 2. Вычисляем позицию для плавающей панели снизу области (если включено в настройках)
            if AppSettings.shared.showFloatingBarDuringRecording {
                var barCenter = NSPoint(x: appKitRect.midX, y: appKitRect.minY - 35)
                // Если панель выходит за нижний край экрана, показываем её внутри внизу области
                if barCenter.y < 40 {
                    barCenter.y = appKitRect.minY + 35
                }
                // Предотвращаем выход за левый и правый края
                let minX: CGFloat = 160
                let maxX: CGFloat = (NSScreen.main?.frame.width ?? 1440) - 160
                barCenter.x = max(minX, min(maxX, barCenter.x))
                
                let barWin = RecordingControlBarWindow(
                    initialPosition: barCenter,
                    windowManager: self,
                    onPauseResume: { [weak self] in self?.togglePauseResumeScreenRecording() },
                    onStop: { [weak self] in self?.stopScreenRecording() },
                    onCancel: { [weak self] in self?.cancelScreenRecording() }
                )
                barWin.orderFrontRegardless()
                self.recordingBarWindow = barWin
            }
            
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isRecording, !self.isRecordingPaused else { return }
                    self.recordingDuration += 1
                }
            }
        } catch {
            print("Recording start failed: \(error.localizedDescription)")
        }
    }
    
    public func togglePauseResumeScreenRecording() {
        guard isRecording else { return }
        if isRecordingPaused {
            ScreenRecorderService.shared.resumeRecording()
            isRecordingPaused = false
        } else {
            ScreenRecorderService.shared.pauseRecording()
            isRecordingPaused = true
        }
    }
    
    public func stopScreenRecording() {
        cleanupRecordingSession()
        
        Task {
            if let savedURL = try? await ScreenRecorderService.shared.stopRecording() {
                await MainActor.run {
                    self.openVideoEditor(videoURL: savedURL)
                }
            }
        }
    }
    
    public func cancelScreenRecording() {
        cleanupRecordingSession()
        
        Task {
            await ScreenRecorderService.shared.cancelRecording()
        }
    }
    
    func cleanupRecordingSession() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        isRecordingPaused = false
        
        recordingFrameWindow?.orderOut(nil)
        recordingFrameWindow = nil
        
        recordingBarWindow?.orderOut(nil)
        recordingBarWindow = nil
    }
}
