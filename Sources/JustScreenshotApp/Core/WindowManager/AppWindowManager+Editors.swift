import AppKit
import SwiftUI

extension AppWindowManager {
    // MARK: - Редакторы (скриншоты и видео)
    
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
            onDelete: { [weak self] in
                self?.deleteCapturedItem(id: id)
            },
            onClose: { [weak self] in self?.closeEditor(id: id) }
        )
        
        let window = makeEditorWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1140, height: 780),
            title: L("editor.title", Int(item.image.size.width), Int(item.image.size.height)),
            minSize: NSSize(width: 880, height: 560),
            rootView: view,
            resetCascade: editors.isEmpty
        )
        
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
        let finalImage = model.renderFinalImage()
        self.history.add(finalImage)
        model.markSaved()
        return true
    }
    
    func closeEditor(id: UUID) {
        guard let managed = editors[id] else { return }
        if managed.windowShouldClose(managed.window) {
            editors.removeValue(forKey: id)
            managed.closeSilently()
        }
    }
    
    func closeEditorSilently(id: UUID) {
        guard let managed = editors.removeValue(forKey: id) else { return }
        managed.closeSilently()
    }
    
    public func openVideoEditor(videoURL: URL, cursorTrack: CursorTrack? = nil) {
        let standardizedPath = videoURL.standardizedFileURL.path
        if let existingPair = videoEditors.first(where: { $0.value.window.representedURL?.standardizedFileURL.path == standardizedPath }) {
            existingPair.value.bringToFront()
            return
        }
        
        let editorID = UUID()
        let resolvedTrack = cursorTrack ?? CursorTrackRecorder.loadTrack(forVideoURL: videoURL)
        let model = VideoEditorModel(videoURL: videoURL, cursorTrack: resolvedTrack)
        let view = VideoEditorWindowView(
            model: model,
            onDelete: { [weak self] in
                self?.closeVideoEditor(id: editorID)
                self?.history.deleteVideo(at: videoURL)
            },
            onClose: { [weak self] in self?.closeVideoEditor(id: editorID) }
        )
        
        let window = makeEditorWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740),
            title: L("video_editor.title", videoURL.lastPathComponent),
            minSize: NSSize(width: 860, height: 540),
            rootView: view,
            resetCascade: videoEditors.isEmpty
        )
        window.representedURL = videoURL
        
        let managed = ManagedWindow(window: window) { [weak self] closed in
            model.cleanup()
            self?.videoEditors = self?.videoEditors.filter { $0.value !== closed } ?? [:]
        }
        
        videoEditors[editorID] = managed
        managed.bringToFront()
    }
    
    func closeVideoEditor(id: UUID) {
        guard let managed = videoEditors.removeValue(forKey: id) else { return }
        managed.closeSilently()
    }
    
    private func makeEditorWindow<Content: View>(
        contentRect: NSRect,
        title: String,
        minSize: NSSize,
        rootView: Content,
        resetCascade: Bool
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.minSize = minSize
        window.contentView = NSHostingView(rootView: rootView)
        
        if resetCascade {
            window.center()
            cascadePoint = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        }
        cascadePoint = window.cascadeTopLeft(from: cascadePoint)
        return window
    }
}
