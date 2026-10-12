import AppKit
import SwiftUI

extension AppWindowManager {
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
        window.title = L("editor.title", Int(item.image.size.width), Int(item.image.size.height))
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
    
    func confirmCloseIfNeeded(model: AnnotationEditorModel, window: NSWindow) -> Bool {
        guard model.hasUnsavedChanges else { return true }
        
        let alert = NSAlert()
        alert.messageText = L("alert.unsaved_title")
        alert.informativeText = L("alert.unsaved_informative")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("alert.save"))       // NSApplication.ModalResponse.alertFirstButtonReturn
        alert.addButton(withTitle: L("alert.dont_save"))   // NSApplication.ModalResponse.alertSecondButtonReturn
        alert.addButton(withTitle: L("alert.cancel"))      // NSApplication.ModalResponse.alertThirdButtonReturn
        
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
    
    func closeEditor(id: UUID) {
        guard let managed = editors[id] else { return }
        // Эмулируем стандартный запрос закрытия окна, вызывающий windowShouldClose
        if managed.windowShouldClose(managed.window) {
            editors.removeValue(forKey: id)
            managed.closeSilently()
        }
    }
    
    // MARK: - Видеоредактор
    
    public func openVideoEditor(videoURL: URL) {
        let editorID = UUID()
        let model = VideoEditorModel(videoURL: videoURL)
        let view = VideoEditorWindowView(
            model: model,
            onClose: { [weak self] in self?.closeVideoEditor(id: editorID) }
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = L("video_editor.title", videoURL.lastPathComponent)
        window.minSize = NSSize(width: 720, height: 500)
        window.contentView = NSHostingView(rootView: view)
        window.center()
        
        let managed = ManagedWindow(window: window) { [weak self] closed in
            model.cleanup()
            self?.videoEditors = self?.videoEditors.filter { $0.value !== closed } ?? [:]
        }
        
        videoEditors[editorID] = managed
        managed.bringToFront()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeVideoEditor(id: UUID) {
        guard let managed = videoEditors.removeValue(forKey: id) else { return }
        managed.closeSilently()
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
        window.title = L("history.title")
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
    
    // MARK: - Настройки
    
    public func showSettings() {
        if let existing = settingsWindow {
            existing.bringToFront()
            return
        }
        let view = SettingsWindowView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = L("settings.title")
        window.minSize = NSSize(width: 580, height: 600)
        window.contentView = NSHostingView(rootView: view)
        window.center()
        
        let managed = ManagedWindow(window: window) { [weak self] _ in self?.settingsWindow = nil }
        settingsWindow = managed
        managed.bringToFront()
        NSApp.activate(ignoringOtherApps: true)
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
    
    func closePin(id: UUID) {
        guard let managed = pins.removeValue(forKey: id) else { return }
        managed.closeSilently()
    }
}
