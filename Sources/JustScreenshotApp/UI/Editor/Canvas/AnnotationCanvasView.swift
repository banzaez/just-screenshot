import SwiftUI
import AppKit

/// Холст аннотаций: рисование, выбор, перемещение, resize и поворот.
/// Move/resize идут через локальный preview — модель коммитится только в onEnded.
public struct AnnotationCanvasView: View {
    @ObservedObject public var model: AnnotationEditorModel
    public let baseImage: NSImage
    public let zoomScale: CGFloat
    public let blurredImage: NSImage?
    
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var mode: AnnotationDragMode = .idle
    @State private var snapshot: AnnotationItem?
    /// Локальная копия элемента во время move/resize — без @Published на каждый пиксель
    @State private var previewItem: AnnotationItem?
    @State private var nextCounter: Int = 1
    @State private var lastClickTime: Date = .distantPast
    @State private var lastClickItemID: UUID?
    
    public init(
        model: AnnotationEditorModel,
        baseImage: NSImage,
        zoomScale: CGFloat = 1.0,
        blurredImage: NSImage? = nil
    ) {
        self.model = model
        self.baseImage = baseImage
        self.zoomScale = zoomScale
        self.blurredImage = blurredImage
    }
    
    private var interactions: AnnotationCanvasInteractions {
        AnnotationCanvasInteractions(zoomScale: zoomScale)
    }
    
    private var displayItems: [AnnotationItem] {
        guard let previewItem else { return model.items }
        return model.items.map { $0.id == previewItem.id ? previewItem : $0 }
    }
    
    public var body: some View {
        Canvas { context, _ in
            var scaled = context
            scaled.scaleBy(x: zoomScale, y: zoomScale)
            
            for item in displayItems {
                var itemContext = scaled
                AnnotationCanvasDrawer.applyRotation(of: item, to: &itemContext)
                AnnotationCanvasDrawer.drawItem(item, in: &itemContext, baseImage: baseImage, blurredImage: blurredImage)
            }
            
            let selectedID = previewItem?.id ?? model.selectedItemID
            if let sel = displayItems.first(where: { $0.id == selectedID }) {
                AnnotationCanvasDrawer.drawSelection(sel, in: scaled, zoomScale: zoomScale, interactions: interactions)
            }
            
            if mode == .drawing, model.selectedTool != .select, let start = dragStart, let current = dragCurrent {
                let preview = makePreviewItem(start: start, end: current)
                var c = scaled
                AnnotationCanvasDrawer.drawItem(preview, in: &c, baseImage: baseImage, blurredImage: blurredImage)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in handleChanged(value) }
                .onEnded { value in handleEnded(value) }
        )
    }
    
    private func makePreviewItem(start: CGPoint, end: CGPoint) -> AnnotationItem {
        AnnotationItem(
            tool: model.selectedTool,
            startPoint: start,
            endPoint: end,
            color: model.selectedColor,
            lineWidth: model.lineWidth,
            text: model.textInputString.isEmpty ? L("editor.default_note_text") : model.textInputString,
            counterNumber: nextCounter,
            fontSize: 20,
            scaleFactor: model.selectedTool == .magnifier ? 2.0 : 1.0
        )
    }
    
    // MARK: - Жесты
    
    private func handleChanged(_ value: DragGesture.Value) {
        let loc = interactions.modelPoint(value.location)
        
        if dragStart == nil {
            dragStart = interactions.modelPoint(value.startLocation)
            let startLoc = dragStart!
            beginGesture(at: startLoc)
        }
        
        guard let start = dragStart else { return }
        
        switch mode {
        case .idle:
            break
        case .drawing:
            dragCurrent = loc
        case .moving:
            guard let snap = snapshot else { return }
            let dx = loc.x - start.x, dy = loc.y - start.y
            var moved = snap
            moved.startPoint = CGPoint(x: snap.startPoint.x + dx, y: snap.startPoint.y + dy)
            moved.endPoint = CGPoint(x: snap.endPoint.x + dx, y: snap.endPoint.y + dy)
            previewItem = moved
        case .handle(let h):
            guard let snap = snapshot else { return }
            previewItem = interactions.applyingHandle(h, snap: snap, to: loc)
        }
    }
    
    private func beginGesture(at startLoc: CGPoint) {
        if let sel = model.selectedItem, let h = interactions.hitHandle(of: sel, at: startLoc) {
            mode = .handle(h)
            snapshot = sel
            previewItem = sel
            model.beginGestureEdit()
            return
        }
        
        if let hit = model.items.reversed().first(where: { $0.contains(point: startLoc) }) {
            handleItemClick(hit)
            mode = .moving
            snapshot = hit
            previewItem = hit
            model.beginGestureEdit()
            return
        }
        
        if model.selectedTool == .select {
            model.selectItem(id: nil)
            mode = .idle
            snapshot = nil
            previewItem = nil
        } else {
            model.selectItem(id: nil)
            mode = .drawing
            snapshot = nil
            previewItem = nil
        }
    }
    
    private func handleItemClick(_ hit: AnnotationItem) {
        let now = Date()
        let isDoubleClick = hit.id == lastClickItemID && now.timeIntervalSince(lastClickTime) < 0.35
        lastClickTime = now
        lastClickItemID = hit.id
        
        model.selectItem(id: hit.id)
        if isDoubleClick && hit.tool == .text {
            model.requestTextFocus()
        }
    }
    
    private func handleEnded(_ value: DragGesture.Value) {
        defer {
            dragStart = nil
            dragCurrent = nil
            mode = .idle
            snapshot = nil
            previewItem = nil
        }
        
        switch mode {
        case .moving, .handle:
            if let previewItem, let idx = model.items.firstIndex(where: { $0.id == previewItem.id }) {
                model.items[idx] = previewItem
            }
            model.endGestureEdit()
            
        case .drawing:
            guard model.selectedTool != .select, let start = dragStart else { return }
            let end = dragCurrent ?? interactions.modelPoint(value.location)
            commitNewItem(start: start, end: end)
            
        case .idle:
            break
        }
    }
    
    private func commitNewItem(start: CGPoint, end: CGPoint) {
        let dist = hypot(end.x - start.x, end.y - start.y)
        var newItem: AnnotationItem?
        
        switch model.selectedTool {
        case .text:
            let text = model.textInputString.isEmpty ? L("editor.default_text") : model.textInputString
            newItem = AnnotationItem(
                tool: .text,
                startPoint: start,
                endPoint: CGPoint(x: start.x + 100, y: start.y + 30),
                color: model.selectedColor,
                lineWidth: model.lineWidth,
                text: text,
                fontSize: 22
            )
        case .counter:
            newItem = AnnotationItem(
                tool: .counter,
                startPoint: start,
                endPoint: start,
                color: model.selectedColor,
                lineWidth: model.lineWidth,
                counterNumber: nextCounter
            )
            nextCounter += 1
        case .select:
            break
        case .magnifier:
            if dist >= 4 {
                newItem = AnnotationItem(
                    tool: .magnifier,
                    startPoint: start,
                    endPoint: end,
                    color: model.selectedColor,
                    lineWidth: model.lineWidth,
                    scaleFactor: 2.0
                )
            }
        default:
            if dist >= 4 {
                newItem = AnnotationItem(
                    tool: model.selectedTool,
                    startPoint: start,
                    endPoint: end,
                    color: model.selectedColor,
                    lineWidth: model.lineWidth
                )
            }
        }
        
        if let item = newItem {
            model.appendItem(item, select: true, focusText: item.tool == .text)
        }
    }
}
