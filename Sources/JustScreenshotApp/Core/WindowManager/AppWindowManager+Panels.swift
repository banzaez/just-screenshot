import AppKit
import SwiftUI

extension AppWindowManager {
    // MARK: - История
    
    public func showHistory() {
        history.pruneMissingFiles()
        if let existing = historyWindow {
            existing.bringToFront()
            return
        }
        let view = HistoryWindowView(
            onEdit: { [weak self] entry in self?.editHistoryEntry(entry) },
            onPin: { [weak self] entry in
                guard let self, entry.kind == .image, let img = self.history.image(for: entry) else { return }
                self.pin(image: img, id: entry.id)
            },
            onCopy: { [weak self] entry in
                self?.history.copyToClipboard(entry)
            }
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = L("history.title")
        window.minSize = NSSize(width: 580, height: 420)
        window.contentView = NSHostingView(rootView: view)
        window.center()
        
        let managed = ManagedWindow(window: window) { [weak self] _ in self?.historyWindow = nil }
        historyWindow = managed
        managed.bringToFront()
    }
    
    public func editHistoryEntry(_ entry: HistoryEntry) {
        switch entry.kind {
        case .image:
            guard let image = history.image(for: entry) else {
                history.pruneMissingFiles()
                return
            }
            openAnnotationEditor(item: CapturedItem(id: entry.id, image: image, timestamp: entry.date, rect: .zero))
        case .video:
            let url = history.fileURL(for: entry)
            guard FileManager.default.fileExists(atPath: url.path) else {
                history.pruneMissingFiles()
                return
            }
            openVideoEditor(videoURL: url)
        }
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
}
