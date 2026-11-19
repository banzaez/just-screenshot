import AppKit
import ScreenCaptureKit

extension AppWindowManager {
    // MARK: - Оверлеи выбора

    public func startWindowCapture() {
        guard !overlayState.isCapturePreparing else { return }
        overlayState.isCapturePreparing = true
        Task { [weak self] in
            defer { self?.overlayState.isCapturePreparing = false }
            guard let self else { return }
            guard await ScreenCaptureService.shared.ensurePermission() else { return }
            self.cancelActiveTimedCapture()
            self.presentWindowOverlays()
        }
    }

    private func presentWindowOverlays() {
        guard let session = presentSelectionOverlays(
            mode: .windowOnly,
            needsSampler: false,
            onCompleteRect: { _, _ in },
            onCompleteWindow: { [weak self] scWindow in
                Task { [weak self] in await self?.captureWindowAndShowHUD(scWindow: scWindow) }
            },
            onCancel: {}
        ) else { return }

        let token = session.token
        let overlays = session.overlays
        Task { [weak self] in
            let rawWindows = (try? await ScreenCaptureService.shared.getVisibleWindows()) ?? []
            let sorted = AreaSelectionNSView.sortedFrontToBack(rawWindows)
            guard let self, self.overlayToken == token else { return }
            for overlay in overlays {
                overlay.updateVisibleWindows(sorted, alreadySorted: true)
            }
        }
    }

    public func startAreaCapture(delaySeconds: Int = 0) {
        guard !overlayState.isCapturePreparing else { return }
        overlayState.isCapturePreparing = true
        Task { [weak self] in
            defer { self?.overlayState.isCapturePreparing = false }
            guard let self else { return }
            guard await ScreenCaptureService.shared.ensurePermission() else { return }
            self.cancelActiveTimedCapture()
            self.presentAreaOverlays(delaySeconds: delaySeconds)
        }
    }

    // MARK: - Быстрый захват текста (Text Capture / OCR)

    public func startTextCapture() {
        guard !overlayState.isCapturePreparing else { return }
        overlayState.isCapturePreparing = true
        Task { [weak self] in
            defer { self?.overlayState.isCapturePreparing = false }
            guard let self else { return }
            guard await ScreenCaptureService.shared.ensurePermission() else { return }
            self.cancelActiveTimedCapture()
            self.presentTextCaptureOverlays()
        }
    }

    private func presentTextCaptureOverlays() {
        presentSelectionOverlays(
            mode: .areaOnly,
            needsSampler: true,
            onCompleteRect: { [weak self] rect, overlayIDs in
                Task { [weak self] in
                    await self?.captureRectAndRecognizeText(rect: rect, excludingWindowIDs: overlayIDs)
                }
            },
            onCancel: {}
        )
    }

    private func captureRectAndRecognizeText(rect: CGRect, excludingWindowIDs: [CGWindowID]) async {
        do {
            let image = try await ScreenCaptureService.shared.captureRect(rect, excludingWindowIDs: excludingWindowIDs)
            let text = await TextRecognizer.recognize(in: image)
            if !text.isEmpty {
                ImageExporter.copyText(text)
                SoundEffects.playShutter()
                hudStack.showToast(text: L("hud.ocr_copied", text.count), icon: "text.viewfinder")
            } else {
                NSSound.beep()
                hudStack.showToast(text: L("hud.ocr_not_found"), icon: "text.viewfinder")
            }
        } catch {
            AppLogger.capture.error("Text capture error: \(error.localizedDescription, privacy: .public)")
            hudStack.showToast(text: error.localizedDescription, icon: "exclamationmark.triangle")
        }
    }

    private func presentAreaOverlays(delaySeconds: Int = 0) {
        presentSelectionOverlays(
            mode: .areaOnly,
            needsSampler: true,
            onCompleteRect: { [weak self] rect, overlayIDs in
                guard let self else { return }
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
            onCancel: {}
        )
    }

    public func cancelActiveTimedCapture() {
        timedCaptureSession?.cancelAndClose()
        timedCaptureSession = nil
    }

    /// Отсчет таймера после разметки области с сохранением затемнения и возможностью отмены по Esc
    private func startTimedAreaCountdown(
        rect: CGRect,
        excludingWindowIDs: [CGWindowID],
        seconds: Int
    ) {
        cancelActiveTimedCapture()

        let appKitRect = ScreenCoordinateSpace.appKitRect(fromQuartz: rect)
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

        let center = CGPoint(x: appKitRect.midX, y: appKitRect.midY)
        let escMonitor = EscapeMonitor()

        let countdownWindow = CountdownOverlayWindow(seconds: seconds, centerPoint: center) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let session = self.timedCaptureSession, !session.isCancelled else { return }
                self.cancelActiveTimedCapture()
                // 50мс пауза для надёжного завершения композитинга WindowServer без оверлеев
                try? await Task.sleep(nanoseconds: 50_000_000)
                await self.captureRectAndShowHUD(rect: rect, excludingWindowIDs: captureExcludingIDs)
            }
        }
        if countdownWindow.windowNumber > 0 {
            captureExcludingIDs.append(CGWindowID(countdownWindow.windowNumber))
        }

        let session = TimedCaptureSession(
            dimWindows: dimWindows,
            countdownWindow: countdownWindow,
            escMonitor: escMonitor
        )
        timedCaptureSession = session

        escMonitor.start(includeGlobal: true, useHotKeyFallback: true) { [weak self] in
            self?.cancelActiveTimedCapture()
        }

        NSApp.activate()
        countdownWindow.makeKeyAndOrderFront(nil)
    }

    /// Повтор захвата предыдущей области экрана (Repeat Last Capture)
    public func repeatLastCapture() {
        guard let rect = AppSettings.shared.lastCapturedRect else {
            startAreaCapture()
            return
        }
        guard !overlayState.isCapturePreparing else { return }
        overlayState.isCapturePreparing = true
        Task { [weak self] in
            defer { self?.overlayState.isCapturePreparing = false }
            guard let self else { return }
            guard await ScreenCaptureService.shared.ensurePermission() else { return }
            self.cancelActiveTimedCapture()
            await self.captureRectAndShowHUD(rect: rect)
        }
    }

    // MARK: - Захват

    func captureRectAndShowHUD(rect: CGRect, excludingWindowIDs: [CGWindowID] = []) async {
        do {
            let image = try await ScreenCaptureService.shared.captureRect(rect, excludingWindowIDs: excludingWindowIDs)
            AppSettings.shared.lastCapturedRect = rect
            processCapturedItem(CapturedItem(image: image, rect: rect))
        } catch {
            AppLogger.capture.error("Capture error: \(error.localizedDescription, privacy: .public)")
            hudStack.showToast(text: error.localizedDescription, icon: "exclamationmark.triangle")
        }
    }

    func captureWindowAndShowHUD(scWindow: SCWindow) async {
        do {
            let image = try await ScreenCaptureService.shared.captureWindow(windowID: CGWindowID(scWindow.windowID))
            processCapturedItem(CapturedItem(image: image, rect: scWindow.frame))
        } catch {
            AppLogger.capture.error("Capture window error: \(error.localizedDescription, privacy: .public)")
            hudStack.showToast(text: error.localizedDescription, icon: "exclamationmark.triangle")
        }
    }

    func processCapturedItem(_ item: CapturedItem) {
        let pngData = ImageExporter.pngData(from: item.image)
        if AppSettings.shared.copyToClipboardOnCapture {
            if let pngData {
                ImageExporter.copyToClipboard(pngData: pngData)
            } else {
                ImageExporter.copyToClipboard(item.image)
            }
        }
        history.add(item.image, id: item.id, preencodedPNG: pngData)
        SoundEffects.playShutter()
        showQuickAccessHUD(item: item)
    }

    // MARK: - HUD

    public func showQuickAccessHUD(item: CapturedItem) {
        let cachedThumb = history.cachedThumbnail(for: HistoryEntry(
            id: item.id,
            date: item.timestamp,
            width: Int(item.image.size.width),
            height: Int(item.image.size.height),
            kind: .image
        ))
        hudStack.show(
            item: item,
            thumbnail: cachedThumb,
            actions: HUDStackManager.Actions(
                onAnnotate: { [weak self] in self?.openAnnotationEditor(item: item) },
                onSave: { ImageExporter.saveImageWithDialog(item.image, defaultName: "Screenshot") },
                onCopy: { ImageExporter.copyToClipboard(item.image) },
                onPin: { [weak self] in self?.pin(image: item.image, id: item.id) },
                onOCR: { [weak self] completion in self?.recognizeText(in: item.image, completion: completion) },
                onDelete: { [weak self] in self?.deleteCapturedItem(id: item.id) }
            )
        )
    }

    public func deleteCapturedItem(id: UUID) {
        history.delete(id: id)
        hudStack.dismiss(itemID: id)
        closeEditorSilently(id: id)
        closePinsForItem(id: id)
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
