import AppKit
import ScreenCaptureKit

extension AppWindowManager {
    // MARK: - Оверлеи выбора
    
    public func startWindowCapture() {
        Task { [weak self] in
            guard let self else { return }
            let hasPerm = await ScreenCaptureService.shared.ensurePermission()
            guard hasPerm else { return }
            
            self.closeAllOverlays()
            guard let screen = NSScreen.main else { return }
            let token = UUID()
            self.overlayToken = token
            
            let windows = (try? await ScreenCaptureService.shared.getVisibleWindows()) ?? []
            // Если за время загрузки запущен другой захват — этот оверлей уже не нужен (иначе окна копятся)
            guard self.overlayToken == token else { return }
            self.closeAllOverlays()
            
            self.presentOverlay(
                AreaOverlayWindow(
                    screen: screen, mode: .windowOnly, visibleWindows: windows,
                    onCompleteRect: { _ in },
                    onCompleteWindow: { [weak self] scWindow in
                        self?.closeAllOverlays()
                        Task { [weak self] in await self?.captureWindowAndShowHUD(scWindow: scWindow) }
                    },
                    onCancel: { [weak self] in self?.closeAllOverlays() }
                )
            )
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
            let hasPerm = await ScreenCaptureService.shared.ensurePermission()
            guard hasPerm else { return }
            
            self.closeAllOverlays()
            guard let screen = NSScreen.main else { return }
            self.overlayToken = UUID()
            let bgImage = try? await ScreenCaptureService.shared.captureScreenWithSCK(screen: screen)
            
            self.presentOverlay(
                AreaOverlayWindow(
                    screen: screen, mode: .areaOnly, visibleWindows: [],
                    backgroundImage: bgImage,
                    onCompleteRect: { [weak self] rect in
                        self?.closeAllOverlays()
                        Task { [weak self] in await self?.captureRectAndShowHUD(rect: rect) }
                    },
                    onCompleteWindow: { _ in },
                    onCancel: { [weak self] in self?.closeAllOverlays() }
                )
            )
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
    
    func presentOverlay(_ window: AreaOverlayWindow) {
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        overlayWindow = window
    }
    
    func closeAllOverlays() {
        guard let w = overlayWindow else { return }
        overlayWindow = nil
        w.orderOut(nil)
        w.contentView = nil
        w.close()
    }
    
    // MARK: - Захват
    
    func captureRectAndShowHUD(rect: CGRect) async {
        do {
            AppSettings.shared.lastCapturedRect = rect
            let image = try await ScreenCaptureService.shared.captureRect(rect)
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
