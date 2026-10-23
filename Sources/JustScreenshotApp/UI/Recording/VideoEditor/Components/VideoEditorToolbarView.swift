import SwiftUI
import AppKit

/// Верхняя панель инструментов видеоредактора: аннотации, стили, обрезка, скорость, экспорт
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
        ViewThatFits(in: .horizontal) {
            toolbarContent
            
            ScrollView(.horizontal, showsIndicators: false) {
                toolbarContent
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }
    
    private var toolbarContent: some View {
        HStack(spacing: 12) {
            // Обрезка кадра (Crop)
            Button {
                model.isCropping.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crop")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L("video_editor.crop"))
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .foregroundStyle(model.isCropping ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(model.isCropping ? Color.accentColor : Color.white.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(L("video_editor.crop_help"))
            
            // Размытие конфиденциальных данных (Blur / Redact)
            Button {
                model.addAnnotation(type: .blur)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L("video_editor.type_blur"))
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .foregroundStyle(model.hasBlurAnnotations ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(model.hasBlurAnnotations ? Color.indigo.opacity(0.85) : Color.white.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(L("video_editor.blur_help"))
            
            // Умный зум на курсор (Smart Zoom / Camera Follow) с настройками
            HStack(spacing: 0) {
                // Основная кнопка переключения Вкл / Выкл
                Button {
                    model.isSmartZoomEnabled.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.metering.matrix")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Smart Zoom")
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                        if model.isSmartZoomEnabled {
                            Text(model.smartZoomScale.title)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.25))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.leading, 9)
                    .padding(.trailing, 4)
                    .frame(height: 30)
                    .foregroundStyle(model.isSmartZoomEnabled ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .fixedSize()
                
                // Выпадающее меню настроек умного зума
                Menu {
                    Toggle(L("video_editor.smart_zoom_enable"), isOn: $model.isSmartZoomEnabled)
                    
                    Divider()
                    
                    Section(L("video_editor.smart_zoom_scale_header")) {
                        ForEach(SmartZoomScale.allCases) { scale in
                            Button {
                                model.smartZoomScale = scale
                            } label: {
                                HStack {
                                    Text(scaleTitle(scale))
                                    if model.smartZoomScale == scale {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Section(L("video_editor.smart_zoom_mode_header")) {
                        ForEach(SmartZoomMode.allCases) { mode in
                            Button {
                                model.smartZoomMode = mode
                            } label: {
                                HStack {
                                    Text(modeTitle(mode))
                                    if model.smartZoomMode == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Toggle(L("video_editor.smart_zoom_idle_zoomout"), isOn: $model.autoZoomOutOnIdle)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(model.isSmartZoomEnabled ? Color.white.opacity(0.85) : Color.secondary)
                        .padding(.horizontal, 6)
                        .frame(height: 30)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(model.isSmartZoomEnabled ? Color.blue : Color.white.opacity(0.08))
            )
            .fixedSize()
            .help(L("video_editor.smart_zoom_help"))
            
            // Скорость воспроизведения
            Menu {
                Button(L("video_editor.speed_05")) { model.setRate(0.5) }
                Button(L("video_editor.speed_10")) { model.setRate(1.0) }
                Button(L("video_editor.speed_15")) { model.setRate(1.5) }
                Button(L("video_editor.speed_20")) { model.setRate(2.0) }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "gauge.with.needle")
                        .font(.system(size: 11, weight: .medium))
                    Text(String(format: "%.1fx", model.playbackRate))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                        .fixedSize()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Spacer(minLength: 16)
            
            // Группа экспорта (WebP, GIF, MP4)
            HStack(spacing: 8) {
                Button(action: onExportWebP) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles.tv")
                            .font(.system(size: 11, weight: .semibold))
                        Text("WebP")
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(red: 0.1, green: 0.65, blue: 0.6))
                    )
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help(L("video_editor.export_webp_help"))
                
                Button(action: onExportGIF) {
                    HStack(spacing: 5) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 11, weight: .semibold))
                        Text("GIF")
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.purple.opacity(0.85))
                    )
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help(L("video_editor.export_gif_help"))
                
                Button(action: onExportMP4) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(L("video_editor.save_mp4"))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help(L("video_editor.save_mp4_help"))
            }
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func scaleTitle(_ scale: SmartZoomScale) -> String {
        switch scale {
        case .subtle: return L("video_editor.smart_zoom_scale_subtle")
        case .balanced: return L("video_editor.smart_zoom_scale_balanced")
        case .closeup: return L("video_editor.smart_zoom_scale_closeup")
        }
    }
    
    private func modeTitle(_ mode: SmartZoomMode) -> String {
        switch mode {
        case .onClicks: return L("video_editor.smart_zoom_mode_clicks")
        case .continuous: return L("video_editor.smart_zoom_mode_continuous")
        }
    }
}
