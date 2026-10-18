import SwiftUI
import AVKit

/// Главное окно профессионального видеоредактора
public struct VideoEditorWindowView: View {
    @ObservedObject var model: VideoEditorModel
    var onClose: () -> Void
    
    public init(model: VideoEditorModel, onClose: @escaping () -> Void) {
        self.model = model
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Верхний тулбар
            VideoEditorToolbarView(
                model: model,
                onExportMP4: { performExport(isGIF: false) },
                onExportGIF: { performExport(isGIF: true) }
            )
            
            // 2. Контекстная панель выбранного элемента (свойства, цвет, поворот, дублирование, удаление)
            VideoSelectedItemBar(model: model)
            
            // 3. Основная рабочая область (Плеер + Canvas оверлей)
            ZStack {
                Color.black
                
                VideoPlayerRepresentable(player: model.player)
                
                VideoOverlayCanvasView(model: model)
                
                // Оверлей процесса экспорта
                if model.isExporting {
                    ZStack {
                        Color.black.opacity(0.7)
                        VStack(spacing: 12) {
                            ProgressView(value: model.exportProgress)
                                .progressViewStyle(.linear)
                                .frame(width: 240)
                            Text(model.exportStatusText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 3. Нижняя панель (Таймлайн и управление воспроизведением)
            VStack(spacing: 0) {
                // Таймлайн обрезки с превью кадров
                VideoTimelineView(model: model)
                
                // Кнопки управления воспроизведением (Play/Pause, шаг кадра)
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
                    
                    Text(L("video_editor.duration", String(format: "%.1f", model.trimEnd - model.trimStart)))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .preferredColorScheme(.dark)
        .editorKeyHandler(
            onDelete: {
                if let id = model.selectedAnnotationID {
                    model.removeAnnotation(id: id)
                }
            },
            onEscape: {
                model.selectedAnnotationID = nil
            }
        )
    }
    
    private func performExport(isGIF: Bool) {
        model.pause()
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = isGIF ? [.gif] : [.mpeg4Movie]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = isGIF ? "Animation.gif" : "VideoEdit.mp4"
        
        NSApp.activate(ignoringOtherApps: true)
        guard savePanel.runModal() == .OK, let targetURL = savePanel.url else { return }
        
        model.isExporting = true
        model.exportProgress = 0.0
        model.exportStatusText = isGIF ? L("video_editor.exporting_gif") : L("video_editor.exporting_mp4")
        
        let options = VideoExportService.ExportOptions(
            trimStart: model.trimStart,
            trimEnd: model.trimEnd,
            playbackRate: model.playbackRate,
            cropRect: model.isCropping ? model.cropRect : nil,
            gifFPS: 15,
            annotations: model.annotations
        )
        let sourceURL = model.videoURL
        
        Task {
            do {
                let onProgress: @Sendable (Double) -> Void = { progress in
                    Task { @MainActor in
                        self.model.exportProgress = progress
                    }
                }
                if isGIF {
                    try await VideoExportService.shared.exportGIF(
                        sourceURL: sourceURL,
                        destinationURL: targetURL,
                        options: options,
                        progressHandler: onProgress
                    )
                } else {
                    try await VideoExportService.shared.exportVideo(
                        sourceURL: sourceURL,
                        destinationURL: targetURL,
                        options: options,
                        progressHandler: onProgress
                    )
                }
                
                await MainActor.run {
                    self.model.isExporting = false
                    NSWorkspace.shared.activateFileViewerSelecting([targetURL])
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
    }
}
