import SwiftUI
import AppKit

/// Главное окно редактора аннотаций: адаптивное вписывание, undo/redo, фон и ленивое размытие
public struct AnnotationEditorWindowView: View {
    @Bindable public var model: AnnotationEditorModel
    public let onSave: (NSImage) -> Void
    public let onSaveToHistory: ((NSImage) -> Void)?
    public let onDelete: () -> Void
    public let onClose: () -> Void

    @State private var fitMode: Bool = true
    @State private var manualZoom: CGFloat = 1.0
    @State private var fitScale: CGFloat = 1.0
    @State private var blurredImage: NSImage?
    @State private var justCopied: Bool = false
    @State private var justCopiedTask: Task<Void, Never>?

    public init(
        model: AnnotationEditorModel,
        onSave: @escaping (NSImage) -> Void,
        onSaveToHistory: ((NSImage) -> Void)? = nil,
        onDelete: @escaping () -> Void = {},
        onClose: @escaping () -> Void
    ) {
        self.model = model
        self.onSave = onSave
        self.onSaveToHistory = onSaveToHistory
        self.onDelete = onDelete
        self.onClose = onClose
    }

    private var zoom: CGFloat { fitMode ? fitScale : manualZoom }
    private var imgSize: CGSize { model.currentBaseImage.size }
    private var extraPad: CGFloat { model.showBackdrop ? model.backdropPadding : 0 }

    private var needsBlurredImage: Bool {
        model.selectedTool == .blur || model.items.contains(where: { $0.tool == .blur })
    }

    private var blurTaskKey: String {
        "\(model.imageRevision)-\(needsBlurredImage)"
    }

    private func computeFit(for size: CGSize) -> CGFloat {
        let margin: CGFloat = 32
        let w = max(size.width - margin, 80)
        let h = max(size.height - margin, 80)
        let contentW = imgSize.width + extraPad * 2
        let contentH = imgSize.height + (model.showWindowFrame ? WindowTitlebarSpec.height : 0) + extraPad * 2
        guard contentW > 0, contentH > 0 else { return 1 }
        return max(0.05, min(w / contentW, h / contentH, 4.0))
    }

    private func setZoom(_ value: CGFloat) {
        manualZoom = min(max(value, 0.1), 4.0)
        fitMode = false
    }

    private func autoRedactSensitiveData() {
        let targetImage = model.currentBaseImage
        let targetRevision = model.imageRevision
        Task { @MainActor in
            let regions = await TextRecognizer.findSensitiveRegions(in: targetImage)
            guard !regions.isEmpty, model.imageRevision == targetRevision else { return }

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

    private var topToolbar: some View {
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    public var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow, state: .active)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topToolbar
                    .background(.ultraThinMaterial)

                Divider()

                EditorSelectedItemBar(
                    item: model.selectedItem,
                    isCropping: model.selectedTool == .crop,
                    onApplyCrop: { model.applyCrop() },
                    onResetCrop: {
                        model.resetCrop()
                        model.selectedTool = .select
                    },
                    focusTextField: model.shouldFocusTextEditor,
                    onTextChange: { val in model.liveUpdateSelected { $0.text = val } },
                    onFontSizeChange: { val in
                        model.fontSize = val
                        model.updateSelected { $0.fontSize = val }
                    },
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

                    let titlebarH = model.showWindowFrame ? WindowTitlebarSpec.height * z : 0
                    let totalH = displayH + titlebarH

                    ScrollView([.horizontal, .vertical]) {
                        ZStack {
                            if model.showBackdrop {
                                Rectangle().fill(model.backdropPreset.gradient)
                            }
                            VStack(spacing: 0) {
                                if model.showWindowFrame {
                                    MacOSWindowHeaderView(scale: z)
                                        .frame(width: displayW, height: titlebarH)
                                }
                                ZStack {
                                    Image(nsImage: model.currentBaseImage)
                                        .resizable()
                                        .frame(width: displayW, height: displayH)
                                    AnnotationCanvasView(
                                        model: model,
                                        baseImage: model.currentBaseImage,
                                        zoomScale: z,
                                        blurredImage: blurredImage
                                    )
                                    .frame(width: displayW, height: displayH)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: (model.showBackdrop || model.showWindowFrame) ? model.backdropCornerRadius * z : 0))
                            .shadow(
                                color: .black.opacity(model.showBackdrop && model.addShadow ? 0.4 : 0),
                                radius: model.backdropShadowRadius * z,
                                x: 0,
                                y: model.backdropShadowRadius * 0.4 * z
                            )
                        }
                        .frame(width: displayW + pad * 2, height: totalH + pad * 2)
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
                    .onChange(of: model.showWindowFrame) { _, _ in fitScale = computeFit(for: geo.size) }
                    .onChange(of: model.imageRevision) { _, _ in
                        fitScale = computeFit(for: geo.size)
                        blurredImage = nil
                    }
                }

                Divider()

                EditorBottomBarView(
                    showBackdrop: $model.showBackdrop,
                    backdropPreset: $model.backdropPreset,
                    backdropPadding: $model.backdropPadding,
                    backdropCornerRadius: $model.backdropCornerRadius,
                    backdropShadowRadius: $model.backdropShadowRadius,
                    addShadow: $model.addShadow,
                    showWindowFrame: $model.showWindowFrame,
                    justCopied: $justCopied,
                    onClose: onClose,
                    onDelete: onDelete,
                    onCopy: copyAction,
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .onAppear {
            model.finishInitialLoading()
        }
        .onDisappear {
            justCopiedTask?.cancel()
            model.flushPendingEdits()
        }
        .task(id: blurTaskKey) {
            guard needsBlurredImage else { return }
            let revision = model.imageRevision
            let base = model.currentBaseImage
            let blurred = await BlurFilter.makeBlurredAsync(base, id: model.capturedItem.id, revision: revision)
            guard !Task.isCancelled, model.imageRevision == revision else { return }
            blurredImage = blurred
        }
        .editorKeyHandler(
            onDelete: { model.deleteSelected() },
            onEscape: {
                if model.selectedItemID != nil {
                    model.selectItem(id: nil)
                    return true
                }
                if model.selectedTool == .crop {
                    model.selectTool(.select)
                    return true
                }
                return false
            },
            onSelectTool: { model.selectTool($0) },
            onCopy: copyAction
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

    private func copyAction() {
        let finalImage = model.renderFinalImage()
        ImageExporter.copyToClipboard(finalImage)
        if model.hasUnsavedChanges {
            if let custom = onSaveToHistory {
                custom(finalImage)
            } else {
                HistoryStore.shared.add(finalImage)
            }
            model.markSaved()
        }
        justCopiedTask?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) { justCopied = true }
        justCopiedTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.18)) { justCopied = false }
        }
    }
}

/// Заголовок окна в стиле macOS с тремя кнопками-светофорами
private struct MacOSWindowHeaderView: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: WindowTitlebarSpec.buttonSpacing * scale) {
            ForEach(Array(WindowTitlebarSpec.trafficLightRGB.enumerated()), id: \.offset) { _, rgb in
                Circle()
                    .fill(Color(red: rgb.r, green: rgb.g, blue: rgb.b))
                    .frame(width: WindowTitlebarSpec.buttonDiameter * scale, height: WindowTitlebarSpec.buttonDiameter * scale)
                    .overlay(Circle().stroke(Color.black.opacity(WindowTitlebarSpec.borderWhiteAlpha), lineWidth: max(0.25, 0.5 * scale)))
            }
            Spacer()
        }
        .padding(.horizontal, WindowTitlebarSpec.leadingInset * scale)
        .frame(maxHeight: .infinity)
        .background(Color(white: WindowTitlebarSpec.backgroundWhite))
    }
}
