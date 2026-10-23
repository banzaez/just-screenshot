import AppKit
import ScreenCaptureKit

extension AppWindowManager {
    // MARK: - Запись экрана
    
    public func toggleRecording() {
        if isRecording {
            stopScreenRecording()
        } else if isRecordingPreparing {
            startActiveRecording()
        } else {
            startScreenRecording()
        }
    }
    
    public func startScreenRecording() {
        Task { [weak self] in
            guard let self else { return }
            guard await ScreenCaptureService.shared.ensurePermission() else { return }
            
            if self.isRecordingPreparing {
                self.recordingDimWindows.forEach { $0.orderFrontRegardless() }
                self.recordingFrameWindow?.orderFrontRegardless()
                self.recordingBarWindow?.orderFrontRegardless()
                return
            }
            if self.isRecording {
                return
            }
            
            // Сначала пользователь сам выделяет область курсором как при скриншоте
            self.presentRecordingAreaSelection()
        }
    }
    
    // MARK: - Первичное выделение области (как при скриншоте)
    
    public func presentRecordingAreaSelection() {
        closeAllOverlays()
        cleanupRecordingSession()
        
        beginOverlaySession()
        let screens = activeScreens()
        guard !screens.isEmpty else { return }
        
        let overlays = screens.map { screen in
            acquireOverlay(for: screen).configured(
                screen: screen,
                mode: .recordingArea,
                onCompleteRect: { [weak self] quartzRect in
                    self?.closeAllOverlays()
                    let appKitRect = ScreenCoordinateSpace.appKitRect(fromQuartz: quartzRect)
                    let w = Int(appKitRect.width)
                    let h = Int(appKitRect.height)
                    let evenRect = CGRect(
                        x: appKitRect.origin.x,
                        y: appKitRect.origin.y,
                        width: CGFloat(max(160, w - (w % 2))),
                        height: CGFloat(max(120, h - (h % 2)))
                    )
                    self?.enterRecordingSetup(appKitRect: evenRect)
                },
                onCompleteWindow: { _ in },
                onCancel: { [weak self] in
                    self?.closeAllOverlays()
                }
            )
        }
        presentOverlays(overlays)
    }
    
    // MARK: - Режим подготовки к записи (Setup / Adjustment Mode)
    
    public func enterRecordingSetup(appKitRect: CGRect) {
        closeAllOverlays()
        cleanupRecordingSession()
        
        isRecordingPreparing = true
        isRecording = false
        recordingRect = appKitRect
        
        // Создаем и показываем мягкое затемнение экрана вокруг рамки
        setupRecordingDimWindows(holeRect: appKitRect)
        
        let frameWin = RecordingFrameWindow(
            screenRect: appKitRect,
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
        frameWin.orderFrontRegardless()
        recordingFrameWindow = frameWin
        
        let barWin = RecordingControlBarWindow(
            initialPosition: calculateBarCenter(for: appKitRect),
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
                if self?.isRecording == true {
                    self?.cancelScreenRecording()
                } else {
                    self?.cancelRecordingSetup()
                }
            }
        )
        barWin.orderFrontRegardless()
        recordingBarWindow = barWin
    }
    
    public func applyPresetRect(_ rect: CGRect) {
        let w = Int(rect.width)
        let h = Int(rect.height)
        let evenRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: CGFloat(w - (w % 2)),
            height: CGFloat(h - (h % 2))
        )
        recordingRect = evenRect
        recordingFrameWindow?.updateFrame(evenRect)
        repositionRecordingBar(relativeTo: evenRect)
        updateRecordingDimHole(evenRect)
    }
    
    public func selectNewRecordingArea() {
        recordingDimWindows.forEach { $0.orderOut(nil) }
        recordingFrameWindow?.orderOut(nil)
        recordingBarWindow?.orderOut(nil)
        
        beginOverlaySession()
        let screens = activeScreens()
        guard !screens.isEmpty else {
            recordingDimWindows.forEach { $0.orderFrontRegardless() }
            recordingFrameWindow?.orderFrontRegardless()
            recordingBarWindow?.orderFrontRegardless()
            return
        }
        
        let overlays = screens.map { screen in
            acquireOverlay(for: screen).configured(
                screen: screen,
                mode: .recordingArea,
                onCompleteRect: { [weak self] quartzRect in
                    self?.closeAllOverlays()
                    let appKitRect = ScreenCoordinateSpace.appKitRect(fromQuartz: quartzRect)
                    let w = Int(appKitRect.width)
                    let h = Int(appKitRect.height)
                    let evenRect = CGRect(
                        x: appKitRect.origin.x,
                        y: appKitRect.origin.y,
                        width: CGFloat(w - (w % 2)),
                        height: CGFloat(h - (h % 2))
                    )
                    self?.enterRecordingSetup(appKitRect: evenRect)
                },
                onCompleteWindow: { _ in },
                onCancel: { [weak self] in
                    self?.closeAllOverlays()
                    self?.recordingDimWindows.forEach { $0.orderFrontRegardless() }
                    self?.recordingFrameWindow?.orderFrontRegardless()
                    self?.recordingBarWindow?.orderFrontRegardless()
                }
            )
        }
        presentOverlays(overlays)
    }
    
    public func cancelRecordingSetup() {
        isRecordingPreparing = false
        clearRecordingDimWindows()
        
        recordingFrameWindow?.orderOut(nil)
        recordingFrameWindow = nil
        recordingBarWindow?.orderOut(nil)
        recordingBarWindow = nil
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
        recordingBarWindow?.orderFrontRegardless()
    }
    
    func clearRecordingDimWindows() {
        for win in recordingDimWindows {
            win.orderOut(nil)
        }
        recordingDimWindows.removeAll()
    }
    
    // MARK: - Запуск активной записи (Active Recording)
    
    public func startActiveRecording() {
        guard isRecordingPreparing else { return }
        
        let rectToRecord = recordingRect
        AppSettings.shared.lastRecordingRect = rectToRecord
        
        let countdownSec = AppSettings.shared.recordingCountdownSeconds
        if countdownSec > 0 {
            let center = CGPoint(x: rectToRecord.midX, y: rectToRecord.midY)
            let countdown = CountdownOverlayWindow(seconds: countdownSec, centerPoint: center) { [weak self] in
                Task { [weak self] in
                    await self?.beginActiveRecording(appKitRect: rectToRecord)
                }
            }
            countdown.makeKeyAndOrderFront(nil)
        } else {
            Task { [weak self] in
                await self?.beginActiveRecording(appKitRect: rectToRecord)
            }
        }
    }
    
    private func beginActiveRecording(appKitRect: CGRect) async {
        let moviesDir = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        let outputURL = moviesDir.appendingPathComponent("ScreenRecording-\(Int(Date().timeIntervalSince1970)).mp4")
        
        let quartzRect = ScreenCoordinateSpace.quartzRect(fromAppKit: appKitRect)
        
        recordingFrameWindow?.setMode(.recording)
        
        // Синхронизируем затемнение экрана при начале записи
        if AppSettings.shared.dimOutsideRecordingArea {
            syncRecordingDimWindows(holeRect: appKitRect)
        } else {
            clearRecordingDimWindows()
        }
        
        if AppSettings.shared.showClicksDuringRecording || AppSettings.shared.showKeystrokesDuringRecording {
            let effectsWin = RecordingEffectsOverlayWindow(screenRect: appKitRect)
            effectsWin.orderFrontRegardless()
            recordingEffectsWindow = effectsWin
        }
        
        do {
            try await ScreenRecorderService.shared.startRecording(rect: quartzRect, destinationURL: outputURL)
            isRecording = true
            isRecordingPreparing = false
            isRecordingPaused = false
            recordingDuration = 0
            recordingStartedAt = Date()
            recordingPausedAt = nil
            recordingAccumulatedPause = 0
            
            if AppSettings.shared.playSound {
                NSSound(named: "Purr")?.play()
            }
            
            recordingBarWindow?.updateForRecordingMode()
            repositionRecordingBar(relativeTo: appKitRect)
            
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tickRecordingDuration()
                }
            }
        } catch {
            cleanupRecordingSession()
            showRecordingError(error.localizedDescription)
        }
    }
    
    // MARK: - Пауза, возобновление, остановка
    
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
        isRecordingPreparing = false
        isRecordingPaused = false
        recordingStartedAt = nil
        recordingPausedAt = nil
        recordingAccumulatedPause = 0
        
        clearRecordingDimWindows()
        
        recordingFrameWindow?.orderOut(nil)
        recordingFrameWindow = nil
        
        recordingEffectsWindow?.orderOut(nil)
        recordingEffectsWindow = nil
        
        recordingBarWindow?.orderOut(nil)
        recordingBarWindow = nil
    }
    
    // MARK: - Вспомогательные методы
    
    private func determineInitialRecordingRect() -> CGRect {
        if let saved = AppSettings.shared.lastRecordingRect {
            let matchesScreen = NSScreen.screens.contains(where: { $0.frame.intersects(saved) })
            if matchesScreen, saved.width >= 160, saved.height >= 120 {
                let w = Int(saved.width)
                let h = Int(saved.height)
                return CGRect(
                    x: saved.origin.x,
                    y: saved.origin.y,
                    width: CGFloat(w - (w % 2)),
                    height: CGFloat(h - (h % 2))
                )
            }
        }
        
        let mouseLoc = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        
        guard let screen = targetScreen else {
            return CGRect(x: 100, y: 100, width: 1280, height: 720)
        }
        
        let sf = screen.frame
        let targetW = min(1280, max(640, CGFloat(Int(sf.width * 0.7) / 2 * 2)))
        let targetH = min(720, max(400, CGFloat(Int(sf.height * 0.7) / 2 * 2)))
        
        let x = sf.midX - targetW / 2
        let y = sf.midY - targetH / 2
        return CGRect(x: x, y: y, width: targetW, height: targetH)
    }
    
    func repositionRecordingBar(relativeTo rect: CGRect) {
        guard let barWin = recordingBarWindow else { return }
        let center = calculateBarCenter(for: rect)
        barWin.updatePosition(center: center)
    }
    
    func calculateBarCenter(for rect: CGRect) -> NSPoint {
        var barCenter = NSPoint(x: rect.midX, y: rect.minY - 40)
        if barCenter.y < 60 {
            barCenter.y = rect.maxY + 40
        }
        
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(barCenter, $0.frame, false) })
            ?? NSScreen.screens.first(where: { $0.frame.intersects(rect) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        
        if let targetScreen {
            let halfW: CGFloat = 350
            let minX = targetScreen.frame.minX + halfW + 10
            let maxX = targetScreen.frame.maxX - halfW - 10
            barCenter.x = max(minX, min(maxX, barCenter.x))
            let minY = targetScreen.frame.minY + 38
            let maxY = targetScreen.frame.maxY - 38
            barCenter.y = max(minY, min(maxY, barCenter.y))
        }
        return barCenter
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
