import AppKit
import ScreenCaptureKit

extension AppWindowManager {
    // MARK: - Overlay pool / presentation

    func activeScreens() -> [NSScreen] {
        NSScreen.screens.isEmpty ? (NSScreen.main.map { [$0] } ?? []) : NSScreen.screens
    }

    func pruneDisconnectedOverlayDisplays() {
        let activeIDs = Set(NSScreen.screens.map(\.displayID))
        let staleIDs = overlayPool.keys.filter { !activeIDs.contains($0) }
        for id in staleIDs {
            if let window = overlayPool.removeValue(forKey: id),
               !overlayWindows.contains(where: { $0 === window }) {
                window.orderOut(nil)
                window.contentView = nil
                window.close()
            }
        }
    }

    @discardableResult
    func beginOverlaySession() -> UUID {
        closeAllOverlays(restoreRecordingSetup: false)
        let token = UUID()
        overlayToken = token
        samplerInFlight.removeAll()
        overlayState.failedSamplerDisplays.removeAll()
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

    /// Единый метод настройки и показа оверлеев выбора по всем мониторам
    @discardableResult
    func presentSelectionOverlays(
        mode: OverlayMode,
        needsSampler: Bool,
        onCompleteRect: @escaping (CGRect, [CGWindowID]) -> Void,
        onCompleteWindow: @escaping (SCWindow) -> Void = { _ in },
        onCancel: @escaping () -> Void
    ) -> (token: UUID, overlays: [AreaOverlayWindow])? {
        let token = beginOverlaySession()
        let screens = activeScreens()
        guard !screens.isEmpty else { return nil }

        let overlays = screens.map { screen -> AreaOverlayWindow in
            let overlay = acquireOverlay(for: screen)
            return overlay.configured(
                screen: screen,
                mode: mode,
                onCompleteRect: { [weak self] rect in
                    guard let self else { return }
                    let overlayIDs = self.overlayWindows.compactMap {
                        $0.windowNumber > 0 ? CGWindowID($0.windowNumber) : nil
                    }
                    self.closeAllOverlays(restoreRecordingSetup: false)
                    onCompleteRect(rect, overlayIDs)
                },
                onCompleteWindow: { [weak self] scWindow in
                    self?.closeAllOverlays(restoreRecordingSetup: false)
                    onCompleteWindow(scWindow)
                },
                onCancel: { [weak self] in
                    self?.closeAllOverlays(restoreRecordingSetup: false)
                    onCancel()
                },
                onNeedBackgroundSample: needsSampler ? { [weak self, weak overlay] in
                    guard let self, let overlay else { return }
                    self.ensureSampler(for: overlay, token: token)
                } : nil
            )
        }
        presentOverlays(overlays, onCancel: onCancel)

        if needsSampler,
           let primary = overlays.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? overlays.first {
            ensureSampler(for: primary, token: token)
        }

        return (token, overlays)
    }

    func presentOverlays(_ windows: [AreaOverlayWindow], onCancel: (() -> Void)? = nil) {
        overlayWindows = windows
        overlayState.escMonitor.start(includeGlobal: true, useHotKeyFallback: true) { [weak self] in
            self?.closeAllOverlays(restoreRecordingSetup: false)
            onCancel?()
        }
        NSApp.activate()

        let mouseLoc = NSEvent.mouseLocation
        for window in windows {
            window.isReleasedWhenClosed = false
            window.alphaValue = 1
            window.orderFrontRegardless()
        }
        if let targetWin = windows.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? windows.first {
            targetWin.makeKeyAndOrderFront(nil)
            targetWin.makeFirstResponder(targetWin.contentView)
        }
    }

    func closeAllOverlays(restoreRecordingSetup: Bool = true) {
        overlayToken = UUID()
        samplerInFlight.removeAll()
        overlayState.failedSamplerDisplays.removeAll()
        overlayState.escMonitor.stop()

        let windows = overlayWindows
        overlayWindows.removeAll()
        for window in windows {
            window.prepareForReuse()
        }

        if restoreRecordingSetup, recordingPhase == .preparing {
            recordingDimWindows.forEach { $0.orderFrontRegardless() }
            recordingFrameWindow?.makeKeyAndOrderFront(nil)
            recordingBarWindow?.orderFrontRegardless()
        }
    }

    func ensureSampler(for overlay: AreaOverlayWindow, token: UUID) {
        let displayID = overlay.screenID
        guard !samplerInFlight.contains(displayID),
              !overlayState.failedSamplerDisplays.contains(displayID) else { return }
        guard let screen = overlay.screen ?? NSScreen.screens.first(where: { $0.displayID == displayID }) else { return }

        samplerInFlight.insert(displayID)
        Task { [weak self, weak overlay] in
            defer {
                Task { @MainActor [weak self] in
                    guard let self, self.overlayToken == token else { return }
                    self.samplerInFlight.remove(displayID)
                }
            }
            do {
                let bgImage = try await ScreenCaptureService.shared.captureScreenWithSCK(screen: screen)
                guard let self, self.overlayToken == token else { return }
                let sampler = await Task.detached(priority: .userInitiated) {
                    ScreenPixelSampler(image: bgImage)
                }.value
                guard self.overlayToken == token else { return }
                overlay?.updateSampler(sampler)
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, self.overlayToken == token else { return }
                    self.overlayState.failedSamplerDisplays.insert(displayID)
                }
                AppLogger.capture.warning("Background pixel sampler failed for display \(displayID): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
