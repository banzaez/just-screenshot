import SwiftUI
import AVKit

/// Главное окно профессионального видеоредактора
public struct VideoEditorWindowView: View {
    var model: VideoEditorModel
    var onDelete: (() -> Void)?
    @State private var justCopied = false
    @State private var justCopiedTask: Task<Void, Never>?

    public init(
        model: VideoEditorModel,
        onDelete: (() -> Void)? = nil
    ) {
        self.model = model
        self.onDelete = onDelete
    }

    public var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow, state: .active)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. Верхний тулбар
                VideoEditorToolbarView(
                    model: model,
                    justCopied: justCopied,
                    onCopy: { performCopy() },
                    onExportMP4: { performExport(format: .mp4) },
                    onExportGIF: { performExport(format: .gif) },
                    onExportWebP: { performExport(format: .webp) },
                    onDelete: onDelete
                )
                .zIndex(1)

                // 2. Основная рабочая область (Плеер + Canvas оверлей + Crop вне зума)
                ZStack {
                    Color.black

                    GeometryReader { geo in
                        let containerSize = geo.size
                        let videoRect = model.videoContentRect(in: containerSize)

                        let zoom = model.isSmartZoomEnabled ? model.currentCameraZoom : 1.0
                        let maxPanX = max(0, (videoRect.width * (zoom - 1.0)) / 2)
                        let maxPanY = max(0, (videoRect.height * (zoom - 1.0)) / 2)

                        let rawPanX = (0.5 - model.currentCameraFocus.x) * videoRect.width * (zoom - 1.0)
                        let rawPanY = (0.5 - model.currentCameraFocus.y) * videoRect.height * (zoom - 1.0)

                        let panX = min(maxPanX, max(-maxPanX, rawPanX))
                        let panY = min(maxPanY, max(-maxPanY, rawPanY))

                        ZStack {
                            Group {
                                VideoPlayerRepresentable(player: model.player)
                                VideoOverlayCanvasView(model: model)

                                // Постпроцессинг подсветки кликов мыши в координатах исходного видео
                                if model.isClickHighlightsEnabled && !model.activeClickRipples.isEmpty {
                                    ZStack {
                                        ForEach(Array(model.activeClickRipples.enumerated()), id: \.offset) { _, ripple in
                                            let radius = 8.0 + ripple.progress * 24.0
                                            let alpha = Double(max(0, 1.0 - ripple.progress))
                                            let px = videoRect.origin.x + ripple.point.x * videoRect.width
                                            let py = videoRect.origin.y + ripple.point.y * videoRect.height
                                            let strokeColor: Color = ripple.isRightClick ? Color(red: 1.0, green: 0.65, blue: 0.25) : Color(red: 0.35, green: 0.72, blue: 1.0)
                                            let fillColor: Color = ripple.isRightClick ? Color(red: 1.0, green: 0.6, blue: 0.2) : Color(red: 0.2, green: 0.6, blue: 1.0)

                                            Circle()
                                                .fill(fillColor.opacity(0.24 * alpha))
                                                .overlay(Circle().stroke(strokeColor.opacity(0.85 * alpha), lineWidth: 2.2))
                                                .frame(width: radius * 2, height: radius * 2)
                                                .position(x: px, y: py)
                                        }
                                    }
                                    .allowsHitTesting(false)
                                }

                                // Постпроцессинг красного эффекта в месте ввода текста
                                if model.isTypingHighlightEnabled && !model.activeTypingEffects.isEmpty {
                                    ZStack {
                                        ForEach(Array(model.activeTypingEffects.enumerated()), id: \.offset) { _, effect in
                                            let radius = 6.0 + effect.progress * 18.0
                                            let alpha = Double(max(0, 1.0 - effect.progress))
                                            let px = videoRect.origin.x + effect.point.x * videoRect.width
                                            let py = videoRect.origin.y + effect.point.y * videoRect.height

                                            Circle()
                                                .fill(Color.red.opacity(0.26 * alpha))
                                                .overlay(Circle().stroke(Color.red.opacity(0.9 * alpha), lineWidth: 2.0))
                                                .shadow(color: Color.red.opacity(0.5 * alpha), radius: 6)
                                                .frame(width: radius * 2, height: radius * 2)
                                                .position(x: px, y: py)
                                        }
                                    }
                                    .allowsHitTesting(false)
                                }
                            }
                            .scaleEffect(zoom, anchor: .center)
                            .offset(x: panX, y: panY)
                            .animation(.interpolatingSpring(stiffness: 110, damping: 16), value: model.currentCameraFocus)
                            .animation(.interpolatingSpring(stiffness: 110, damping: 16), value: model.currentCameraZoom)
                            .animation(.easeInOut(duration: 0.28), value: model.isSmartZoomEnabled)

                            // Рамка кадрирования всегда находится в координатах незумированного кадра
                            if model.isCropping {
                                NormalizedCropOverlayView(
                                    cropRect: Bindable(model).cropRect,
                                    containerSize: containerSize,
                                    contentRect: videoRect
                                )
                            }

                            // Постпроцессинг бейджа нажатых клавиш (Keystrokes HUD) с учётом Smart Zoom
                            if model.isKeystrokesEnabled,
                               let text = model.currentKeystrokeText,
                               model.currentKeystrokeAlpha > 0.001 {
                                let resolvedPos = model.keystrokePosition.resolved(
                                    cameraFocus: model.currentCameraFocus,
                                    cameraZoom: zoom
                                )
                                let sizeScale = CGFloat(model.keystrokeSize.rawValue)
                                let edgeInset: CGFloat = 24
                                let alignment: Alignment = {
                                    switch resolvedPos {
                                    case .bottomCenter: return .bottom
                                    case .bottomLeft: return .bottomLeading
                                    case .bottomRight: return .bottomTrailing
                                    case .topCenter: return .top
                                    }
                                }()

                                Text(text)
                                    .font(.system(size: 16 * sizeScale, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16 * sizeScale)
                                    .padding(.vertical, 9 * sizeScale)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10 * sizeScale, style: .continuous)
                                            .fill(Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.92))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10 * sizeScale, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.32), lineWidth: 1.2)
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.55), radius: 10, y: 3)
                                    .padding(edgeInset)
                                    .frame(width: videoRect.width, height: videoRect.height, alignment: alignment)
                                    .position(x: videoRect.midX, y: videoRect.midY)
                                    .opacity(Double(model.currentKeystrokeAlpha))
                                    .animation(.easeInOut(duration: 0.2), value: resolvedPos)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .clipped()
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(0)

                // 3. Нижняя панель (Таймлайн и управление воспроизведением)
                VStack(spacing: 0) {
                    VideoTimelineView(model: model)

                    HStack(spacing: 16) {
                        Button {
                            model.seek(to: model.currentTime - 1.0)
                        } label: {
                            Image(systemName: "gobackward")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help(L("video_editor.back_1s"))
                        .accessibilityLabel(L("video_editor.back_1s"))

                        Button {
                            model.togglePlayPause()
                        } label: {
                            Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.space, modifiers: [])
                        .help(L("video_editor.play_pause"))
                        .accessibilityLabel(L("video_editor.play_pause"))

                        Button {
                            model.seek(to: model.currentTime + 1.0)
                        } label: {
                            Image(systemName: "goforward")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help(L("video_editor.forward_1s"))
                        .accessibilityLabel(L("video_editor.forward_1s"))

                        Spacer()

                        let effectiveDuration = max(0, (model.trimEnd - model.trimStart) / Double(max(0.1, model.playbackRate)))
                        Text(L("video_editor.duration", String(format: "%.1f", effectiveDuration)))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                }
                .zIndex(1)
            }
            .disabled(model.isExporting)

            // Полнооконный оверлей экспорта с кнопкой отмены
            if model.isExporting {
                ZStack {
                    Color.black.opacity(0.72)
                        .ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView(value: model.exportProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 240)
                        Text(model.exportStatusText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Button(L("video_editor.cancel_export")) {
                            model.cancelExport()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            justCopiedTask?.cancel()
        }
        .editorKeyHandler(
            onDelete: {
                if let id = model.selectedAnnotationID {
                    model.removeAnnotation(id: id)
                }
            },
            onEscape: {
                if model.selectedAnnotationID != nil {
                    model.selectedAnnotationID = nil
                    return true
                }
                if model.isCropping {
                    model.isCropping = false
                    return true
                }
                return false
            }
        )
    }

    private enum ExportFormat {
        case mp4
        case gif
        case webp
    }

    private func triggerCopiedBadge() {
        justCopiedTask?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) { justCopied = true }
        justCopiedTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.15)) { justCopied = false }
        }
    }

    private func performCopy() {
        if !model.hasEdits {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([model.videoURL as NSURL])
            triggerCopiedBadge()
            return
        }

        model.pause()
        model.isExporting = true
        model.exportProgress = 0.0
        model.exportStatusText = L("video_editor.exporting_mp4")

        let options = model.currentExportOptions()
        let sourceURL = model.videoURL
        let tempDir = FileManager.default.temporaryDirectory
        cleanupStaleCopiedClips(in: tempDir)
        let targetURL = tempDir.appendingPathComponent("JustScreenshot-Clip-\(UUID().uuidString.prefix(8)).mp4")

        let task = Task {
            defer {
                Task { @MainActor in
                    self.model.clearExportTask()
                }
            }
            do {
                let onProgress: @Sendable (Double) -> Void = { progress in
                    Task { @MainActor in
                        self.model.exportProgress = progress
                    }
                }
                try await VideoExportService.shared.exportVideo(
                    sourceURL: sourceURL,
                    destinationURL: targetURL,
                    options: options,
                    progressHandler: onProgress
                )
                try Task.checkCancellation()
                await MainActor.run {
                    self.model.isExporting = false
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.writeObjects([targetURL as NSURL])
                    self.triggerCopiedBadge()
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.model.isExporting = false
                }
            } catch {
                await MainActor.run {
                    self.model.isExporting = false
                    let alert = NSAlert()
                    alert.messageText = L("video_editor.export_error")
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
        model.registerExportTask(task)
    }

    private func cleanupStaleCopiedClips(in tempDir: URL) {
        let cutoff = Date().addingTimeInterval(-3600)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for url in urls where url.lastPathComponent.hasPrefix("JustScreenshot-Clip-") && url.pathExtension == "mp4" {
            if let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
               date < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func performExport(format: ExportFormat) {
        model.pause()

        let savePanel = NSSavePanel()
        switch format {
        case .mp4:
            savePanel.allowedContentTypes = [.mpeg4Movie]
            savePanel.nameFieldStringValue = "VideoEdit.mp4"
            model.exportStatusText = L("video_editor.exporting_mp4")
        case .gif:
            savePanel.allowedContentTypes = [.gif]
            savePanel.nameFieldStringValue = "Animation.gif"
            model.exportStatusText = L("video_editor.exporting_gif")
        case .webp:
            savePanel.allowedContentTypes = [.webP]
            savePanel.nameFieldStringValue = "Animation.webp"
            model.exportStatusText = L("video_editor.exporting_webp")
        }
        savePanel.directoryURL = ImageExporter.defaultSaveDirectoryURL()
        savePanel.canCreateDirectories = true

        NSApp.activate()
        guard savePanel.runModal() == .OK, let targetURL = savePanel.url else { return }

        model.isExporting = true
        model.exportProgress = 0.0

        let options = model.currentExportOptions(gifFPS: 15)
        let sourceURL = model.videoURL

        let task = Task {
            defer {
                Task { @MainActor in
                    self.model.clearExportTask()
                }
            }
            do {
                let onProgress: @Sendable (Double) -> Void = { progress in
                    Task { @MainActor in
                        self.model.exportProgress = progress
                    }
                }
                switch format {
                case .mp4:
                    try await VideoExportService.shared.exportVideo(
                        sourceURL: sourceURL,
                        destinationURL: targetURL,
                        options: options,
                        progressHandler: onProgress
                    )
                case .gif:
                    try await VideoExportService.shared.exportGIF(
                        sourceURL: sourceURL,
                        destinationURL: targetURL,
                        options: options,
                        progressHandler: onProgress
                    )
                case .webp:
                    try await VideoExportService.shared.exportWebP(
                        sourceURL: sourceURL,
                        destinationURL: targetURL,
                        options: options,
                        progressHandler: onProgress
                    )
                }

                try Task.checkCancellation()
                await MainActor.run {
                    self.model.isExporting = false
                    if format == .mp4 {
                        let crop = self.model.hasCustomCrop ? self.model.cropRect : CGRect(x: 0, y: 0, width: 1, height: 1)
                        let outW = max(1, Int(self.model.naturalSize.width * crop.width))
                        let outH = max(1, Int(self.model.naturalSize.height * crop.height))
                        let outDur = max(0.1, (self.model.trimEnd - self.model.trimStart) / Double(max(0.1, self.model.playbackRate)))
                        HistoryStore.shared.addVideo(
                            url: targetURL,
                            width: outW,
                            height: outH,
                            duration: outDur
                        )
                    }
                    NSWorkspace.shared.activateFileViewerSelecting([targetURL])
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.model.isExporting = false
                }
            } catch {
                await MainActor.run {
                    self.model.isExporting = false
                    let alert = NSAlert()
                    alert.messageText = L("video_editor.export_error")
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
        model.registerExportTask(task)
    }
}
