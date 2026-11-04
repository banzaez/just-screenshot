import SwiftUI
import AppKit
import Observation

/// Наблюдаемая модель состояния редактора: элементы, сессия UI, фон, undo/redo
@Observable
@MainActor
public final class AnnotationEditorModel {
    public let capturedItem: CapturedItem
    public var currentBaseImage: NSImage
    
    public var items: [AnnotationItem] = []
    public var selectedItemID: UUID? = nil
    public var cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    
    public var selectedTool: AnnotationTool = EditorPreferences.tool {
        didSet {
            // Не затираем «рисовалку» при переходе в режим выбора или обрезки
            if selectedTool != .select && selectedTool != .crop {
                EditorPreferences.tool = selectedTool
            }
        }
    }
    public var selectedColor: Color = EditorPreferences.color {
        didSet { EditorPreferences.color = selectedColor }
    }
    public var lineWidth: CGFloat = EditorPreferences.lineWidth {
        didSet { EditorPreferences.lineWidth = lineWidth }
    }
    public var fontSize: CGFloat = EditorPreferences.fontSize {
        didSet { EditorPreferences.fontSize = fontSize }
    }
    public var textInputString: String = ""
    /// Запрос фокуса на поле текста в selected bar после создания/даблклика
    public var shouldFocusTextEditor: Bool = false
    
    public var showBackdrop: Bool = EditorPreferences.showBackdrop {
        didSet {
            EditorPreferences.showBackdrop = showBackdrop
            markModified()
        }
    }
    public var backdropPreset: BackdropPreset = EditorPreferences.backdropPreset {
        didSet {
            EditorPreferences.backdropPreset = backdropPreset
            markModified()
        }
    }
    public var backdropPadding: CGFloat = EditorPreferences.backdropPadding {
        didSet {
            EditorPreferences.backdropPadding = backdropPadding
            markModified()
        }
    }
    public var backdropCornerRadius: CGFloat = EditorPreferences.backdropCornerRadius {
        didSet {
            EditorPreferences.backdropCornerRadius = backdropCornerRadius
            markModified()
        }
    }
    public var backdropShadowRadius: CGFloat = EditorPreferences.backdropShadowRadius {
        didSet {
            EditorPreferences.backdropShadowRadius = backdropShadowRadius
            markModified()
        }
    }
    public var addShadow: Bool = EditorPreferences.addShadow {
        didSet {
            EditorPreferences.addShadow = addShadow
            markModified()
        }
    }
    public var showWindowFrame: Bool = EditorPreferences.showWindowFrame {
        didSet {
            EditorPreferences.showWindowFrame = showWindowFrame
            markModified()
        }
    }
    
    public private(set) var canUndo: Bool = false
    public private(set) var canRedo: Bool = false
    
    private struct EditorStateSnapshot {
        let image: NSImage
        let items: [AnnotationItem]
    }
    @ObservationIgnored private var snapshotUndoStack: [EditorStateSnapshot] = []
    @ObservationIgnored private var snapshotRedoStack: [EditorStateSnapshot] = []
    
    @ObservationIgnored private var undoStack: [[AnnotationItem]] = []
    @ObservationIgnored private var redoStack: [[AnnotationItem]] = []
    @ObservationIgnored private var isRestoring = false
    /// Снимок до текущего жеста (move/resize/draw commit)
    @ObservationIgnored private var gestureBaseline: [AnnotationItem]?
    @ObservationIgnored private var liveEditFinalizeTask: Task<Void, Never>?
    
    @ObservationIgnored public private(set) var hasUnsavedChanges: Bool = false
    @ObservationIgnored private var initialLoaded = false
    
    public var selectedItemIndex: Int? {
        guard let id = selectedItemID else { return nil }
        return items.firstIndex(where: { $0.id == id })
    }
    
    public var selectedItem: AnnotationItem? {
        guard let idx = selectedItemIndex else { return nil }
        return items[idx]
    }
    
    public init(capturedItem: CapturedItem) {
        self.capturedItem = capturedItem
        self.currentBaseImage = capturedItem.image
        self.textInputString = L("editor.default_note_text")
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
    
    // MARK: - Selection / tools
    
    public func selectTool(_ tool: AnnotationTool) {
        selectedTool = tool
        if tool != .select {
            selectedItemID = nil
        }
    }
    
    public func selectItem(id: UUID?) {
        selectedItemID = id
        if id != nil {
            selectedTool = .select
        }
    }
    
    public func requestTextFocus() {
        shouldFocusTextEditor = true
    }
    
    public func consumeTextFocusRequest() {
        shouldFocusTextEditor = false
    }
    
    // MARK: - Undo & Redo
    
    /// Начало жеста: один checkpoint на весь drag
    public func beginGestureEdit() {
        guard gestureBaseline == nil else { return }
        gestureBaseline = items
    }
    
    /// Конец жеста: если items изменились — пушим baseline в undo
    public func endGestureEdit() {
        guard let baseline = gestureBaseline else { return }
        gestureBaseline = nil
        guard baseline != items else { return }
        undoStack.append(baseline)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
        markModified()
        updateUndoRedoAvailability()
    }
    
    /// Явный checkpoint перед пакетным изменением (авто-редакт и т.п.)
    public func pushExplicitUndoCheckpoint() {
        undoStack.append(items)
        redoStack.removeAll()
        updateUndoRedoAvailability()
    }
    
    /// Точечное изменение items с undo (append / delete / duplicate / property)
    public func commitItemsMutation(_ mutate: (inout [AnnotationItem]) -> Void) {
        let baseline = items
        var next = items
        mutate(&next)
        guard next != baseline else { return }
        undoStack.append(baseline)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
        isRestoring = true
        items = next
        isRestoring = false
        markModified()
        updateUndoRedoAvailability()
    }
    
    public func updateSelected(_ mutate: (inout AnnotationItem) -> Void) {
        guard let idx = selectedItemIndex else { return }
        commitItemsMutation { list in
            mutate(&list[idx])
        }
    }
    
    /// Непрерывное изменение (слайдер): один undo-checkpoint на жест с debounce
    public func liveUpdateSelected(_ mutate: (inout AnnotationItem) -> Void) {
        beginGestureEdit()
        guard let idx = selectedItemIndex else { return }
        mutate(&items[idx])
        markModified()
        liveEditFinalizeTask?.cancel()
        liveEditFinalizeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run { self?.endGestureEdit() }
        }
    }
    
    public func undo() {
        if let lastSnap = snapshotUndoStack.popLast() {
            snapshotRedoStack.append(EditorStateSnapshot(image: currentBaseImage, items: items))
            isRestoring = true
            currentBaseImage = lastSnap.image
            items = lastSnap.items
            cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
            selectedItemID = nil
            isRestoring = false
            markModified()
            updateUndoRedoAvailability()
            return
        }
        guard let prev = undoStack.popLast() else { return }
        isRestoring = true
        redoStack.append(items)
        let previousSelection = selectedItemID
        items = prev
        if let previousSelection, prev.contains(where: { $0.id == previousSelection }) {
            selectedItemID = previousSelection
        } else {
            selectedItemID = nil
        }
        isRestoring = false
        markModified()
        updateUndoRedoAvailability()
    }
    
    public func redo() {
        if let nextSnap = snapshotRedoStack.popLast() {
            snapshotUndoStack.append(EditorStateSnapshot(image: currentBaseImage, items: items))
            isRestoring = true
            currentBaseImage = nextSnap.image
            items = nextSnap.items
            cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
            selectedItemID = nil
            isRestoring = false
            markModified()
            updateUndoRedoAvailability()
            return
        }
        guard let next = redoStack.popLast() else { return }
        isRestoring = true
        undoStack.append(items)
        let previousSelection = selectedItemID
        items = next
        if let previousSelection, next.contains(where: { $0.id == previousSelection }) {
            selectedItemID = previousSelection
        } else {
            selectedItemID = nil
        }
        isRestoring = false
        markModified()
        updateUndoRedoAvailability()
    }
    
    private func updateUndoRedoAvailability() {
        canUndo = !undoStack.isEmpty || !snapshotUndoStack.isEmpty
        canRedo = !redoStack.isEmpty || !snapshotRedoStack.isEmpty
    }
    
    // MARK: - Обрезка (Crop)
    
    public func resetCrop() {
        cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    
    public func applyCrop() {
        guard cropRect.width > 0.01, cropRect.height > 0.01 else { return }
        guard cropRect.origin.x > 0.001 || cropRect.origin.y > 0.001 || cropRect.width < 0.999 || cropRect.height < 0.999 else {
            selectedTool = .select
            return
        }
        
        let oldImg = currentBaseImage
        let imgW = oldImg.size.width
        let imgH = oldImg.size.height
        
        let pixelRect = CGRect(
            x: cropRect.origin.x * imgW,
            y: cropRect.origin.y * imgH,
            width: cropRect.width * imgW,
            height: cropRect.height * imgH
        )
        
        guard let cg = oldImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let scaleX = CGFloat(cg.width) / imgW
        let scaleY = CGFloat(cg.height) / imgH
        
        let cgCropRect = CGRect(
            x: pixelRect.origin.x * scaleX,
            y: pixelRect.origin.y * scaleY,
            width: pixelRect.width * scaleX,
            height: pixelRect.height * scaleY
        )
        
        guard let croppedCG = cg.cropping(to: cgCropRect) else { return }
        let newImage = NSImage(cgImage: croppedCG, size: pixelRect.size)
        
        snapshotUndoStack.append(EditorStateSnapshot(image: oldImg, items: items))
        if snapshotUndoStack.count > 20 { snapshotUndoStack.removeFirst() }
        snapshotRedoStack.removeAll()
        
        let offsetX = pixelRect.origin.x
        let offsetY = pixelRect.origin.y
        var updatedItems = items
        for i in updatedItems.indices {
            updatedItems[i].startPoint.x -= offsetX
            updatedItems[i].startPoint.y -= offsetY
            updatedItems[i].endPoint.x -= offsetX
            updatedItems[i].endPoint.y -= offsetY
        }
        
        isRestoring = true
        currentBaseImage = newImage
        items = updatedItems
        cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        selectedTool = .select
        isRestoring = false
        markModified()
        updateUndoRedoAvailability()
    }
    
    // MARK: - Convenience mutations
    
    /// Добавляет элемент. Инструмент рисования не сбрасывается (можно рисовать серию).
    public func appendItem(_ item: AnnotationItem, select: Bool = true, focusText: Bool = false) {
        commitItemsMutation { $0.append(item) }
        if select {
            selectedItemID = item.id
        }
        if focusText {
            requestTextFocus()
        }
    }
    
    public func deleteSelected() {
        guard let id = selectedItemID else { return }
        commitItemsMutation { list in
            list.removeAll { $0.id == id }
        }
        selectedItemID = nil
    }
    
    public func duplicateSelected() {
        guard let idx = selectedItemIndex else { return }
        let o = items[idx]
        let copy = AnnotationItem(
            tool: o.tool,
            startPoint: CGPoint(x: o.startPoint.x + 24, y: o.startPoint.y + 24),
            endPoint: CGPoint(x: o.endPoint.x + 24, y: o.endPoint.y + 24),
            color: o.color, lineWidth: o.lineWidth, text: o.text,
            counterNumber: o.counterNumber + 1, fontSize: o.fontSize,
            rotationAngle: o.rotationAngle, scaleFactor: o.scaleFactor
        )
        appendItem(copy, select: true, focusText: copy.tool == .text)
    }
    
    // MARK: - Экспорт
    
    public func renderFinalImage() -> NSImage {
        AnnotationRenderer.render(
            baseImage: currentBaseImage,
            items: items,
            backdrop: showBackdrop ? backdropPreset : nil,
            padding: backdropPadding,
            cornerRadius: backdropCornerRadius,
            shadowRadius: backdropShadowRadius,
            shadow: addShadow,
            showWindowFrame: showWindowFrame,
            imageID: capturedItem.id
        )
    }
}
