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
    
    private enum Handle: Equatable {
        case rotate
        case start
        case end
        case corner(left: Bool, top: Bool)
    }
    
    private enum DragMode: Equatable {
        case idle
        case drawing
        case moving
        case handle(Handle)
    }
    
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var mode: DragMode = .idle
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
    
    private var z: CGFloat { max(zoomScale, 0.05) }
    /// Расстояние ручки вращения от рамки (в модельных координатах, постоянное на экране)
    private var rotateOffset: CGFloat { 26 / z }
    private var handleHitRadius: CGFloat { 11 / z }
    
    public var body: some View {
        Canvas { context, _ in
            var scaled = context
            scaled.scaleBy(x: zoomScale, y: zoomScale)
            
            for item in items {
                var itemContext = scaled
                applyRotation(of: item, to: &itemContext)
                drawItem(item, in: &itemContext)
            }
            
            if let sel = items.first(where: { $0.id == selectedItemID }) {
                drawSelection(sel, in: scaled)
            }
            
            if mode == .drawing, currentTool != .select, let start = dragStart, let current = dragCurrent {
                let preview = AnnotationItem(
                    tool: currentTool, startPoint: start, endPoint: current,
                    color: currentColor, lineWidth: lineWidth,
                    text: textInputString.isEmpty ? "Текст заметки" : textInputString,
                    counterNumber: nextCounter, fontSize: 20
                )
                var c = scaled
                drawItem(preview, in: &c)
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
    
    private func model(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x / z, y: p.y / z) }
    
    private func handleChanged(_ value: DragGesture.Value) {
        let loc = model(value.location)
        
        if dragStart == nil {
            dragStart = model(value.startLocation)
            let startLoc = dragStart!
            
            if let sel = items.first(where: { $0.id == selectedItemID }), let h = hitHandle(of: sel, at: startLoc) {
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
            applyHandle(h, snap: snap, index: idx, to: loc)
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
        let end = dragCurrent ?? model(value.location)
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
    
    // MARK: - Ручки
    
    /// Позиции ручек в локальной (неповернутой) системе элемента
    private func handlePositions(of item: AnnotationItem) -> [(Handle, CGPoint)] {
        var result: [(Handle, CGPoint)] = []
        if item.isLineLike {
            result.append((.start, item.startPoint))
            result.append((.end, item.endPoint))
        } else {
            let box = item.boundingBox
            if item.isRectLike {
                result.append((.corner(left: true, top: true), CGPoint(x: box.minX, y: box.minY)))
                result.append((.corner(left: false, top: true), CGPoint(x: box.maxX, y: box.minY)))
                result.append((.corner(left: true, top: false), CGPoint(x: box.minX, y: box.maxY)))
                result.append((.corner(left: false, top: false), CGPoint(x: box.maxX, y: box.maxY)))
            }
            if item.supportsRotation {
                result.append((.rotate, CGPoint(x: box.midX, y: box.minY - rotateOffset)))
            }
        }
        return result
    }
    
    private func hitHandle(of item: AnnotationItem, at point: CGPoint) -> Handle? {
        let local = item.unrotated(point)
        // Ручка вращения проверяется первой, чтобы не конфликтовать с углами
        let ordered = handlePositions(of: item).sorted { a, _ in a.0 == .rotate }
        for (h, pos) in ordered where hypot(local.x - pos.x, local.y - pos.y) <= handleHitRadius {
            return h
        }
        return nil
    }
    
    private func applyHandle(_ h: Handle, snap: AnnotationItem, index idx: Int, to loc: CGPoint) {
        switch h {
        case .rotate:
            let c = snap.center
            var deg = atan2(loc.y - c.y, loc.x - c.x) * 180 / .pi + 90
            deg = AnnotationItem.normalize(deg)
            let snapped = (deg / 15).rounded() * 15
            if abs(deg - snapped) < 4 { deg = snapped }
            items[idx].rotationAngle = deg
        case .start:
            items[idx].startPoint = loc
        case .end:
            items[idx].endPoint = loc
        case .corner(let left, let top):
            let local = snap.unrotated(loc)
            let minX = min(snap.startPoint.x, snap.endPoint.x), maxX = max(snap.startPoint.x, snap.endPoint.x)
            let minY = min(snap.startPoint.y, snap.endPoint.y), maxY = max(snap.startPoint.y, snap.endPoint.y)
            let x0 = left ? local.x : minX, x1 = left ? maxX : local.x
            let y0 = top ? local.y : minY, y1 = top ? maxY : local.y
            items[idx].startPoint = CGPoint(x: x0, y: y0)
            items[idx].endPoint = CGPoint(x: x1, y: y1)
        }
    }
    
    // MARK: - Отрисовка
    
    private func applyRotation(of item: AnnotationItem, to ctx: inout GraphicsContext) {
        guard item.rotationAngle != 0, !item.isLineLike else { return }
        let c = item.center
        ctx.translateBy(x: c.x, y: c.y)
        ctx.rotate(by: Angle(degrees: item.rotationAngle))
        ctx.translateBy(x: -c.x, y: -c.y)
    }
    
    private func drawSelection(_ item: AnnotationItem, in base: GraphicsContext) {
        let px = 1 / z
        let dash: [CGFloat] = [3 * px, 3 * px]
        let accent = Color.accentColor
        var ctx = base
        
        if item.isLineLike {
            // Аккуратная повёрнутая рамка вдоль отрезка
            let c = item.center
            let angle = atan2(item.endPoint.y - item.startPoint.y, item.endPoint.x - item.startPoint.x)
            let len = hypot(item.endPoint.x - item.startPoint.x, item.endPoint.y - item.startPoint.y)
            let pad = item.lineHalfThickness + 5 * px
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: .radians(angle))
            let rect = CGRect(x: -len / 2 - pad, y: -pad, width: len + pad * 2, height: pad * 2)
            ctx.stroke(Path(roundedRect: rect, cornerRadius: pad), with: .color(accent.opacity(0.9)),
                       style: StrokeStyle(lineWidth: px, dash: dash))
        } else {
            applyRotation(of: item, to: &ctx)
            let box = item.boundingBox
            ctx.stroke(Path(roundedRect: box, cornerRadius: 2 * px), with: .color(accent.opacity(0.9)),
                       style: StrokeStyle(lineWidth: px, dash: dash))
            if item.supportsRotation {
                let top = CGPoint(x: box.midX, y: box.minY)
                let knob = CGPoint(x: box.midX, y: box.minY - rotateOffset)
                var line = Path()
                line.move(to: top)
                line.addLine(to: knob)
                ctx.stroke(line, with: .color(accent.opacity(0.9)), lineWidth: px)
            }
        }
        
        // Ручки (одинакового экранного размера независимо от зума)
        var handleCtx = base
        if !item.isLineLike { applyRotation(of: item, to: &handleCtx) }
        let r = 5 * px
        for (h, pos) in handlePositions(of: item) {
            let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
            let path = Path(ellipseIn: rect)
            if h == .rotate {
                handleCtx.fill(path, with: .color(accent))
                let ring = Path(ellipseIn: rect.insetBy(dx: -2 * px, dy: -2 * px))
                handleCtx.stroke(ring, with: .color(.white), lineWidth: px * 1.5)
            } else {
                handleCtx.fill(path, with: .color(.white))
                handleCtx.stroke(path, with: .color(accent), lineWidth: 1.5 * px)
            }
        }
    }
    
    private func drawItem(_ item: AnnotationItem, in context: inout GraphicsContext) {
        let rect = CGRect(
            x: min(item.startPoint.x, item.endPoint.x), y: min(item.startPoint.y, item.endPoint.y),
            width: abs(item.startPoint.x - item.endPoint.x), height: abs(item.startPoint.y - item.endPoint.y)
        )
        let style = StrokeStyle(lineWidth: item.lineWidth, lineCap: .round, lineJoin: .round)
        
        switch item.tool {
        case .select:
            break
        case .arrow:
            var p = Path()
            drawArrow(from: item.startPoint, to: item.endPoint, path: &p, headLength: max(14, item.lineWidth * 3.2))
            context.stroke(p, with: .color(item.color), style: style)
        case .rectangle:
            context.stroke(Path(rect), with: .color(item.color), style: style)
        case .roundedRect:
            context.stroke(Path(roundedRect: rect, cornerSize: CGSize(width: 10, height: 10)), with: .color(item.color), style: style)
        case .ellipse:
            context.stroke(Path(ellipseIn: rect), with: .color(item.color), style: style)
        case .counter:
            let c = item.startPoint
            let path = Path(ellipseIn: CGRect(x: c.x - 16, y: c.y - 16, width: 32, height: 32))
            context.fill(path, with: .color(item.color))
            context.draw(Text("\(item.counterNumber)").font(.system(size: 15, weight: .bold)).foregroundColor(.white), at: c)
        case .blur:
            if let blurred = blurredImage {
                var clipped = context
                clipped.clip(to: Path(rect))
                clipped.draw(Image(nsImage: blurred), in: CGRect(origin: .zero, size: blurred.size))
            } else {
                context.fill(Path(rect), with: .color(Color.gray.opacity(0.7)))
            }
            context.stroke(Path(rect), with: .color(.white.opacity(0.35)), lineWidth: 1)
        case .highlighter:
            var p = Path()
            p.move(to: item.startPoint)
            p.addLine(to: item.endPoint)
            context.stroke(p, with: .color(item.color.opacity(0.45)),
                           style: StrokeStyle(lineWidth: item.lineWidth * 4, lineCap: .round, lineJoin: .round))
        case .text:
            let t = Text(item.text.isEmpty ? "Текст" : item.text)
                .font(.system(size: item.fontSize, weight: .bold))
                .foregroundColor(item.color)
            context.draw(t, at: item.startPoint, anchor: .topLeading)
        }
    }
    
    private func drawArrow(from start: CGPoint, to end: CGPoint, path: inout Path, headLength: CGFloat) {
        path.move(to: start)
        path.addLine(to: end)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let spread: CGFloat = .pi / 6
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - headLength * cos(angle - spread), y: end.y - headLength * sin(angle - spread)))
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - headLength * cos(angle + spread), y: end.y - headLength * sin(angle + spread)))
    }
}
