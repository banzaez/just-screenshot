import AppKit

extension AppWindowManager {
    // MARK: - Overlay pool / presentation
    
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
}
