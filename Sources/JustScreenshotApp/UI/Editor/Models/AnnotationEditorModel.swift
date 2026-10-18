import SwiftUI
import AppKit

/// Наблюдаемая модель состояния редактора: элементы, сессия UI, фон, undo/redo
@MainActor
public final class AnnotationEditorModel: ObservableObject {
    public let capturedItem: CapturedItem
    
    @Published public var items: [AnnotationItem] = []
    @Published public var selectedItemID: UUID? = nil
    
    @Published public var selectedTool: AnnotationTool = EditorPreferences.tool {
        didSet {
            // Не затираем «рисовалку» при переходе в режим выбора
            if selectedTool != .select {
                EditorPreferences.tool = selectedTool
            }
        }
    }
    @Published public var selectedColor: Color = EditorPreferences.color {
        didSet { EditorPreferences.color = selectedColor }
    }
    @Published public var lineWidth: CGFloat = EditorPreferences.lineWidth {
        didSet { EditorPreferences.lineWidth = lineWidth }
    }
    @Published public var fontSize: CGFloat = EditorPreferences.fontSize {
        didSet { EditorPreferences.fontSize = fontSize }
    }
    @Published public var textInputString: String = ""
    /// Запрос фокуса на поле текста в selected bar после создания/даблклика
    @Published public var shouldFocusTextEditor: Bool = false
    
    @Published public var showBackdrop: Bool = EditorPreferences.showBackdrop {
        didSet {
            EditorPreferences.showBackdrop = showBackdrop
            markModified()
        }
    }
    @Published public var backdropPreset: BackdropPreset = EditorPreferences.backdropPreset {
        didSet {
            EditorPreferences.backdropPreset = backdropPreset
            markModified()
        }
    }
    @Published public var backdropPadding: CGFloat = EditorPreferences.backdropPadding {
        didSet {
            EditorPreferences.backdropPadding = backdropPadding
            markModified()
        }
    }
    @Published public var backdropCornerRadius: CGFloat = EditorPreferences.backdropCornerRadius {
        didSet {
            EditorPreferences.backdropCornerRadius = backdropCornerRadius
            markModified()
        }
    }
    @Published public var backdropShadowRadius: CGFloat = EditorPreferences.backdropShadowRadius {
        didSet {
            EditorPreferences.backdropShadowRadius = backdropShadowRadius
            markModified()
        }
    }
    @Published public var addShadow: Bool = EditorPreferences.addShadow {
        didSet {
            EditorPreferences.addShadow = addShadow
            markModified()
        }
    }
    
    @Published public private(set) var canUndo: Bool = false
    @Published public private(set) var canRedo: Bool = false
    
    private var undoStack: [[AnnotationItem]] = []
    private var redoStack: [[AnnotationItem]] = []
    private var isRestoring = false
    /// Снимок до текущего жеста (move/resize/draw commit)
    private var gestureBaseline: [AnnotationItem]?
    private var liveEditFinalizeTask: Task<Void, Never>?
    
    public private(set) var hasUnsavedChanges: Bool = false
    private var initialLoaded = false
    
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
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
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
