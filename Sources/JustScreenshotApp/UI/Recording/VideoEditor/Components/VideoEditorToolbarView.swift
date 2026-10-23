import SwiftUI
import AppKit

/// Верхняя панель инструментов видеоредактора
public struct VideoEditorToolbarView: View {
    @ObservedObject var model: VideoEditorModel
    var onExportMP4: () -> Void
    var onExportGIF: () -> Void
    var onExportWebP: () -> Void
    
    public init(
        model: VideoEditorModel,
        onExportMP4: @escaping () -> Void,
        onExportGIF: @escaping () -> Void,
        onExportWebP: @escaping () -> Void
    ) {
        self.model = model
        self.onExportMP4 = onExportMP4
        self.onExportGIF = onExportGIF
        self.onExportWebP = onExportWebP
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            // Добавление аннотаций
            HStack(spacing: 2) {
                ForEach(VideoAnnotationType.allCases) { type in
                    EditorIconButton(
                        type.icon,
                        title: L("video_editor.add_annotation", type.localizedTitle),
                        width: 40
                    ) {
                        model.addAnnotation(type: type)
                    }
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            
            // Стиль новых / выбранных
            HStack(spacing: 8) {
                ColorDropdown(
                    selection: Binding(
                        get: { model.annotationColor },
                        set: { model.setAnnotationColor($0) }
                    )
                )
                WidthDropdown(
                    selection: Binding(
                        get: { model.annotationLineWidth },
                        set: { model.setAnnotationLineWidth($0) }
                    )
                )
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            
            // Crop
            Button {
                model.isCropping.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crop")
                        .font(.system(size: 13, weight: .medium))
                    Text(L("video_editor.crop"))
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .foregroundStyle(model.isCropping ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(model.isCropping ? Color.accentColor : Color.white.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .help(L("video_editor.crop_help"))
            
            // Скорость
            Menu {
                Button(L("video_editor.speed_05")) { model.setRate(0.5) }
                Button(L("video_editor.speed_10")) { model.setRate(1.0) }
                Button(L("video_editor.speed_15")) { model.setRate(1.5) }
                Button(L("video_editor.speed_20")) { model.setRate(2.0) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.needle")
                        .font(.system(size: 12))
                    Text(String(format: "%.1fx", model.playbackRate))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            }
            .menuStyle(.borderlessButton)
            .frame(width: 80)
            
            Spacer()
            
            Button(action: onExportWebP) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles.tv")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L("video_editor.export_webp"))
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(red: 0.1, green: 0.65, blue: 0.6))
                )
            }
            .buttonStyle(.plain)
            .help(L("video_editor.export_webp_help"))
            
            Button(action: onExportGIF) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L("video_editor.export_gif"))
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.purple.opacity(0.85))
                )
            }
            .buttonStyle(.plain)
            .help(L("video_editor.export_gif_help"))
            
            Button(action: onExportMP4) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L("video_editor.save_mp4"))
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .frame(height: 32)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(.plain)
            .help(L("video_editor.save_mp4_help"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }
}
