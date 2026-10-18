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
        if delaySeconds > 0 {
            let countdown = CountdownOverlayWindow(seconds: delaySeconds) { [weak self] in
                self?.startAreaCapture(delaySeconds: 0)
            }
            countdown.makeKeyAndOrderFront(nil)
            return
        }
        
        Task { [weak self] in
            guard let self else { return }
            guard await ScreenCaptureService.shared.ensurePermission() else { return }
            self.presentAreaOverlays()
        }
    }
    
    private func presentAreaOverlays() {
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
                    Task { [weak self] in
                        await self?.captureRectAndShowHUD(rect: rect, excludingWindowIDs: overlayIDs)
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
