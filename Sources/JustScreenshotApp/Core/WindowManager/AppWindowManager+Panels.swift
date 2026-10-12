import AppKit
import SwiftUI

extension AppWindowManager {
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
}
