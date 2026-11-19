import SwiftUI
import AppKit
import Observation

/// Наблюдаемая модель состояния редактора: элементы, единый стек undo/redo, фон, кадрирование
@Observable
@MainActor
public final class AnnotationEditorModel {
    public let capturedItem: CapturedItem
    public var currentBaseImage: NSImage
    public private(set) var imageRevision: Int = 0

    public var items: [AnnotationItem] = []
    public var selectedItemID: UUID? = nil
    public var cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    public private(set) var nextCounterNumber: Int = 1

    public var selectedTool: AnnotationTool = EditorPreferences.tool {
        didSet {
            // Не затираем активный инструмент рисования при переходе к выбору или обрезке
            if selectedTool != .select && selectedTool != .crop {
                EditorPreferences.tool = selectedTool
            }
        }
    }
    public var selectedColor: Color = EditorPreferences.color {
        didSet { EditorPreferences.color = selectedColor }
    }
    public var lineWidth: CGFloat = EditorPreferences.lineWidth {
        didSet { schedulePreferencesSync() }
    }
    public var fontSize: CGFloat = EditorPreferences.fontSize {
        didSet { schedulePreferencesSync() }
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
            schedulePreferencesSync()
            markModified()
        }
    }
    public var backdropCornerRadius: CGFloat = EditorPreferences.backdropCornerRadius {
        didSet {
            schedulePreferencesSync()
            markModified()
        }
    }
    public var backdropShadowRadius: CGFloat = EditorPreferences.backdropShadowRadius {
        didSet {
            schedulePreferencesSync()
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

    private struct HistorySnapshot {
        let image: NSImage
        let imageRevision: Int
        let items: [AnnotationItem]
        let nextCounterNumber: Int
    }

    @ObservationIgnored private var historyUndoStack: [HistorySnapshot] = []
    @ObservationIgnored private var historyRedoStack: [HistorySnapshot] = []
    @ObservationIgnored private var gestureBaseline: HistorySnapshot?
    @ObservationIgnored private nonisolated(unsafe) var liveEditFinalizeTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var prefSyncTask: Task<Void, Never>?

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

    deinit {
        liveEditFinalizeTask?.cancel()
        prefSyncTask?.cancel()
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

    public func flushPendingEdits() {
        liveEditFinalizeTask?.cancel()
        liveEditFinalizeTask = nil
        endGestureEdit()

        prefSyncTask?.cancel()
        prefSyncTask = nil
        syncNumericPreferences()
    }

    public func cleanup() {
        flushPendingEdits()
    }

    private func schedulePreferencesSync() {
        prefSyncTask?.cancel()
        prefSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, let self else { return }
            self.prefSyncTask = nil
            self.syncNumericPreferences()
        }
    }

    private func syncNumericPreferences() {
        EditorPreferences.lineWidth = lineWidth
        EditorPreferences.fontSize = fontSize
        EditorPreferences.backdropPadding = backdropPadding
        EditorPreferences.backdropCornerRadius = backdropCornerRadius
        EditorPreferences.backdropShadowRadius = backdropShadowRadius
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

    // MARK: - Unified Chronological Undo & Redo

    private func captureSnapshot() -> HistorySnapshot {
        HistorySnapshot(
            image: currentBaseImage,
            imageRevision: imageRevision,
            items: items,
            nextCounterNumber: nextCounterNumber
        )
    }

    private func pushUndoSnapshot(_ snapshot: HistorySnapshot) {
        historyUndoStack.append(snapshot)
        if historyUndoStack.count > 100 {
            historyUndoStack.removeFirst()
        }
        historyRedoStack.removeAll()
        updateUndoRedoAvailability()
    }

    private func restoreSnapshot(_ snap: HistorySnapshot) {
        let previousSelection = selectedItemID
        let imageChanged = snap.image !== currentBaseImage || snap.imageRevision != imageRevision
        currentBaseImage = snap.image
        imageRevision = snap.imageRevision
        items = snap.items
        nextCounterNumber = snap.nextCounterNumber
        if imageChanged {
            cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
            selectedItemID = nil
        } else if let previousSelection, snap.items.contains(where: { $0.id == previousSelection }) {
            selectedItemID = previousSelection
        } else {
            selectedItemID = nil
        }
        markModified()
        updateUndoRedoAvailability()
    }

    /// Начало жеста: сохраняем единый снимок перед drag/resize/slider
    public func beginGestureEdit() {
        guard gestureBaseline == nil else { return }
        gestureBaseline = captureSnapshot()
    }

    /// Конец жеста: если элементы изменились — фиксируем baseline в единый undo
    public func endGestureEdit() {
        guard let baseline = gestureBaseline else { return }
        gestureBaseline = nil
        guard baseline.items != items else { return }
        pushUndoSnapshot(baseline)
        markModified()
    }

    /// Точечное изменение элементов с сохранением единого undo-снимка
    public func commitItemsMutation(_ mutate: (inout [AnnotationItem]) -> Void) {
        flushPendingGestureIfDifferent()
        let baseline = captureSnapshot()
        var next = items
        mutate(&next)
        guard next != baseline.items else { return }
        pushUndoSnapshot(baseline)
        items = next
        markModified()
    }

    private func flushPendingGestureIfDifferent() {
        liveEditFinalizeTask?.cancel()
        liveEditFinalizeTask = nil
        if gestureBaseline != nil {
            endGestureEdit()
        }
    }

    public func updateSelected(_ mutate: (inout AnnotationItem) -> Void) {
        guard let idx = selectedItemIndex else { return }
        commitItemsMutation { list in
            mutate(&list[idx])
        }
    }

    /// Непрерывное изменение (слайдер): один undo-сэмпл на жест с debounce
    public func liveUpdateSelected(_ mutate: (inout AnnotationItem) -> Void) {
        beginGestureEdit()
        guard let idx = selectedItemIndex else { return }
        mutate(&items[idx])
        markModified()
        liveEditFinalizeTask?.cancel()
        liveEditFinalizeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self?.endGestureEdit()
        }
    }

    public func undo() {
        flushPendingGestureIfDifferent()
        guard let prev = historyUndoStack.popLast() else { return }
        historyRedoStack.append(captureSnapshot())
        restoreSnapshot(prev)
    }

    public func redo() {
        flushPendingGestureIfDifferent()
        guard let next = historyRedoStack.popLast() else { return }
        historyUndoStack.append(captureSnapshot())
        restoreSnapshot(next)
    }

    private func updateUndoRedoAvailability() {
        canUndo = !historyUndoStack.isEmpty
        canRedo = !historyRedoStack.isEmpty
    }

    // MARK: - Обрезка (Crop)

    public func resetCrop() {
        cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    public func applyCrop() {
        flushPendingGestureIfDifferent()
        guard cropRect.width > 0.01, cropRect.height > 0.01 else { return }
        guard cropRect.origin.x > 0.001 || cropRect.origin.y > 0.001 || cropRect.width < 0.999 || cropRect.height < 0.999 else {
            selectedTool = .select
            return
        }

        let oldImg = currentBaseImage
        let imgW = oldImg.size.width
        let imgH = oldImg.size.height
        guard imgW > 0, imgH > 0 else { return }

        let nx = min(max(0, cropRect.origin.x), 0.99)
        let ny = min(max(0, cropRect.origin.y), 0.99)
        let nw = min(1.0 - nx, max(0.01, cropRect.width))
        let nh = min(1.0 - ny, max(0.01, cropRect.height))

        let pointRect = CGRect(
            x: nx * imgW,
            y: ny * imgH,
            width: nw * imgW,
            height: nh * imgH
        )

        guard let cg = ImageExporter.cgImage(from: oldImg) else { return }
        let scaleX = CGFloat(cg.width) / imgW
        let scaleY = CGFloat(cg.height) / imgH

        let cgBounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        let cgCropRect = CGRect(
            x: pointRect.origin.x * scaleX,
            y: pointRect.origin.y * scaleY,
            width: pointRect.width * scaleX,
            height: pointRect.height * scaleY
        ).integral.intersection(cgBounds)

        guard !cgCropRect.isNull, cgCropRect.width >= 1, cgCropRect.height >= 1,
              let croppedCG = cg.cropping(to: cgCropRect) else { return }

        let newPointSize = NSSize(
            width: cgCropRect.width / max(scaleX, 0.01),
            height: cgCropRect.height / max(scaleY, 0.01)
        )
        let rep = NSBitmapImageRep(cgImage: croppedCG)
        rep.size = newPointSize
        let newImage = NSImage(size: newPointSize)
        newImage.addRepresentation(rep)

        let baseline = captureSnapshot()
        pushUndoSnapshot(baseline)

        let offsetX = cgCropRect.origin.x / max(scaleX, 0.01)
        let offsetY = cgCropRect.origin.y / max(scaleY, 0.01)
        var updatedItems = items
        for i in updatedItems.indices {
            updatedItems[i].startPoint.x -= offsetX
            updatedItems[i].startPoint.y -= offsetY
            updatedItems[i].endPoint.x -= offsetX
            updatedItems[i].endPoint.y -= offsetY
        }

        imageRevision += 1
        currentBaseImage = newImage
        items = updatedItems
        cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        selectedTool = .select
        selectedItemID = nil
        markModified()
    }

    // MARK: - Convenience mutations

    /// Добавляет элемент. Инструмент рисования не сбрасывается (можно рисовать серию).
    public func appendItem(_ item: AnnotationItem, select: Bool = true, focusText: Bool = false) {
        commitItemsMutation { $0.append(item) }
        if item.tool == .counter {
            nextCounterNumber = max(nextCounterNumber + 1, item.counterNumber + 1)
        }
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
        let nextCounter = o.tool == .counter ? nextCounterNumber : o.counterNumber
        let copy = AnnotationItem(
            tool: o.tool,
            startPoint: CGPoint(x: o.startPoint.x + 24, y: o.startPoint.y + 24),
            endPoint: CGPoint(x: o.endPoint.x + 24, y: o.endPoint.y + 24),
            color: o.color,
            lineWidth: o.lineWidth,
            text: o.text,
            counterNumber: nextCounter,
            fontSize: o.fontSize,
            rotationAngle: o.rotationAngle,
            scaleFactor: o.scaleFactor,
            curveOffset: o.curveOffset
        )
        appendItem(copy, select: true, focusText: copy.tool == .text)
    }

    // MARK: - Экспорт

    public func renderFinalImage() -> NSImage {
        flushPendingEdits()
        return AnnotationRenderer.render(
            baseImage: currentBaseImage,
            items: items,
            backdrop: showBackdrop ? backdropPreset : nil,
            padding: backdropPadding,
            cornerRadius: backdropCornerRadius,
            shadowRadius: backdropShadowRadius,
            shadow: addShadow,
            showWindowFrame: showWindowFrame,
            imageID: capturedItem.id,
            revision: imageRevision
        )
    }
}
