import AppKit
import ScreenCaptureKit

extension AppWindowManager {
    // MARK: - Запись экрана

    public func toggleRecording() {
        switch recordingPhase {
        case .recording:
            stopScreenRecording()
        case .preparing:
            startActiveRecording()
        case .idle:
            startScreenRecording()
        case .selectingArea, .countdown, .starting, .stopping:
            break
        }
    }

    public func startScreenRecording() {
        guard recordingPhase == .idle || recordingPhase == .preparing else { return }
        Task { [weak self] in
            guard let self else { return }
            guard await ScreenCaptureService.shared.ensurePermission() else { return }

            if self.recordingPhase == .preparing {
                self.recordingDimWindows.forEach { $0.orderFrontRegardless() }
                self.recordingFrameWindow?.orderFrontRegardless()
                self.recordingBarWindow?.orderFrontRegardless()
                return
            }
            guard self.recordingPhase == .idle else { return }

            self.cancelActiveTimedCapture()
            self.presentRecordingAreaSelection()
        }
    }

    private func evenRecordingRect(_ rect: CGRect) -> CGRect {
        let w = Int(rect.width.rounded())
        let h = Int(rect.height.rounded())
        return CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: CGFloat(max(160, w - (w % 2))),
            height: CGFloat(max(120, h - (h % 2)))
        )
    }

    // MARK: - Первичное выделение области

    public func presentRecordingAreaSelection() {
        cleanupRecordingSession()
        recordingPhase = .selectingArea

        guard presentSelectionOverlays(
            mode: .recordingArea,
            needsSampler: false,
            onCompleteRect: { [weak self] quartzRect, _ in
                let appKitRect = ScreenCoordinateSpace.appKitRect(fromQuartz: quartzRect)
                self?.enterRecordingSetup(appKitRect: self?.evenRecordingRect(appKitRect) ?? appKitRect)
            },
            onCompleteWindow: { [weak self] scWindow in
                let appKitRect = ScreenCoordinateSpace.appKitRect(fromQuartz: scWindow.frame)
                self?.enterRecordingSetup(appKitRect: self?.evenRecordingRect(appKitRect) ?? appKitRect)
            },
            onCancel: { [weak self] in
                if self?.recordingPhase == .selectingArea {
                    self?.recordingPhase = .idle
                }
            }
        ) != nil else {
            recordingPhase = .idle
            return
        }
    }

    // MARK: - Режим подготовки к записи (Setup / Adjustment Mode)

    public func enterRecordingSetup(appKitRect: CGRect) {
        closeAllOverlays(restoreRecordingSetup: false)
        cleanupRecordingSession()

        let normalizedRect = evenRecordingRect(appKitRect)
        recordingPhase = .preparing
        recordingRect = normalizedRect

        setupRecordingDimWindows(holeRect: normalizedRect)

        let frameWin = RecordingFrameWindow(
            screenRect: normalizedRect,
            mode: .setup,
            onRectChanged: { [weak self] newRect in
                guard let self else { return }
                self.recordingRect = newRect
                self.repositionRecordingBar(relativeTo: newRect)
                self.updateRecordingDimHole(newRect)
            },
            onStartRequested: { [weak self] in
                self?.startActiveRecording()
            },
            onCancelRequested: { [weak self] in
                self?.cancelRecordingSetup()
            }
        )
        NSApp.activate()
        frameWin.makeKeyAndOrderFront(nil)
        recordingFrameWindow = frameWin

        let barWin = RecordingControlBarWindow(
            initialPosition: calculateBarCenter(for: normalizedRect),
            windowManager: self,
            onStartRecording: { [weak self] in
                self?.startActiveRecording()
            },
            onSelectPreset: { [weak self] presetRect in
                self?.applyPresetRect(presetRect)
            },
            onRequestNewArea: { [weak self] in
                self?.selectNewRecordingArea()
            },
            onToggleDimming: { [weak self] in
                guard let self else { return }
                self.syncRecordingDimWindows(holeRect: self.recordingRect)
            },
            onPauseResume: { [weak self] in
                self?.togglePauseResumeScreenRecording()
            },
            onStop: { [weak self] in
                self?.stopScreenRecording()
            },
            onCancel: { [weak self] in
                if self?.recordingPhase == .recording {
                    self?.cancelScreenRecording()
                } else {
                    self?.cancelRecordingSetup()
                }
            }
        )
        barWin.orderFrontRegardless()
        recordingBarWindow = barWin

        recordingState.setupEscMonitor.start(
            shouldHandle: { [weak self] in
                guard let self else { return false }
                return self.recordingPhase == .preparing && self.overlayWindows.isEmpty
            },
            onEscape: { [weak self] in
                self?.cancelRecordingSetup()
            }
        )
    }

    public func applyPresetRect(_ rect: CGRect) {
        let evenRect = evenRecordingRect(rect)
        recordingRect = evenRect
        recordingFrameWindow?.updateFrame(evenRect, notify: false)
        repositionRecordingBar(relativeTo: evenRect)
        updateRecordingDimHole(evenRect)
    }

    public func selectNewRecordingArea() {
        guard recordingPhase == .preparing else { return }
        recordingDimWindows.forEach { $0.orderOut(nil) }
        recordingFrameWindow?.orderOut(nil)
        recordingBarWindow?.orderOut(nil)
        recordingPhase = .selectingArea

        guard presentSelectionOverlays(
            mode: .recordingArea,
            needsSampler: false,
            onCompleteRect: { [weak self] quartzRect, _ in
                let appKitRect = ScreenCoordinateSpace.appKitRect(fromQuartz: quartzRect)
                self?.enterRecordingSetup(appKitRect: appKitRect)
            },
            onCompleteWindow: { [weak self] scWindow in
                let appKitRect = ScreenCoordinateSpace.appKitRect(fromQuartz: scWindow.frame)
                self?.enterRecordingSetup(appKitRect: appKitRect)
            },
            onCancel: { [weak self] in
                guard let self else { return }
                self.recordingPhase = .preparing
                self.recordingDimWindows.forEach { $0.orderFrontRegardless() }
                self.recordingFrameWindow?.makeKeyAndOrderFront(nil)
                self.recordingBarWindow?.orderFrontRegardless()
            }
        ) != nil else {
            recordingPhase = .preparing
            recordingDimWindows.forEach { $0.orderFrontRegardless() }
            recordingFrameWindow?.makeKeyAndOrderFront(nil)
            recordingBarWindow?.orderFrontRegardless()
            return
        }
    }

    public func cancelRecordingSetup() {
        cleanupRecordingSession()
    }

    // MARK: - Затемнение экрана (Dimming Overlay)

    func setupRecordingDimWindows(holeRect: CGRect) {
        clearRecordingDimWindows()
        guard AppSettings.shared.dimOutsideRecordingArea else { return }
        let screens = activeScreens()
        recordingDimWindows = screens.map { screen in
            let win = RecordingDimOverlayWindow(screen: screen, holeRect: holeRect)
            win.orderFrontRegardless()
            return win
        }
    }

    func updateRecordingDimHole(_ rect: CGRect) {
        guard AppSettings.shared.dimOutsideRecordingArea else { return }
        for win in recordingDimWindows {
            win.updateHole(appKitRect: rect)
        }
    }

    func syncRecordingDimWindows(holeRect: CGRect) {
        if AppSettings.shared.dimOutsideRecordingArea {
            if recordingDimWindows.isEmpty {
                setupRecordingDimWindows(holeRect: holeRect)
            } else {
                for win in recordingDimWindows {
                    win.updateHole(appKitRect: holeRect)
                    win.orderFrontRegardless()
                }
            }
        } else {
            clearRecordingDimWindows()
        }
        recordingFrameWindow?.orderFrontRegardless()
        if recordingPhase != .recording || AppSettings.shared.showFloatingBarDuringRecording {
            recordingBarWindow?.orderFrontRegardless()
        }
    }

    func clearRecordingDimWindows() {
        for win in recordingDimWindows {
            win.orderOut(nil)
            win.contentView = nil
            win.close()
        }
        recordingDimWindows.removeAll()
    }

    // MARK: - Запуск активной записи (Active Recording)

    public func startActiveRecording() {
        guard recordingPhase == .preparing else { return }

        let rectToRecord = recordingRect
        let countdownSec = AppSettings.shared.recordingCountdownSeconds

        if countdownSec > 0 {
            recordingPhase = .countdown
            let center = CGPoint(x: rectToRecord.midX, y: rectToRecord.midY)
            let countdown = CountdownOverlayWindow(seconds: countdownSec, centerPoint: center) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.recordingPhase == .countdown else { return }
                    self.recordingState.countdownEscMonitor.stop()
                    self.recordingState.countdownWindow?.cancel()
                    self.recordingState.countdownWindow = nil
                    await self.beginActiveRecording(appKitRect: rectToRecord)
                }
            }
            recordingState.countdownWindow = countdown
            recordingState.countdownEscMonitor.start(includeGlobal: true, useHotKeyFallback: true) { [weak self] in
                self?.cancelRecordingSetup()
            }
            NSApp.activate()
            countdown.makeKeyAndOrderFront(nil)
        } else {
            recordingPhase = .starting
            Task { [weak self] in
                await self?.beginActiveRecording(appKitRect: rectToRecord)
            }
        }
    }

    private func beginActiveRecording(appKitRect: CGRect) async {
        guard recordingPhase == .countdown || recordingPhase == .starting else { return }
        recordingPhase = .starting

        recordingState.setupEscMonitor.stop()
        recordingState.countdownEscMonitor.stop()

        let baseDir: URL
        if let customDir = ImageExporter.defaultSaveDirectoryURL() {
            baseDir = customDir
        } else {
            baseDir = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
        }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let outputURL = baseDir.appendingPathComponent("ScreenRecording-\(df.string(from: Date())).mp4")

        let quartzRect = ScreenCoordinateSpace.quartzRect(fromAppKit: appKitRect)

        recordingFrameWindow?.setMode(.recording)

        if AppSettings.shared.dimOutsideRecordingArea {
            syncRecordingDimWindows(holeRect: appKitRect)
        } else {
            clearRecordingDimWindows()
        }

        ScreenRecorderService.shared.onUnexpectedStop = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self, self.recordingPhase == .recording || self.recordingPhase == .starting else { return }
                self.cleanupRecordingSession()
                self.presentAlert(
                    title: L("recording.error_title"),
                    message: error.localizedDescription
                )
            }
        }

        do {
            try await ScreenRecorderService.shared.startRecording(rect: quartzRect, destinationURL: outputURL)
            guard recordingPhase == .starting else {
                await ScreenRecorderService.shared.cancelRecording()
                cleanupRecordingSession()
                return
            }

            CursorTrackRecorder.shared.start(recordingRect: appKitRect)
            KeystrokeTrackRecorder.shared.start()
            recordingPhase = .recording
            isRecordingPaused = false
            recordingDuration = 0
            recordingStartedAt = Date()
            recordingPausedAt = nil
            recordingAccumulatedPause = 0

            SoundEffects.playRecordStart()

            if AppSettings.shared.showFloatingBarDuringRecording {
                recordingBarWindow?.updateForRecordingMode()
                repositionRecordingBar(relativeTo: appKitRect)
                recordingBarWindow?.orderFrontRegardless()
            } else {
                recordingBarWindow?.orderOut(nil)
            }

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.tickRecordingDuration()
                }
            }
        } catch {
            cleanupRecordingSession()
            presentAlert(
                title: L("recording.error_title"),
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Пауза, возобновление, остановка

    public func togglePauseResumeScreenRecording() {
        guard recordingPhase == .recording else { return }
        if isRecordingPaused {
            if let pausedAt = recordingPausedAt {
                recordingAccumulatedPause += Date().timeIntervalSince(pausedAt)
            }
            recordingPausedAt = nil
            ScreenRecorderService.shared.resumeRecording()
            CursorTrackRecorder.shared.resume()
            KeystrokeTrackRecorder.shared.resume()
            isRecordingPaused = false
        } else {
            recordingPausedAt = Date()
            ScreenRecorderService.shared.pauseRecording()
            CursorTrackRecorder.shared.pause()
            KeystrokeTrackRecorder.shared.pause()
            isRecordingPaused = true
        }
        tickRecordingDuration(force: true)
    }

    public func stopScreenRecording() {
        guard recordingPhase == .recording else { return }
        tickRecordingDuration(force: true)
        recordingPhase = .stopping

        let recordedRect = recordingRect
        let recordedDuration = max(0.1, recordingDuration)
        let cursorTrack = CursorTrackRecorder.shared.stop()
        let keystrokeTrack = KeystrokeTrackRecorder.shared.stop()
        cleanupRecordingSession(targetPhase: .stopping)

        Task { [weak self] in
            defer {
                self?.recordingPhase = .idle
            }
            do {
                if let savedURL = try await ScreenRecorderService.shared.stopRecording() {
                    CursorTrackRecorder.saveTrack(cursorTrack, forVideoURL: savedURL)
                    KeystrokeTrackRecorder.saveTrack(keystrokeTrack, forVideoURL: savedURL)
                    self?.history.addVideo(
                        url: savedURL,
                        width: Int(recordedRect.width),
                        height: Int(recordedRect.height),
                        duration: recordedDuration
                    )
                    self?.openVideoEditor(videoURL: savedURL, cursorTrack: cursorTrack, keystrokeTrack: keystrokeTrack)
                }
            } catch {
                self?.presentAlert(
                    title: L("recording.error_title"),
                    message: error.localizedDescription
                )
            }
        }
    }

    public func cancelScreenRecording() {
        _ = CursorTrackRecorder.shared.stop()
        _ = KeystrokeTrackRecorder.shared.stop()
        cleanupRecordingSession()

        Task {
            await ScreenRecorderService.shared.cancelRecording()
        }
    }

    func cleanupRecordingSession(targetPhase: RecordingPhase = .idle) {
        _ = CursorTrackRecorder.shared.stop()
        _ = KeystrokeTrackRecorder.shared.stop()
        ScreenRecorderService.shared.onUnexpectedStop = nil
        recordingState.setupEscMonitor.stop()
        recordingState.countdownEscMonitor.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil

        recordingPhase = targetPhase
        isRecordingPaused = false
        recordingStartedAt = nil
        recordingPausedAt = nil
        recordingAccumulatedPause = 0

        recordingState.countdownWindow?.cancel()
        recordingState.countdownWindow?.close()
        recordingState.countdownWindow = nil

        clearRecordingDimWindows()

        recordingFrameWindow?.orderOut(nil)
        recordingFrameWindow?.contentView = nil
        recordingFrameWindow?.close()
        recordingFrameWindow = nil

        recordingBarWindow?.orderOut(nil)
        recordingBarWindow?.contentView = nil
        recordingBarWindow?.close()
        recordingBarWindow = nil
    }

    // MARK: - Вспомогательные методы

    func repositionRecordingBar(relativeTo rect: CGRect) {
        guard let barWin = recordingBarWindow else { return }
        let center = calculateBarCenter(for: rect)
        barWin.updatePosition(center: center)
    }

    func calculateBarCenter(for rect: CGRect) -> NSPoint {
        let targetScreen = ScreenCoordinateSpace.targetScreen(for: rect)
        let screenFrame = targetScreen?.visibleFrame ?? targetScreen?.frame
        let barSize = recordingBarWindow?.frame.size
            ?? CGSize(width: recordingPhase == .recording ? 340 : 560, height: 52)
        let halfW = barSize.width / 2
        let halfH = barSize.height / 2

        var barCenter = NSPoint(x: rect.midX, y: rect.minY - 40)
        if let screenFrame {
            if barCenter.y - halfH < screenFrame.minY + 10 {
                barCenter.y = rect.maxY + 40
            }
            let minX = screenFrame.minX + halfW + 10
            let maxX = max(minX, screenFrame.maxX - halfW - 10)
            barCenter.x = max(minX, min(maxX, barCenter.x))
            let minY = screenFrame.minY + halfH + 8
            let maxY = max(minY, screenFrame.maxY - halfH - 8)
            barCenter.y = max(minY, min(maxY, barCenter.y))
        }
        return barCenter
    }

    private func tickRecordingDuration(force: Bool = false) {
        guard recordingPhase == .recording, let start = recordingStartedAt else { return }
        if isRecordingPaused && !force { return }
        var paused = recordingAccumulatedPause
        if let pausedAt = recordingPausedAt {
            paused += Date().timeIntervalSince(pausedAt)
        }
        let elapsed = max(0, Date().timeIntervalSince(start) - paused)
        if force || Int(elapsed) != Int(recordingDuration) {
            recordingDuration = elapsed
        }
    }
}
