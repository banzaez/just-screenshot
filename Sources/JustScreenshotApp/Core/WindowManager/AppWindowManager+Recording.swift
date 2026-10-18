import AppKit
import ScreenCaptureKit

extension AppWindowManager {
    // MARK: - Запись экрана
    
    public func toggleRecording() {
        if isRecording { stopScreenRecording() } else { startScreenRecording() }
    }
    
    public func startScreenRecording() {
        if !ScreenCaptureService.shared.hasScreenCapturePermission() {
            Task { [weak self] in
                guard let self else { return }
                let granted = await ScreenCaptureService.shared.checkAndRequestPermissions()
                if !granted {
                    ScreenCaptureService.shared.showPermissionAlert()
                    return
                }
                self.startScreenRecording()
            }
            return
        }
        
        beginOverlaySession()
        let screens = activeScreens()
        guard !screens.isEmpty else { return }
        
        let overlays = screens.map { screen in
            acquireOverlay(for: screen).configured(
                screen: screen,
                mode: .recordingArea,
                onCompleteRect: { [weak self] rect in
                    self?.closeAllOverlays()
                    Task { [weak self] in await self?.beginRecordingArea(rect: rect) }
                },
                onCompleteWindow: { _ in },
                onCancel: { [weak self] in self?.closeAllOverlays() }
            )
        }
        presentOverlays(overlays)
    }
    
    func beginRecordingArea(rect: CGRect) async {
        let moviesDir = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        let outputURL = moviesDir.appendingPathComponent("ScreenRecording-\(Int(Date().timeIntervalSince1970)).mp4")
        
        do {
            try await ScreenRecorderService.shared.startRecording(rect: rect, destinationURL: outputURL)
            isRecording = true
            isRecordingPaused = false
            recordingDuration = 0
            recordingStartedAt = Date()
            recordingPausedAt = nil
            recordingAccumulatedPause = 0
            
            if AppSettings.shared.playSound {
                NSSound(named: "Purr")?.play()
            }
            
            let primaryScreenHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
                ?? NSScreen.main?.frame.height
                ?? 900
            let appKitRect = NSRect(
                x: rect.origin.x,
                y: primaryScreenHeight - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            )
            
            let frameWin = RecordingFrameWindow(screenRect: appKitRect)
            frameWin.orderFrontRegardless()
            recordingFrameWindow = frameWin
            
            if AppSettings.shared.showFloatingBarDuringRecording {
                var barCenter = NSPoint(x: appKitRect.midX, y: appKitRect.minY - 35)
                if barCenter.y < 40 {
                    barCenter.y = appKitRect.minY + 35
                }
                let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(barCenter, $0.frame, false) })
                    ?? NSScreen.main
                    ?? NSScreen.screens.first
                let screenMinX = (targetScreen?.frame.minX ?? 0) + 160
                let screenMaxX = (targetScreen?.frame.maxX ?? 1440) - 160
                barCenter.x = max(screenMinX, min(screenMaxX, barCenter.x))
                
                let barWin = RecordingControlBarWindow(
                    initialPosition: barCenter,
                    windowManager: self,
                    onPauseResume: { [weak self] in self?.togglePauseResumeScreenRecording() },
                    onStop: { [weak self] in self?.stopScreenRecording() },
                    onCancel: { [weak self] in self?.cancelScreenRecording() }
                )
                barWin.orderFrontRegardless()
                recordingBarWindow = barWin
            }
            
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tickRecordingDuration()
                }
            }
        } catch {
            showRecordingError(error.localizedDescription)
        }
    }
    
    public func togglePauseResumeScreenRecording() {
        guard isRecording else { return }
        if isRecordingPaused {
            if let pausedAt = recordingPausedAt {
                recordingAccumulatedPause += Date().timeIntervalSince(pausedAt)
            }
            recordingPausedAt = nil
            ScreenRecorderService.shared.resumeRecording()
            isRecordingPaused = false
        } else {
            recordingPausedAt = Date()
            ScreenRecorderService.shared.pauseRecording()
            isRecordingPaused = true
        }
        tickRecordingDuration()
    }
    
    public func stopScreenRecording() {
        cleanupRecordingSession()
        
        Task {
            do {
                if let savedURL = try await ScreenRecorderService.shared.stopRecording() {
                    await MainActor.run {
                        self.openVideoEditor(videoURL: savedURL)
                    }
                }
            } catch {
                await MainActor.run {
                    self.showRecordingError(error.localizedDescription)
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
        recordingStartedAt = nil
        recordingPausedAt = nil
        recordingAccumulatedPause = 0
        
        recordingFrameWindow?.orderOut(nil)
        recordingFrameWindow = nil
        
        recordingBarWindow?.orderOut(nil)
        recordingBarWindow = nil
    }
    
    private func tickRecordingDuration() {
        guard isRecording, let start = recordingStartedAt else { return }
        var paused = recordingAccumulatedPause
        if let pausedAt = recordingPausedAt {
            paused += Date().timeIntervalSince(pausedAt)
        }
        recordingDuration = max(0, Date().timeIntervalSince(start) - paused)
    }
    
    private func showRecordingError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L("recording.error_title")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("alert.cancel"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
