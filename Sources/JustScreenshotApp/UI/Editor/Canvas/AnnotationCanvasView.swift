import SwiftUI
import AppKit

/// Холст аннотаций: рисование, выбор, перемещение, resize и поворот.
/// Move/resize идут через локальный preview — модель коммитится только в onEnded.
public struct AnnotationCanvasView: View {
    public var model: AnnotationEditorModel
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
        ZStack {
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
                
                if mode == .drawing, model.selectedTool != .select, model.selectedTool != .crop, let start = dragStart, let current = dragCurrent {
                    let preview = makePreviewItem(start: start, end: current)
                    var c = scaled
                    AnnotationCanvasDrawer.drawItem(preview, in: &c, baseImage: baseImage, blurredImage: blurredImage)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                model.selectedTool == .crop ? nil : DragGesture(minimumDistance: 0)
                    .onChanged { value in handleChanged(value) }
                    .onEnded { value in handleEnded(value) }
            )
            
            if model.selectedTool == .crop {
                ScreenshotCropOverlayView(model: model, imageSize: baseImage.size, zoomScale: zoomScale)
            }
        }
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
            fontSize: model.fontSize,
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
                fontSize: model.fontSize
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
        case .select, .crop:
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

// MARK: - Интерактивная рамка обрезки скриншота

private struct ScreenshotCropOverlayView: View {
    var model: AnnotationEditorModel
    let imageSize: CGSize
    let zoomScale: CGFloat
    
    @State private var dragInitialCrop: CGRect?
    @State private var resizeCornerStartCrop: CGRect?
    
    var body: some View {
        let displayW = imageSize.width * zoomScale
        let displayH = imageSize.height * zoomScale
        
        let cropPixelRect = CGRect(
            x: model.cropRect.origin.x * displayW,
            y: model.cropRect.origin.y * displayH,
            width: max(20, model.cropRect.width * displayW),
            height: max(20, model.cropRect.height * displayH)
        )
        
        ZStack(alignment: .topLeading) {
            // Затемненная область вокруг рамки
            Path { path in
                path.addRect(CGRect(origin: .zero, size: CGSize(width: displayW, height: displayH)))
                path.addRect(cropPixelRect)
            }
            .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)
            
            // Сетка 3x3 и рамка
            ZStack {
                VStack(spacing: 0) {
                    Spacer()
                    Divider().background(Color.white.opacity(0.4))
                    Spacer()
                    Divider().background(Color.white.opacity(0.4))
                    Spacer()
                }
                HStack(spacing: 0) {
                    Spacer()
                    Divider().background(Color.white.opacity(0.4))
                    Spacer()
                    Divider().background(Color.white.opacity(0.4))
                    Spacer()
                }
            }
            .frame(width: cropPixelRect.width, height: cropPixelRect.height)
            .overlay(
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .position(x: cropPixelRect.midX, y: cropPixelRect.midY)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        if dragInitialCrop == nil {
                            dragInitialCrop = model.cropRect
                        }
                        guard let initial = dragInitialCrop, displayW > 0, displayH > 0 else { return }
                        let dx = val.translation.width / displayW
                        let dy = val.translation.height / displayH
                        
                        let newX = max(0, min(1 - initial.width, initial.origin.x + dx))
                        let newY = max(0, min(1 - initial.height, initial.origin.y + dy))
                        model.cropRect.origin = CGPoint(x: newX, y: newY)
                    }
                    .onEnded { _ in
                        dragInitialCrop = nil
                    }
            )
            
            // 4 угловых маркера изменения размера
            cropCornerHandle(cropPixelRect: cropPixelRect, isLeft: true, isTop: true, displayW: displayW, displayH: displayH)
            cropCornerHandle(cropPixelRect: cropPixelRect, isLeft: false, isTop: true, displayW: displayW, displayH: displayH)
            cropCornerHandle(cropPixelRect: cropPixelRect, isLeft: true, isTop: false, displayW: displayW, displayH: displayH)
            cropCornerHandle(cropPixelRect: cropPixelRect, isLeft: false, isTop: false, displayW: displayW, displayH: displayH)
        }
        .frame(width: displayW, height: displayH)
    }
    
    @ViewBuilder
    private func cropCornerHandle(
        cropPixelRect: CGRect,
        isLeft: Bool,
        isTop: Bool,
        displayW: CGFloat,
        displayH: CGFloat
    ) -> some View {
        let handleSize: CGFloat = 14
        let x = isLeft ? cropPixelRect.minX : cropPixelRect.maxX
        let y = isTop ? cropPixelRect.minY : cropPixelRect.maxY
        
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1.5))
            .frame(width: handleSize, height: handleSize)
            .shadow(radius: 2)
            .position(x: x, y: y)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        if resizeCornerStartCrop == nil {
                            resizeCornerStartCrop = model.cropRect
                        }
                        guard let initial = resizeCornerStartCrop, displayW > 0, displayH > 0 else { return }
                        let dx = val.translation.width / displayW
                        let dy = val.translation.height / displayH
                        
                        var minX = initial.minX
                        var maxX = initial.maxX
                        var minY = initial.minY
                        var maxY = initial.maxY
                        
                        let minSize: CGFloat = 0.05
                        
                        if isLeft {
                            minX = max(0, min(maxX - minSize, initial.minX + dx))
                        } else {
                            maxX = min(1.0, max(minX + minSize, initial.maxX + dx))
                        }
                        
                        if isTop {
                            minY = max(0, min(maxY - minSize, initial.minY + dy))
                        } else {
                            maxY = min(1.0, max(minY + minSize, initial.maxY + dy))
                        }
                        
                        model.cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                    }
                    .onEnded { _ in
                        resizeCornerStartCrop = nil
                    }
            )
    }
}
