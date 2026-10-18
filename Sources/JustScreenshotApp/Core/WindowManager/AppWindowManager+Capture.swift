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
    
    // MARK: - Pool / presentation
    
    func activeScreens() -> [NSScreen] {
        NSScreen.screens.isEmpty ? (NSScreen.main.map { [$0] } ?? []) : NSScreen.screens
    }
    
    @discardableResult
    func beginOverlaySession() -> UUID {
        closeAllOverlays()
        let token = UUID()
        overlayToken = token
        samplerInFlight.removeAll()
        return token
    }
    
    func acquireOverlay(for screen: NSScreen) -> AreaOverlayWindow {
        if let existing = overlayPool[screen.displayID] {
            return existing
        }
        let window = AreaOverlayWindow(screen: screen)
        overlayPool[screen.displayID] = window
        return window
    }
    
    func presentOverlays(_ windows: [AreaOverlayWindow]) {
        overlayWindows = windows
        installOverlayEscMonitors()
        NSApp.activate(ignoringOtherApps: true)
        
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
        overlayToken = UUID()
        samplerInFlight.removeAll()
        removeOverlayEscMonitors()
        
        let windows = overlayWindows
        overlayWindows.removeAll()
        for window in windows {
            window.prepareForReuse()
        }
    }
    
    func installOverlayEscMonitors() {
        guard overlayEscLocalMonitor == nil else { return }
        overlayEscLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.closeAllOverlays()
                return nil
            }
            return event
        }
        overlayEscGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                DispatchQueue.main.async { self?.closeAllOverlays() }
            }
        }
    }
    
    func removeOverlayEscMonitors() {
        if let monitor = overlayEscLocalMonitor {
            NSEvent.removeMonitor(monitor)
            overlayEscLocalMonitor = nil
        }
        if let monitor = overlayEscGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            overlayEscGlobalMonitor = nil
        }
    }
    
    func ensureSampler(for overlay: AreaOverlayWindow, token: UUID) {
        let displayID = overlay.screenID
        guard !samplerInFlight.contains(displayID) else { return }
        guard let screen = overlay.screen ?? NSScreen.screens.first(where: { $0.displayID == displayID }) else { return }
        
        samplerInFlight.insert(displayID)
        Task { [weak self, weak overlay] in
            defer {
                Task { @MainActor [weak self] in
                    self?.samplerInFlight.remove(displayID)
                }
            }
            guard let bgImage = try? await ScreenCaptureService.shared.captureScreenWithSCK(screen: screen) else { return }
            guard let self, self.overlayToken == token else { return }
            let sampler = await Task.detached(priority: .userInitiated) {
                ScreenPixelSampler(image: bgImage)
            }.value
            guard self.overlayToken == token else { return }
            overlay?.updateSampler(sampler)
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

extension AreaOverlayWindow {
    @discardableResult
    func configured(
        screen: NSScreen,
        mode: OverlayMode,
        onCompleteRect: @escaping (CGRect) -> Void,
        onCompleteWindow: @escaping (SCWindow) -> Void,
        onCancel: @escaping () -> Void,
        onNeedBackgroundSample: (() -> Void)? = nil
    ) -> AreaOverlayWindow {
        configure(
            screen: screen,
            mode: mode,
            visibleWindows: [],
            backgroundImage: nil,
            onCompleteRect: onCompleteRect,
            onCompleteWindow: onCompleteWindow,
            onCancel: onCancel,
            onNeedBackgroundSample: onNeedBackgroundSample
        )
        return self
    }
}
