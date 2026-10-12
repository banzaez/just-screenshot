import SwiftUI
import AppKit

/// Холст аннотаций: рисование, выбор, перемещение, изменение размера за маркеры и поворот за ручку
public struct AnnotationCanvasView: View {
    @Binding public var items: [AnnotationItem]
    @Binding public var selectedItemID: UUID?
    
    public let currentTool: AnnotationTool
    public let currentColor: Color
    public let lineWidth: CGFloat
    public let textInputString: String
    public let zoomScale: CGFloat
    public let blurredImage: NSImage?
    
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var mode: AnnotationDragMode = .idle
    @State private var snapshot: AnnotationItem?
    @State private var nextCounter: Int = 1
    
    public init(
        items: Binding<[AnnotationItem]>,
        selectedItemID: Binding<UUID?>,
        currentTool: AnnotationTool,
        currentColor: Color,
        lineWidth: CGFloat,
        textInputString: String = "Текст",
        zoomScale: CGFloat = 1.0,
        blurredImage: NSImage? = nil
    ) {
        self.blurredImage = blurredImage
        self._items = items
        self._selectedItemID = selectedItemID
        self.currentTool = currentTool
        self.currentColor = currentColor
        self.lineWidth = lineWidth
        self.textInputString = textInputString
        self.zoomScale = zoomScale
    }
    
    private var interactions: AnnotationCanvasInteractions {
        AnnotationCanvasInteractions(zoomScale: zoomScale)
    }
    
    public var body: some View {
        Canvas { context, _ in
            var scaled = context
            scaled.scaleBy(x: zoomScale, y: zoomScale)
            
            for item in items {
                var itemContext = scaled
                AnnotationCanvasDrawer.applyRotation(of: item, to: &itemContext)
                AnnotationCanvasDrawer.drawItem(item, in: &itemContext, blurredImage: blurredImage)
            }
            
            if let sel = items.first(where: { $0.id == selectedItemID }) {
                AnnotationCanvasDrawer.drawSelection(sel, in: scaled, zoomScale: zoomScale, interactions: interactions)
            }
            
            if mode == .drawing, currentTool != .select, let start = dragStart, let current = dragCurrent {
                let preview = AnnotationItem(
                    tool: currentTool, startPoint: start, endPoint: current,
                    color: currentColor, lineWidth: lineWidth,
                    text: textInputString.isEmpty ? "Текст заметки" : textInputString,
                    counterNumber: nextCounter, fontSize: 20
                )
                var c = scaled
                AnnotationCanvasDrawer.drawItem(preview, in: &c, blurredImage: blurredImage)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in handleChanged(value) }
                .onEnded { value in handleEnded(value) }
        )
    }
    
    // MARK: - Жесты
    
    private func handleChanged(_ value: DragGesture.Value) {
        let loc = interactions.modelPoint(value.location)
        
        if dragStart == nil {
            dragStart = interactions.modelPoint(value.startLocation)
            let startLoc = dragStart!
            
            if let sel = items.first(where: { $0.id == selectedItemID }), let h = interactions.hitHandle(of: sel, at: startLoc) {
                mode = .handle(h)
                snapshot = sel
            } else if let hit = items.reversed().first(where: { $0.contains(point: startLoc) }) {
                selectedItemID = hit.id
                mode = .moving
                snapshot = hit
            } else if currentTool == .select {
                selectedItemID = nil
                mode = .idle
                snapshot = nil
            } else {
                selectedItemID = nil
                mode = .drawing
                snapshot = nil
            }
        }
        
        guard let start = dragStart else { return }
        
        switch mode {
        case .idle:
            break
        case .drawing:
            dragCurrent = loc
        case .moving:
            guard let snap = snapshot, let idx = items.firstIndex(where: { $0.id == snap.id }) else { return }
            let dx = loc.x - start.x, dy = loc.y - start.y
            items[idx].startPoint = CGPoint(x: snap.startPoint.x + dx, y: snap.startPoint.y + dy)
            items[idx].endPoint = CGPoint(x: snap.endPoint.x + dx, y: snap.endPoint.y + dy)
        case .handle(let h):
            guard let snap = snapshot, let idx = items.firstIndex(where: { $0.id == snap.id }) else { return }
            interactions.applyHandle(h, snap: snap, to: loc, in: &items, index: idx)
        }
    }
    
    private func handleEnded(_ value: DragGesture.Value) {
        defer {
            dragStart = nil
            dragCurrent = nil
            mode = .idle
            snapshot = nil
        }
        guard mode == .drawing, currentTool != .select, let start = dragStart else { return }
        let end = dragCurrent ?? interactions.modelPoint(value.location)
        let dist = hypot(end.x - start.x, end.y - start.y)
        
        var newItem: AnnotationItem?
        switch currentTool {
        case .text:
            newItem = AnnotationItem(
                tool: .text, startPoint: start, endPoint: CGPoint(x: start.x + 100, y: start.y + 30),
                color: currentColor, lineWidth: lineWidth,
                text: textInputString.isEmpty ? "Текст" : textInputString, fontSize: 22
            )
        case .counter:
            newItem = AnnotationItem(
                tool: .counter, startPoint: start, endPoint: start,
                color: currentColor, lineWidth: lineWidth, counterNumber: nextCounter
            )
            nextCounter += 1
        case .select:
            break
        default:
            if dist >= 4 {
                newItem = AnnotationItem(
                    tool: currentTool, startPoint: start, endPoint: end,
                    color: currentColor, lineWidth: lineWidth
                )
            }
        }
        if let item = newItem {
            items.append(item)
            selectedItemID = item.id
        }
    }
}
