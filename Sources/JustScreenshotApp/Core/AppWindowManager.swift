import SwiftUI
import AppKit
import Carbon
import ScreenCaptureKit

/// Главный контроллер интерфейса: оверлеи выбора, стек HUD, редакторы, история, закрепы, запись
@MainActor
public final class AppWindowManager: ObservableObject {
    public static let shared = AppWindowManager()
    
    @Published public var currentCapturedItem: CapturedItem?
    @Published public var isRecording: Bool = false
    @Published public var isRecordingPaused: Bool = false
    @Published public var recordingDuration: TimeInterval = 0
    
    private var overlayWindow: AreaOverlayWindow?
    private var overlayToken = UUID()
    private var recordingFrameWindow: RecordingFrameWindow?
    private var recordingBarWindow: RecordingControlBarWindow?
    private let hudStack = HUDStackManager()
    private var editors: [UUID: ManagedWindow] = [:]
    private var pins: [UUID: ManagedWindow] = [:]
    private var historyWindow: ManagedWindow?
    private var cascadePoint = NSPoint.zero
    private var recordingTimer: Timer?
    
    private let history = HistoryStore.shared
    
    private init() {
        setupGlobalHotkeys()
    }
    
    // MARK: - Горячие клавиши
    
    private func setupGlobalHotkeys() {
        let cmdShift: UInt32 = UInt32(cmdKey | shiftKey)
        let hk = GlobalHotKeyManager.shared
        hk.register(id: 1, keyCode: UInt32(kVK_ANSI_3), modifiers: cmdShift) { [weak self] in self?.toggleRecording() }
        hk.register(id: 2, keyCode: UInt32(kVK_ANSI_4), modifiers: cmdShift) { [weak self] in self?.startWindowCapture() }
        hk.register(id: 3, keyCode: UInt32(kVK_ANSI_W), modifiers: cmdShift) { [weak self] in self?.startWindowCapture() }
        hk.register(id: 4, keyCode: UInt32(kVK_ANSI_5), modifiers: cmdShift) { [weak self] in self?.startAreaCapture() }
        hk.register(id: 5, keyCode: UInt32(kVK_ANSI_H), modifiers: cmdShift) { [weak self] in self?.showHistory() }
    }
    
    public func toggleRecording() {
        if isRecording { stopScreenRecording() } else { startScreenRecording() }
    }
    
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
    
    public func startAreaCapture() {
        Task { [weak self] in
            guard let self else { return }
            let hasPerm = await ScreenCaptureService.shared.ensurePermission()
            guard hasPerm else { return }
            
            self.closeAllOverlays()
            guard let screen = NSScreen.main else { return }
            self.overlayToken = UUID()
            self.presentOverlay(
                AreaOverlayWindow(
                    screen: screen, mode: .areaOnly, visibleWindows: [],
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
    
    public func startScreenRecording() {
        Task { [weak self] in
            guard let self else { return }
            let hasPerm = await ScreenCaptureService.shared.ensurePermission()
            guard hasPerm else { return }
            
            self.closeAllOverlays()
            guard let screen = NSScreen.main else { return }
            self.overlayToken = UUID()
            self.presentOverlay(
                AreaOverlayWindow(
                    screen: screen, mode: .recordingArea, visibleWindows: [],
                    onCompleteRect: { [weak self] rect in
                        self?.closeAllOverlays()
                        Task { [weak self] in await self?.beginRecordingArea(rect: rect) }
                    },
                    onCompleteWindow: { _ in },
                    onCancel: { [weak self] in self?.closeAllOverlays() }
                )
            )
        }
    }
    
    private func presentOverlay(_ window: AreaOverlayWindow) {
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        overlayWindow = window
    }
    
    private func closeAllOverlays() {
        guard let w = overlayWindow else { return }
        overlayWindow = nil
        w.orderOut(nil)
        w.contentView = nil
        w.close()
    }
    
    // MARK: - Захват
    
    private func captureRectAndShowHUD(rect: CGRect) async {
        do {
            let image = try await ScreenCaptureService.shared.captureRect(rect)
            processCapturedItem(CapturedItem(image: image, rect: rect))
        } catch {
            print("Capture error: \(error.localizedDescription)")
        }
    }
    
    private func captureWindowAndShowHUD(scWindow: SCWindow) async {
        do {
            let image = try await ScreenCaptureService.shared.captureWindow(windowID: CGWindowID(scWindow.windowID))
            processCapturedItem(CapturedItem(image: image, rect: scWindow.frame))
        } catch {
            print("Capture window error: \(error.localizedDescription)")
        }
    }
    
    private func processCapturedItem(_ item: CapturedItem) {
        currentCapturedItem = item
        ImageExporter.copyToClipboard(item.image)
        history.add(item.image, id: item.id)
        NSSound(named: "Screen Capture")?.play()
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
    
    // MARK: - Редакторы (можно открывать несколько одновременно)
    
    public func openAnnotationEditor(item: CapturedItem) {
        if let existing = editors[item.id] {
            existing.bringToFront()
            return
        }
        
        let id = item.id
        let model = AnnotationEditorModel(capturedItem: item)
        let view = AnnotationEditorWindowView(
            model: model,
            onSave: { [weak self] finalImage in
                if ImageExporter.saveImageWithDialog(finalImage, defaultName: "Annotated") {
                    self?.history.add(finalImage)
                    model.markSaved()
                }
            },
            onSaveToHistory: { [weak self] finalImage in
                self?.history.add(finalImage)
                model.markSaved()
            },
            onClose: { [weak self] in self?.closeEditor(id: id) }
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Редактор — \(Int(item.image.size.width)) × \(Int(item.image.size.height))"
        window.minSize = NSSize(width: 640, height: 460)
        window.contentView = NSHostingView(rootView: view)
        
        if editors.isEmpty {
            window.center()
            cascadePoint = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        }
        cascadePoint = window.cascadeTopLeft(from: cascadePoint)
        
        let managed = ManagedWindow(window: window) { [weak self] closed in
            self?.editors = self?.editors.filter { $0.value !== closed } ?? [:]
        }
        
        managed.shouldClose = { [weak self, weak window] _ in
            guard let self, let window else { return true }
            return self.confirmCloseIfNeeded(model: model, window: window)
        }
        
        editors[id] = managed
        managed.bringToFront()
    }
    
    private func confirmCloseIfNeeded(model: AnnotationEditorModel, window: NSWindow) -> Bool {
        guard model.hasUnsavedChanges else { return true }
        
        let alert = NSAlert()
        alert.messageText = "Сохранить изменения в историю перед закрытием?"
        alert.informativeText = "В редакторе есть несохранённые аннотации или изменения оформления."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Сохранить")      // NSApplication.ModalResponse.alertFirstButtonReturn
        alert.addButton(withTitle: "Не сохранять")   // NSApplication.ModalResponse.alertSecondButtonReturn
        alert.addButton(withTitle: "Отмена")         // NSApplication.ModalResponse.alertThirdButtonReturn
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            let finalImage = model.renderFinalImage()
            self.history.add(finalImage)
            model.markSaved()
            return true
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }
    
    private func closeEditor(id: UUID) {
        guard let managed = editors[id] else { return }
        // Эмулируем стандартный запрос закрытия окна, вызывающий windowShouldClose
        if managed.windowShouldClose(managed.window) {
            editors.removeValue(forKey: id)
            managed.closeSilently()
        }
    }
    
    // MARK: - История
    
    public func showHistory() {
        if let existing = historyWindow {
            existing.bringToFront()
            return
        }
        let view = HistoryWindowView(
            onEdit: { [weak self] entry in self?.editHistoryEntry(entry) },
            onPin: { [weak self] entry in
                guard let self, let img = self.history.image(for: entry) else { return }
                self.pin(image: img, id: entry.id)
            },
            onCopy: { [weak self] entry in
                if let img = self?.history.image(for: entry) { ImageExporter.copyToClipboard(img) }
            }
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "История снимков"
        window.minSize = NSSize(width: 560, height: 400)
        window.contentView = NSHostingView(rootView: view)
        window.center()
        
        let managed = ManagedWindow(window: window) { [weak self] _ in self?.historyWindow = nil }
        historyWindow = managed
        managed.bringToFront()
    }
    
    public func editHistoryEntry(_ entry: HistoryEntry) {
        guard let image = history.image(for: entry) else { return }
        openAnnotationEditor(item: CapturedItem(id: entry.id, image: image, timestamp: entry.date, rect: .zero))
    }
    
    // MARK: - Открыть изображение / из буфера
    
    public func openImageFromDisk() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let image = NSImage(contentsOf: url) else { continue }
            openAnnotationEditor(item: CapturedItem(image: image, rect: .zero))
        }
    }
    
    public func openImageFromClipboard() {
        guard let image = NSImage(pasteboard: .general) else {
            NSSound.beep()
            return
        }
        openAnnotationEditor(item: CapturedItem(image: image, rect: .zero))
    }
    
    // MARK: - Закрепление поверх окон
    
    public func pin(image: NSImage, id: UUID) {
        let pinID = UUID()
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let scale = min(1, (visible.width * 0.6) / image.size.width, (visible.height * 0.6) / image.size.height)
        let size = NSSize(width: max(120, image.size.width * scale), height: max(80, image.size.height * scale))
        let offset = CGFloat(pins.count % 8) * 28
        let origin = NSPoint(x: visible.midX - size.width / 2 + offset, y: visible.midY - size.height / 2 - offset)
        
        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .resizable], backing: .buffered, defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.aspectRatio = size
        window.minSize = NSSize(width: 100, height: 70)
        
        window.contentView = NSHostingView(rootView: PinnedImageView(
            image: image,
            onClose: { [weak self] in self?.closePin(id: pinID) },
            onEdit: { [weak self] in self?.openAnnotationEditor(item: CapturedItem(image: image, rect: .zero)) }
        ))
        
        let managed = ManagedWindow(window: window) { [weak self] closed in
            self?.pins = self?.pins.filter { $0.value !== closed } ?? [:]
        }
        pins[pinID] = managed
        window.orderFrontRegardless()
    }
    
    private func closePin(id: UUID) {
        guard let managed = pins.removeValue(forKey: id) else { return }
        managed.closeSilently()
    }
    
    // MARK: - OCR
    
    private func recognizeText(in image: NSImage, completion: @escaping (String) -> Void) {
        Task { @MainActor in
            let text = await TextRecognizer.recognize(in: image)
            if !text.isEmpty { ImageExporter.copyText(text) }
            completion(text)
        }
    }
    
    // MARK: - Запись экрана
    
    private func beginRecordingArea(rect: CGRect) async {
        let moviesDir = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        let outputURL = moviesDir.appendingPathComponent("ScreenRecording-\(Int(Date().timeIntervalSince1970)).mp4")
        
        do {
            try await ScreenRecorderService.shared.startRecording(rect: rect, destinationURL: outputURL)
            isRecording = true
            isRecordingPaused = false
            recordingDuration = 0
            NSSound(named: "Purr")?.play()
            
            // Преобразуем координаты ScreenCaptureKit (origin вверху основного экрана) в координаты AppKit
            let screenHeight = NSScreen.main?.frame.height ?? 900
            let appKitRect = NSRect(
                x: rect.origin.x,
                y: screenHeight - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            )
            
            // 1. Показываем рамку выделения области
            let frameWin = RecordingFrameWindow(screenRect: appKitRect)
            frameWin.orderFrontRegardless()
            self.recordingFrameWindow = frameWin
            
            // 2. Вычисляем позицию для плавающей панели снизу области
            var barCenter = NSPoint(x: appKitRect.midX, y: appKitRect.minY - 35)
            // Если панель выходит за нижний край экрана, показываем её внутри внизу области
            if barCenter.y < 40 {
                barCenter.y = appKitRect.minY + 35
            }
            // Предотвращаем выход за левый и правый края
            let minX: CGFloat = 160
            let maxX: CGFloat = (NSScreen.main?.frame.width ?? 1440) - 160
            barCenter.x = max(minX, min(maxX, barCenter.x))
            
            let barWin = RecordingControlBarWindow(
                initialPosition: barCenter,
                windowManager: self,
                onPauseResume: { [weak self] in self?.togglePauseResumeScreenRecording() },
                onStop: { [weak self] in self?.stopScreenRecording() },
                onCancel: { [weak self] in self?.cancelScreenRecording() }
            )
            barWin.orderFrontRegardless()
            self.recordingBarWindow = barWin
            
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isRecording, !self.isRecordingPaused else { return }
                    self.recordingDuration += 1
                }
            }
        } catch {
            print("Recording start failed: \(error.localizedDescription)")
        }
    }
    
    public func togglePauseResumeScreenRecording() {
        guard isRecording else { return }
        if isRecordingPaused {
            ScreenRecorderService.shared.resumeRecording()
            isRecordingPaused = false
        } else {
            ScreenRecorderService.shared.pauseRecording()
            isRecordingPaused = true
        }
    }
    
    public func stopScreenRecording() {
        cleanupRecordingSession()
        
        Task {
            if let savedURL = try? await ScreenRecorderService.shared.stopRecording() {
                NSWorkspace.shared.activateFileViewerSelecting([savedURL])
            }
        }
    }
    
    public func cancelScreenRecording() {
        cleanupRecordingSession()
        
        Task {
            await ScreenRecorderService.shared.cancelRecording()
        }
    }
    
    private func cleanupRecordingSession() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        isRecordingPaused = false
        
        recordingFrameWindow?.orderOut(nil)
        recordingFrameWindow = nil
        
        recordingBarWindow?.orderOut(nil)
        recordingBarWindow = nil
    }
}
