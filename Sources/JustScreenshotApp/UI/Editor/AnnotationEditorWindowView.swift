import SwiftUI
import AppKit

/// Главное окно редактора аннотаций: адаптивное вписывание, undo/redo, красивый фон
public struct AnnotationEditorWindowView: View {
    @ObservedObject public var model: AnnotationEditorModel
    public let onSave: (NSImage) -> Void
    public let onSaveToHistory: ((NSImage) -> Void)?
    public let onClose: () -> Void
    
    @State private var selectedItemID: UUID? = nil
    
    @State private var selectedTool: AnnotationTool = .select
    @State private var selectedColor: Color = .red
    @State private var lineWidth: CGFloat = 4.0
    @State private var textInputString: String = "Текст заметки"
    
    @State private var fitMode: Bool = true
    @State private var manualZoom: CGFloat = 1.0
    @State private var fitScale: CGFloat = 1.0
    @State private var blurredImage: NSImage?
    
    public init(
        model: AnnotationEditorModel,
        onSave: @escaping (NSImage) -> Void,
        onSaveToHistory: ((NSImage) -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.model = model
        self.onSave = onSave
        self.onSaveToHistory = onSaveToHistory
        self.onClose = onClose
    }
    
    private var capturedItem: CapturedItem { model.capturedItem }
    private var zoom: CGFloat { fitMode ? fitScale : manualZoom }
    private var imgSize: CGSize { capturedItem.image.size }
    private var extraPad: CGFloat { model.showBackdrop ? model.backdropPadding : 0 }
    
    private var selectedItemIndex: Int? {
        guard let id = selectedItemID else { return nil }
        return model.items.firstIndex(where: { $0.id == id })
    }
    
    private func computeFit(for size: CGSize) -> CGFloat {
        let margin: CGFloat = 32
        let w = max(size.width - margin, 80)
        let h = max(size.height - margin, 80)
        let contentW = imgSize.width + extraPad * 2
        let contentH = imgSize.height + extraPad * 2
        guard contentW > 0, contentH > 0 else { return 1 }
        return max(0.05, min(w / contentW, h / contentH, 1.0))
    }
    
    private func setZoom(_ value: CGFloat) {
        manualZoom = min(max(value, 0.1), 4.0)
        fitMode = false
    }
    
    private func undo() {
        model.undo()
        selectedItemID = nil
    }
    
    private func redo() {
        model.redo()
        selectedItemID = nil
    }
    
    private func finalImage() -> NSImage {
        model.renderFinalImage()
    }
    
    private func duplicateSelected() {
        guard let idx = selectedItemIndex else { return }
        let o = model.items[idx]
        let copy = AnnotationItem(
            tool: o.tool,
            startPoint: CGPoint(x: o.startPoint.x + 24, y: o.startPoint.y + 24),
            endPoint: CGPoint(x: o.endPoint.x + 24, y: o.endPoint.y + 24),
            color: o.color, lineWidth: o.lineWidth, text: o.text,
            counterNumber: o.counterNumber + 1, fontSize: o.fontSize,
            rotationAngle: o.rotationAngle, scaleFactor: o.scaleFactor
        )
        model.items.append(copy)
        model.markModified()
        selectedItemID = copy.id
    }
    
    private func deleteSelected() {
        guard let idx = selectedItemIndex else { return }
        model.items.remove(at: idx)
        model.markModified()
        selectedItemID = nil
    }
    
    private func autoRedactSensitiveData() {
        Task { @MainActor in
            let regions = await TextRecognizer.findSensitiveRegions(in: capturedItem.image)
            guard !regions.isEmpty else { return }
            
            model.pushExplicitUndoCheckpoint()
            
            for rect in regions {
                let blurItem = AnnotationItem(
                    tool: .blur,
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
                model.items.append(blurItem)
            }
            model.markModified()
        }
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
                    canUndo: model.canUndo,
                    canRedo: model.canRedo,
                    onUndo: undo,
                    onRedo: redo,
                    onZoomIn: { setZoom(zoom * 1.25) },
                    onZoomOut: { setZoom(zoom / 1.25) },
                    onFit: { fitMode = true },
                    onActualSize: { setZoom(1.0) },
                    onAutoRedact: autoRedactSensitiveData
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            EditorSelectedItemBar(
                item: selectedItemIndex.map { model.items[$0] },
                onTextChange: { val in if let idx = selectedItemIndex { model.items[idx].text = val; model.markModified() } },
                onFontSizeChange: { val in if let idx = selectedItemIndex { model.items[idx].fontSize = val; model.markModified() } },
                onLineWidthChange: { val in if let idx = selectedItemIndex { model.items[idx].lineWidth = val; model.markModified() } },
                onCounterChange: { val in if let idx = selectedItemIndex { model.items[idx].counterNumber = val; model.markModified() } },
                onSetAngle: { val in if let idx = selectedItemIndex { model.items[idx].setAngle(val); model.markModified() } },
                onColorChange: { val in if let idx = selectedItemIndex { model.items[idx].color = val; model.markModified() } },
                onDuplicate: duplicateSelected,
                onDelete: deleteSelected,
                onDeselect: { selectedItemID = nil }
            )
            
            Divider()
            
            GeometryReader { geo in
                let z = zoom
                let displayW = imgSize.width * z
                let displayH = imgSize.height * z
                let pad = extraPad * z
                
                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        if model.showBackdrop {
                            Rectangle().fill(model.backdropPreset.gradient)
                        }
                        ZStack {
                            Image(nsImage: capturedItem.image)
                                .resizable()
                                .frame(width: displayW, height: displayH)
                            AnnotationCanvasView(
                                items: $model.items,
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
                        .clipShape(RoundedRectangle(cornerRadius: model.showBackdrop ? model.backdropCornerRadius * z : 0))
                        .shadow(color: .black.opacity(model.showBackdrop && model.addShadow ? 0.4 : 0), radius: model.backdropShadowRadius * z, x: 0, y: model.backdropShadowRadius * 0.4 * z)
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
                .onChange(of: model.showBackdrop) { _, _ in fitScale = computeFit(for: geo.size) }
                .onChange(of: model.backdropPadding) { _, _ in fitScale = computeFit(for: geo.size) }
            }
            
            Divider()
            
            ScrollView(.horizontal, showsIndicators: false) {
                EditorBottomBarView(
                    showBackdrop: $model.showBackdrop,
                    backdropPreset: $model.backdropPreset,
                    backdropPadding: $model.backdropPadding,
                    backdropCornerRadius: $model.backdropCornerRadius,
                    backdropShadowRadius: $model.backdropShadowRadius,
                    addShadow: $model.addShadow,
                    onClose: onClose,
                    onCopy: { ImageExporter.copyToClipboard(finalImage()) },
                    onSaveToHistory: {
                        let img = finalImage()
                        if let custom = onSaveToHistory {
                            custom(img)
                        } else {
                            HistoryStore.shared.add(img)
                        }
                        model.markSaved()
                    },
                    onSave: {
                        onSave(finalImage())
                    }
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
            model.finishInitialLoading()
        }
        .onChange(of: model.items) { old, _ in
            model.recordStateChange(oldItems: old)
        }
        .onChange(of: model.showBackdrop) { _, _ in model.markModified() }
        .onChange(of: model.backdropPreset) { _, _ in model.markModified() }
        .onChange(of: model.backdropPadding) { _, _ in model.markModified() }
        .onChange(of: model.addShadow) { _, _ in model.markModified() }
        .onEditorDeleteKey(
            onDelete: deleteSelected,
            onEscape: { selectedItemID = nil }
        )
        .editorKeyboardShortcuts(
            onUndo: undo,
            onRedo: redo,
            onDuplicate: duplicateSelected,
            onDelete: deleteSelected,
            onDeselect: { selectedItemID = nil },
            onFit: { fitMode = true },
            onZoomIn: { setZoom(zoom * 1.25) },
            onZoomOut: { setZoom(zoom / 1.25) }
        )
    }
}
