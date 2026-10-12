import SwiftUI
import AppKit

/// Наблюдаемая модель состояния редактора: элементы, фон, подтверждение при закрытии и стек отмены/повтора (Undo/Redo)
@MainActor
public final class AnnotationEditorModel: ObservableObject {
    public let capturedItem: CapturedItem
    
    @Published public var items: [AnnotationItem] = []
    @Published public var showBackdrop: Bool = true
    @Published public var backdropPreset: BackdropPreset = .aurora
    @Published public var backdropPadding: CGFloat = 48
    @Published public var backdropCornerRadius: CGFloat = 12
    @Published public var backdropShadowRadius: CGFloat = 24
    @Published public var addShadow: Bool = true
    
    // Стек Undo / Redo
    @Published public private(set) var canUndo: Bool = false
    @Published public private(set) var canRedo: Bool = false
    
    private var undoStack: [[AnnotationItem]] = []
    private var redoStack: [[AnnotationItem]] = []
    private var isRestoring = false
    private var lastPushTime = Date.distantPast
    
    public private(set) var hasUnsavedChanges: Bool = false
    private var initialLoaded = false
    
    public init(capturedItem: CapturedItem) {
        self.capturedItem = capturedItem
    }
    
    public func markSaved() {
        hasUnsavedChanges = false
    }
    
    public func markModified() {
        if initialLoaded {
            hasUnsavedChanges = true
        }
    }
    
    public func finishInitialLoading() {
        initialLoaded = true
        hasUnsavedChanges = false
    }
    
    // MARK: - Undo & Redo
    
    public func recordStateChange(oldItems: [AnnotationItem]) {
        guard !isRestoring else { return }
        markModified()
        if Date().timeIntervalSince(lastPushTime) > 0.5 {
            undoStack.append(oldItems)
            if undoStack.count > 100 { undoStack.removeFirst() }
        }
        lastPushTime = Date()
        redoStack.removeAll()
        updateUndoRedoAvailability()
    }
    
    public func undo() {
        guard let prev = undoStack.popLast() else { return }
        isRestoring = true
        redoStack.append(items)
        items = prev
        markModified()
        updateUndoRedoAvailability()
        DispatchQueue.main.async { [weak self] in
            self?.isRestoring = false
        }
    }
    
    public func redo() {
        guard let next = redoStack.popLast() else { return }
        isRestoring = true
        undoStack.append(items)
        items = next
        markModified()
        updateUndoRedoAvailability()
        DispatchQueue.main.async { [weak self] in
            self?.isRestoring = false
        }
    }
    
    public func pushExplicitUndoCheckpoint() {
        undoStack.append(items)
        redoStack.removeAll()
        updateUndoRedoAvailability()
    }
    
    private func updateUndoRedoAvailability() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    // MARK: - Экспорт
    
    public func renderFinalImage() -> NSImage {
        AnnotationRenderer.render(
            baseImage: capturedItem.image,
            items: items,
            backdrop: showBackdrop ? backdropPreset : nil,
            padding: backdropPadding,
            cornerRadius: backdropCornerRadius,
            shadowRadius: backdropShadowRadius,
            shadow: addShadow
        )
    }
}
