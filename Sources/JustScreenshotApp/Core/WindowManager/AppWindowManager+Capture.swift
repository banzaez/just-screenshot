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
        
        closeAllOverlays()
        let screens = NSScreen.screens.isEmpty ? (NSScreen.main.map { [$0] } ?? []) : NSScreen.screens
        guard !screens.isEmpty else { return }
        let token = UUID()
        overlayToken = token
        
        let overlays = screens.map { screen in
            AreaOverlayWindow(
                screen: screen, mode: .windowOnly, visibleWindows: [],
                onCompleteRect: { _ in },
                onCompleteWindow: { [weak self] scWindow in
                    self?.closeAllOverlays()
                    Task { [weak self] in await self?.captureWindowAndShowHUD(scWindow: scWindow) }
                },
                onCancel: { [weak self] in self?.closeAllOverlays() }
            )
        }
        presentOverlays(overlays)
        
        // Список окон запрашивается вне главного потока, чтобы оверлей не замирал на время SCShareableContent.
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
        // Сначала экран с курсором, затем остальные
        let mouseLoc = NSEvent.mouseLocation
        let ordered = overlays.sorted { a, _ in NSMouseInRect(mouseLoc, a.frame, false) }
        
        for overlay in ordered {
            guard let screen = overlay.screen else { continue }
            Task { [weak self, weak overlay] in
                guard let bgImage = try? await ScreenCaptureService.shared.captureScreenWithSCK(screen: screen) else { return }
                guard let self, self.overlayToken == token else { return }
                let sampler = await Task.detached(priority: .userInitiated) {
                    ScreenPixelSampler(image: bgImage)
                }.value
                guard self.overlayToken == token else { return }
                overlay?.updateSampler(sampler)
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
        // Активация до makeKey, иначе первый жест уходит на пробуждение приложения.
        NSApp.activate()
        let mouseLoc = NSEvent.mouseLocation
        for window in windows {
            window.isReleasedWhenClosed = false
            window.alphaValue = 1
            window.orderFrontRegardless()
        }
        if let targetWin = windows.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? windows.first {
            targetWin.makeKey()
            targetWin.makeFirstResponder(targetWin.contentView)
        }
    }
    
    func presentOverlay(_ window: AreaOverlayWindow) {
        presentOverlays([window])
    }
    
    func closeAllOverlays() {
        overlayToken = UUID() // отменяет отложенные презентации оверлея
        let windows = overlayWindows
        overlayWindows.removeAll()
        for w in windows {
            w.alphaValue = 0
            w.orderOut(nil)
            w.contentView = nil
            w.close()
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
