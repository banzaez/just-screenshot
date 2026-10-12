import AppKit
import ScreenCaptureKit

extension AppWindowManager {
    // MARK: - Оверлеи выбора
    
    public func startWindowCapture() {
        if !ScreenCaptureService.shared.hasScreenCapturePermission() {
            Task { [weak self] in
                guard let self else { return }
                let granted = await ScreenCaptureService.shared.checkAndRequestPermissions()
                if !granted {
                    ScreenCaptureService.shared.showPermissionAlert()
                    return
                }
                self.startWindowCapture()
            }
            return
        }
        
        Task { [weak self] in
            guard let self else { return }
            self.closeAllOverlays()
            let screens = NSScreen.screens.isEmpty ? (NSScreen.main.map { [$0] } ?? []) : NSScreen.screens
            guard !screens.isEmpty else { return }
            let token = UUID()
            self.overlayToken = token
            
            let windows = (try? await ScreenCaptureService.shared.getVisibleWindows()) ?? []
            guard self.overlayToken == token else { return }
            self.closeAllOverlays()
            
            let overlays = screens.map { screen in
                AreaOverlayWindow(
                    screen: screen, mode: .windowOnly, visibleWindows: windows,
                    onCompleteRect: { _ in },
                    onCompleteWindow: { [weak self] scWindow in
                        self?.closeAllOverlays()
                        Task { [weak self] in await self?.captureWindowAndShowHUD(scWindow: scWindow) }
                    },
                    onCancel: { [weak self] in self?.closeAllOverlays() }
                )
            }
            self.presentOverlays(overlays)
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
        
        // Быстрая синхронная проверка разрешений без задержек и переходов Task
        if !ScreenCaptureService.shared.hasScreenCapturePermission() {
            Task { [weak self] in
                guard let self else { return }
                let granted = await ScreenCaptureService.shared.checkAndRequestPermissions()
                if !granted {
                    ScreenCaptureService.shared.showPermissionAlert()
                    return
                }
                self.startAreaCapture(delaySeconds: 0)
            }
            return
        }
        
        self.closeAllOverlays()
        let screens = NSScreen.screens.isEmpty ? (NSScreen.main.map { [$0] } ?? []) : NSScreen.screens
        guard !screens.isEmpty else { return }
        
        let token = UUID()
        self.overlayToken = token
        
        let overlays = screens.map { screen in
            AreaOverlayWindow(
                screen: screen, mode: .areaOnly, visibleWindows: [],
                backgroundImage: nil,
                onCompleteRect: { [weak self] rect in
                    guard let self else { return }
                    let overlayIDs = self.overlayWindows.compactMap { $0.windowNumber > 0 ? CGWindowID($0.windowNumber) : nil }
                    self.closeAllOverlays()
                    Task { [weak self] in
                        await self?.captureRectAndShowHUD(rect: rect, excludingWindowIDs: overlayIDs)
                    }
                },
                onCompleteWindow: { _ in },
                onCancel: { [weak self] in self?.closeAllOverlays() }
            )
        }
        self.presentOverlays(overlays)
        
        // Фоновый захват экрана для лупы/пипетки на экране с курсором мыши без задержки отображения
        let mouseLoc = NSEvent.mouseLocation
        let activeScreen = screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? screens.first!
        let activeOverlay = overlays.first(where: { $0.frame == activeScreen.frame })
        
        Task { [weak self, weak activeOverlay] in
            let bgImage = try? await ScreenCaptureService.shared.captureScreenWithSCK(screen: activeScreen)
            guard let self, self.overlayToken == token, let bgImage, let activeOverlay else { return }
            
            Task.detached(priority: .userInitiated) {
                let sampler = ScreenPixelSampler(image: bgImage)
                await MainActor.run { [weak activeOverlay] in
                    activeOverlay?.updateSampler(sampler)
                }
            }
        }
    }
    
    /// Повтор захвата предыдущей области экрана (Repeat Last Capture)
    public func repeatLastCapture() {
        guard let rect = AppSettings.shared.lastCapturedRect else {
            // Если область еще не была зафиксирована, запускаем обычный выбор
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
    
    func presentOverlays(_ windows: [AreaOverlayWindow]) {
        self.overlayWindows = windows
        for window in windows {
            window.isReleasedWhenClosed = false
            window.orderFrontRegardless()
        }
        let mouseLoc = NSEvent.mouseLocation
        if let targetWin = windows.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? windows.first {
            targetWin.makeKey()
        }
        NSApp.activate()
    }
    
    func presentOverlay(_ window: AreaOverlayWindow) {
        presentOverlays([window])
    }
    
    func closeAllOverlays() {
        let windows = overlayWindows
        overlayWindows.removeAll()
        for w in windows {
            w.alphaValue = 0
            w.orderOut(nil)
            w.contentView = nil
            w.close()
        }
        CATransaction.flush()
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
