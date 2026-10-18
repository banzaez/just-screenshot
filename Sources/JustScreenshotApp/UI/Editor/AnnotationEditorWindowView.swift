import SwiftUI
import AppKit

/// Главное окно редактора аннотаций: адаптивное вписывание, undo/redo, красивый фон
public struct AnnotationEditorWindowView: View {
    @ObservedObject public var model: AnnotationEditorModel
    public let onSave: (NSImage) -> Void
    public let onSaveToHistory: ((NSImage) -> Void)?
    public let onClose: () -> Void
    
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
    
    private func computeFit(for size: CGSize) -> CGFloat {
        let margin: CGFloat = 32
        let w = max(size.width - margin, 80)
        let h = max(size.height - margin, 80)
        let contentW = imgSize.width + extraPad * 2
        let contentH = imgSize.height + extraPad * 2
        guard contentW > 0, contentH > 0 else { return 1 }
        // Разрешаем upscale, чтобы мелкий скрин заполнял окно
        return max(0.05, min(w / contentW, h / contentH, 4.0))
    }
    
    private func setZoom(_ value: CGFloat) {
        manualZoom = min(max(value, 0.1), 4.0)
        fitMode = false
    }
    
    private func autoRedactSensitiveData() {
        Task { @MainActor in
            let regions = await TextRecognizer.findSensitiveRegions(in: capturedItem.image)
            guard !regions.isEmpty else { return }
            
            model.commitItemsMutation { list in
                for rect in regions {
                    list.append(AnnotationItem(
                        tool: .blur,
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                    ))
                }
            }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                EditorToolbarView(
                    selectedTool: Binding(
                        get: { model.selectedTool },
                        set: { model.selectTool($0) }
                    ),
                    selectedColor: $model.selectedColor,
                    lineWidth: $model.lineWidth,
                    zoomPercent: Int((zoom * 100).rounded()),
                    isFitMode: fitMode,
                    canUndo: model.canUndo,
                    canRedo: model.canRedo,
                    onUndo: { model.undo() },
                    onRedo: { model.redo() },
                    onZoomIn: { setZoom(zoom * 1.25) },
                    onZoomOut: { setZoom(zoom / 1.25) },
                    onFit: { fitMode = true },
                    onActualSize: { setZoom(1.0) },
                    onAutoRedact: autoRedactSensitiveData
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            EditorSelectedItemBar(
                item: model.selectedItem,
                focusTextField: model.shouldFocusTextEditor,
                onTextChange: { val in model.liveUpdateSelected { $0.text = val } },
                onFontSizeChange: { val in model.updateSelected { $0.fontSize = val } },
                onLineWidthChange: { val in model.updateSelected { $0.lineWidth = val } },
                onCounterChange: { val in model.updateSelected { $0.counterNumber = val } },
                onSetAngle: { val in model.liveUpdateSelected { $0.setAngle(val) } },
                onColorChange: { val in model.updateSelected { $0.color = val } },
                onScaleChange: { val in model.liveUpdateSelected { $0.scaleFactor = val } },
                onDuplicate: { model.duplicateSelected() },
                onDelete: { model.deleteSelected() },
                onDeselect: { model.selectItem(id: nil) },
                onTextFocusConsumed: { model.consumeTextFocusRequest() }
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
                                model: model,
                                baseImage: capturedItem.image,
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
                    onCopy: { ImageExporter.copyToClipboard(model.renderFinalImage()) },
                    onSaveToHistory: {
                        let img = model.renderFinalImage()
                        if let custom = onSaveToHistory {
                            custom(img)
                        } else {
                            HistoryStore.shared.add(img)
                        }
                        model.markSaved()
                    },
                    onSave: {
                        onSave(model.renderFinalImage())
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
            blurredImage = await BlurFilter.makeBlurredAsync(capturedItem.image)
            model.finishInitialLoading()
        }
        .editorKeyHandler(
            onDelete: { model.deleteSelected() },
            onEscape: { model.selectItem(id: nil) },
            onSelectTool: { model.selectTool($0) }
        )
        .editorKeyboardShortcuts(
            onUndo: { model.undo() },
            onRedo: { model.redo() },
            onDuplicate: { model.duplicateSelected() },
            onFit: { fitMode = true },
            onZoomIn: { setZoom(zoom * 1.25) },
            onZoomOut: { setZoom(zoom / 1.25) }
        )
    }
}
