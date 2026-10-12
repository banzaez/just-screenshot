import SwiftUI
import AppKit

/// Главное окно редактора аннотаций: адаптивное вписывание, undo/redo, красивый фон
public struct AnnotationEditorWindowView: View {
    public let capturedItem: CapturedItem
    public let onSave: (NSImage) -> Void
    public let onClose: () -> Void
    
    @State private var items: [AnnotationItem] = []
    @State private var undoStack: [[AnnotationItem]] = []
    @State private var redoStack: [[AnnotationItem]] = []
    @State private var isRestoring = false
    @State private var lastPushTime = Date.distantPast
    @State private var selectedItemID: UUID? = nil
    
    @State private var selectedTool: AnnotationTool = .select
    @State private var selectedColor: Color = .red
    @State private var lineWidth: CGFloat = 4.0
    @State private var textInputString: String = "Текст заметки"
    
    @State private var showBackdrop: Bool = true
    @State private var backdropPreset: BackdropPreset = .aurora
    @State private var backdropPadding: CGFloat = 48
    @State private var addShadow: Bool = true
    
    @State private var fitMode: Bool = true
    @State private var manualZoom: CGFloat = 1.0
    @State private var fitScale: CGFloat = 1.0
    @State private var blurredImage: NSImage?
    
    public init(capturedItem: CapturedItem, onSave: @escaping (NSImage) -> Void, onClose: @escaping () -> Void) {
        self.capturedItem = capturedItem
        self.onSave = onSave
        self.onClose = onClose
    }
    
    private var zoom: CGFloat { fitMode ? fitScale : manualZoom }
    private var imgSize: CGSize { capturedItem.image.size }
    private var extraPad: CGFloat { showBackdrop ? backdropPadding : 0 }
    
    private var selectedItemIndex: Int? {
        guard let id = selectedItemID else { return nil }
        return items.firstIndex(where: { $0.id == id })
    }
    
    private func computeFit(for size: CGSize) -> CGFloat {
        let margin: CGFloat = 32
        let w = max(size.width - margin, 80)
        let h = max(size.height - margin, 80)
        let contentW = imgSize.width + extraPad * 2
        let contentH = imgSize.height + extraPad * 2
        guard contentW > 0, contentH > 0 else { return 1 }
        // Уменьшаем под окно, при большом окне — не растягиваем больше 100%
        return max(0.05, min(w / contentW, h / contentH, 1.0))
    }
    
    private func setZoom(_ value: CGFloat) {
        manualZoom = min(max(value, 0.1), 4.0)
        fitMode = false
    }
    
    private func undo() {
        guard let prev = undoStack.popLast() else { return }
        isRestoring = true
        redoStack.append(items)
        items = prev
        selectedItemID = nil
        DispatchQueue.main.async { isRestoring = false }
    }
    
    private func redo() {
        guard let next = redoStack.popLast() else { return }
        isRestoring = true
        undoStack.append(items)
        items = next
        selectedItemID = nil
        DispatchQueue.main.async { isRestoring = false }
    }
    
    private func finalImage() -> NSImage {
        AnnotationRenderer.render(
            baseImage: capturedItem.image,
            items: items,
            backdrop: showBackdrop ? backdropPreset : nil,
            padding: backdropPadding,
            shadow: addShadow
        )
    }
    
    private func duplicateSelected() {
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
        items.append(copy)
        selectedItemID = copy.id
    }
    
    private func deleteSelected() {
        guard let idx = selectedItemIndex else { return }
        items.remove(at: idx)
        selectedItemID = nil
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                EditorToolbarView(
                    selectedTool: $selectedTool,
                    selectedColor: $selectedColor,
                    lineWidth: $lineWidth,
                    textInputString: $textInputString,
                    zoomPercent: Int((zoom * 100).rounded()),
                    isFitMode: fitMode,
                    canUndo: !undoStack.isEmpty,
                    canRedo: !redoStack.isEmpty,
                    onUndo: undo,
                    onRedo: redo,
                    onZoomIn: { setZoom(zoom * 1.25) },
                    onZoomOut: { setZoom(zoom / 1.25) },
                    onFit: { fitMode = true },
                    onActualSize: { setZoom(1.0) }
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            if let idx = selectedItemIndex {
                EditorSelectedItemBar(
                    item: items[idx],
                    onTextChange: { items[idx].text = $0 },
                    onFontSizeChange: { items[idx].fontSize = $0 },
                    onLineWidthChange: { items[idx].lineWidth = $0 },
                    onCounterChange: { items[idx].counterNumber = $0 },
                    onSetAngle: { items[idx].setAngle($0) },
                    onColorChange: { items[idx].color = $0 },
                    onDuplicate: duplicateSelected,
                    onDelete: deleteSelected,
                    onDeselect: { selectedItemID = nil }
                )
                Divider()
            }
            
            GeometryReader { geo in
                let z = zoom
                let displayW = imgSize.width * z
                let displayH = imgSize.height * z
                let pad = extraPad * z
                
                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        if showBackdrop {
                            Rectangle().fill(backdropPreset.gradient)
                        }
                        ZStack {
                            Image(nsImage: capturedItem.image)
                                .resizable()
                                .frame(width: displayW, height: displayH)
                            AnnotationCanvasView(
                                items: $items,
                                selectedItemID: $selectedItemID,
                                currentTool: selectedTool,
                                currentColor: selectedColor,
                                lineWidth: lineWidth,
                                textInputString: textInputString,
                                zoomScale: z,
                                blurredImage: blurredImage
                            )
                            .frame(width: displayW, height: displayH)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: showBackdrop ? 10 * z : 0))
                        .shadow(color: .black.opacity(showBackdrop && addShadow ? 0.4 : 0), radius: 24 * z, x: 0, y: 10 * z)
                    }
                    .frame(width: displayW + pad * 2, height: displayH + pad * 2)
                    .frame(
                        minWidth: geo.size.width,
                        minHeight: geo.size.height
                    )
                    .background(Color(nsColor: .underPageBackgroundColor))
                }
                .onChange(of: geo.size, initial: true) { _, newSize in
                    fitScale = computeFit(for: newSize)
                }
                .onChange(of: showBackdrop) { _, _ in fitScale = computeFit(for: geo.size) }
                .onChange(of: backdropPadding) { _, _ in fitScale = computeFit(for: geo.size) }
            }
            
            Divider()
            
            ScrollView(.horizontal, showsIndicators: false) {
                EditorBottomBarView(
                    showBackdrop: $showBackdrop,
                    backdropPreset: $backdropPreset,
                    backdropPadding: $backdropPadding,
                    addShadow: $addShadow,
                    onClose: onClose,
                    onCopy: { ImageExporter.copyToClipboard(finalImage()) },
                    onSave: { onSave(finalImage()) }
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minWidth: 760)
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 640, minHeight: 460)
        .task {
            await Task.yield()
            blurredImage = BlurFilter.makeBlurred(capturedItem.image)
        }
        .onChange(of: items) { old, _ in
            guard !isRestoring else { return }
            // Склеиваем быстрые изменения (перетаскивание, набор текста) в один шаг отмены
            if Date().timeIntervalSince(lastPushTime) > 0.5 {
                undoStack.append(old)
                if undoStack.count > 100 { undoStack.removeFirst() }
            }
            lastPushTime = Date()
            redoStack.removeAll()
        }
        .background(shortcuts)
    }
    
    /// Скрытые горячие клавиши редактора
    private var shortcuts: some View {
        Group {
            Button("") { undo() }.keyboardShortcut("z", modifiers: [.command])
            Button("") { redo() }.keyboardShortcut("z", modifiers: [.command, .shift])
            Button("") { duplicateSelected() }.keyboardShortcut("d", modifiers: [.command])
            Button("") { deleteSelected() }.keyboardShortcut(.delete, modifiers: [.command])
            Button("") { selectedItemID = nil }.keyboardShortcut(.escape, modifiers: [])
            Button("") { fitMode = true }.keyboardShortcut("0", modifiers: [.command])
            Button("") { setZoom(zoom * 1.25) }.keyboardShortcut("=", modifiers: [.command])
            Button("") { setZoom(zoom / 1.25) }.keyboardShortcut("-", modifiers: [.command])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
    }
}
