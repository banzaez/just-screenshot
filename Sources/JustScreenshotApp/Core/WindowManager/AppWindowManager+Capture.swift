import AppKit
import ScreenCaptureKit

extension AppWindowManager {
    // MARK: - Оверлеи выбора
    
    public func startWindowCapture() {
        Task { [weak self] in
            guard let self else { return }
            guard await ScreenCaptureService.shared.ensurePermission() else { return }
            self.presentWindowOverlays()
        }
    }
    
    private func presentWindowOverlays() {
        let token = beginOverlaySession()
        let screens = activeScreens()
        guard !screens.isEmpty else { return }
        
        let overlays = screens.map { screen in
            acquireOverlay(for: screen).configured(
                screen: screen,
                mode: .windowOnly,
                onCompleteRect: { _ in },
                onCompleteWindow: { [weak self] scWindow in
                    self?.closeAllOverlays()
                    Task { [weak self] in await self?.captureWindowAndShowHUD(scWindow: scWindow) }
                },
                onCancel: { [weak self] in self?.closeAllOverlays() }
            )
        }
        presentOverlays(overlays)
        
        Task { [weak self] in
            let windows = (try? await ScreenCaptureService.shared.getVisibleWindows()) ?? []
            guard let self, self.overlayToken == token else { return }
            for overlay in overlays { overlay.updateVisibleWindows(windows) }
        }
    }
    

    public func startAreaCapture(delaySeconds: Int = 0) {
        Task { [weak self] in
            guard let self else { return }
            guard await ScreenCaptureService.shared.ensurePermission() else { return }
            self.presentAreaOverlays(delaySeconds: delaySeconds)
        }
    }
    
    private func presentAreaOverlays(delaySeconds: Int = 0) {
        let token = beginOverlaySession()
        let screens = activeScreens()
        guard !screens.isEmpty else { return }
        
        let overlays = screens.map { screen -> AreaOverlayWindow in
            let overlay = acquireOverlay(for: screen)
            return overlay.configured(
                screen: screen,
                mode: .areaOnly,
                onCompleteRect: { [weak self] rect in
                    guard let self else { return }
                    let overlayIDs = self.overlayWindows.compactMap {
                        $0.windowNumber > 0 ? CGWindowID($0.windowNumber) : nil
                    }
                    self.closeAllOverlays()
                    
                    if delaySeconds > 0 {
                        self.startTimedAreaCountdown(
                            rect: rect,
                            excludingWindowIDs: overlayIDs,
                            seconds: delaySeconds
                        )
                    } else {
                        Task { [weak self] in
                            await self?.captureRectAndShowHUD(rect: rect, excludingWindowIDs: overlayIDs)
                        }
                    }
                },
                onCompleteWindow: { _ in },
                onCancel: { [weak self] in self?.closeAllOverlays() },
                onNeedBackgroundSample: { [weak self, weak overlay] in
                    guard let self, let overlay else { return }
                    self.ensureSampler(for: overlay, token: token)
                }
            )
        }
        presentOverlays(overlays)
        
        // Сразу только экран под курсором — остальные по mouseEntered.
        if let primary = overlays.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? overlays.first {
            ensureSampler(for: primary, token: token)
        }
    }
    
    /// Отсчет таймера после разметки области с сохранением затемнения и возможностью отмены по Esc
    private func startTimedAreaCountdown(
        rect: CGRect,
        excludingWindowIDs: [CGWindowID],
        seconds: Int
    ) {
        let appKitRect = ScreenCoordinateSpace.appKitRect(fromQuartz: rect)
        
        // 1. Показываем аппаратное затемнение экрана вокруг выбранной области (cutout)
        let screens = activeScreens()
        let dimWindows = screens.map { screen in
            let win = RecordingDimOverlayWindow(screen: screen, holeRect: appKitRect)
            win.orderFrontRegardless()
            return win
        }
        
        var captureExcludingIDs = excludingWindowIDs
        for win in dimWindows where win.windowNumber > 0 {
            captureExcludingIDs.append(CGWindowID(win.windowNumber))
        }
        
        // 2. Показываем виджет обратного отсчета по центру выбранной области
        let center = CGPoint(x: appKitRect.midX, y: appKitRect.midY)
        
        var isCancelled = false
        var isCleanedUp = false
        var escGlobalMonitor: Any?
        var escLocalMonitor: Any?
        var countdownWindow: CountdownOverlayWindow?
        
        let cleanup: @MainActor () -> Void = {
            guard !isCleanedUp else { return }
            isCleanedUp = true
            
            if let gMon = escGlobalMonitor {
                NSEvent.removeMonitor(gMon)
                escGlobalMonitor = nil
            }
            if let lMon = escLocalMonitor {
                NSEvent.removeMonitor(lMon)
                escLocalMonitor = nil
            }
            for win in dimWindows {
                win.orderOut(nil)
                win.close()
            }
            if let cw = countdownWindow {
                cw.orderOut(nil)
                cw.close()
                countdownWindow = nil
            }
        }
        
        // 3. Отмена по Escape (глобально и локально)
        escGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in
                    isCancelled = true
                    cleanup()
                }
            }
        }
        escLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in
                    isCancelled = true
                    cleanup()
                }
                return nil
            }
            return event
        }
        
        countdownWindow = CountdownOverlayWindow(seconds: seconds, centerPoint: center) { [weak self] in
            Task { @MainActor [weak self] in
                guard !isCancelled else { return }
                cleanup()
                guard let self else { return }
                // 50мс пауза для надежного завершения композитинга WindowServer без оверлеев
                try? await Task.sleep(nanoseconds: 50_000_000)
                await self.captureRectAndShowHUD(rect: rect, excludingWindowIDs: captureExcludingIDs)
            }
        }
        if let cw = countdownWindow, cw.windowNumber > 0 {
            captureExcludingIDs.append(CGWindowID(cw.windowNumber))
        }
        countdownWindow?.orderFrontRegardless()
    }
    
    /// Повтор захвата предыдущей области экрана (Repeat Last Capture)
    public func repeatLastCapture() {
        guard let rect = AppSettings.shared.lastCapturedRect else {
            startAreaCapture()
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let hasPerm = await ScreenCaptureService.shared.ensurePermission()
            guard hasPerm else { return }
            await self.captureRectAndShowHUD(rect: rect)
        }
    }
    
    // MARK: - Захват
    
    func captureRectAndShowHUD(rect: CGRect, excludingWindowIDs: [CGWindowID] = []) async {
        do {
            AppSettings.shared.lastCapturedRect = rect
            let image = try await ScreenCaptureService.shared.captureRect(rect, excludingWindowIDs: excludingWindowIDs)
            processCapturedItem(CapturedItem(image: image, rect: rect))
        } catch {
            print("Capture error: \(error.localizedDescription)")
        }
    }
    
    func captureWindowAndShowHUD(scWindow: SCWindow) async {
        do {
            let image = try await ScreenCaptureService.shared.captureWindow(windowID: CGWindowID(scWindow.windowID))
            processCapturedItem(CapturedItem(image: image, rect: scWindow.frame))
        } catch {
            print("Capture window error: \(error.localizedDescription)")
        }
    }
    
    func processCapturedItem(_ item: CapturedItem) {
        currentCapturedItem = item
        if AppSettings.shared.copyToClipboardOnCapture {
            ImageExporter.copyToClipboard(item.image)
        }
        history.add(item.image, id: item.id)
        if AppSettings.shared.playSound {
            NSSound(named: "Screen Capture")?.play()
        }
        showQuickAccessHUD(item: item)
    }
    
    // MARK: - HUD
    
    public func showQuickAccessHUD(item: CapturedItem) {
        hudStack.show(
            item: item,
            actions: HUDStackManager.Actions(
                onAnnotate: { [weak self] in self?.openAnnotationEditor(item: item) },
                onSave: { ImageExporter.saveImageWithDialog(item.image, defaultName: "Screenshot") },
                onCopy: { ImageExporter.copyToClipboard(item.image) },
                onPin: { [weak self] in self?.pin(image: item.image, id: item.id) },
                onOCR: { [weak self] completion in self?.recognizeText(in: item.image, completion: completion) }
            )
        )
    }
    
    // MARK: - OCR
    
    func recognizeText(in image: NSImage, completion: @escaping (String) -> Void) {
        Task { @MainActor in
            let text = await TextRecognizer.recognize(in: image)
            if !text.isEmpty { ImageExporter.copyText(text) }
            completion(text)
        }
    }
}
