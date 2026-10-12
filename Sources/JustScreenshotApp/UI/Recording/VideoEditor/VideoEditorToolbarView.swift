import SwiftUI
import AppKit

/// Верхняя панель инструментов профессионального видеоредактора
public struct VideoEditorToolbarView: View {
    @ObservedObject var model: VideoEditorModel
    var onExportMP4: () -> Void
    var onExportGIF: () -> Void
    
    public init(
        model: VideoEditorModel,
        onExportMP4: @escaping () -> Void,
        onExportGIF: @escaping () -> Void
    ) {
        self.model = model
        self.onExportMP4 = onExportMP4
        self.onExportGIF = onExportGIF
    }
    
    public var body: some View {
        HStack(spacing: 14) {
            // Кнопки добавления аннотаций
            HStack(spacing: 4) {
                ForEach(VideoAnnotationType.allCases) { type in
                    Button {
                        model.addAnnotation(type: type)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: type.icon)
                                .font(.system(size: 13, weight: .medium))
                            Text(type.rawValue)
                                .font(.system(size: 9))
                        }
                        .frame(width: 52, height: 38)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Добавить \(type.rawValue)")
                }
            }
            
            Divider()
                .frame(height: 24)
            
            // Кадрирование (Crop)
            Button {
                model.isCropping.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crop")
                        .font(.system(size: 13, weight: .medium))
                    Text("Кадрировать")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(model.isCropping ? Color.blue : Color.white.opacity(0.08))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Включить или отключить область кадрирования видео")
            
            // Скорость воспроизведения
            Menu {
                Button("0.5x Замедленно") { model.setRate(0.5) }
                Button("1.0x Обычная") { model.setRate(1.0) }
                Button("1.5x Ускорено") { model.setRate(1.5) }
                Button("2.0x В 2 раза быстрее") { model.setRate(2.0) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.needle")
                        .font(.system(size: 12))
                    Text(String(format: "%.1fx", model.playbackRate))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 76)
            
            Spacer()
            
            // Кнопка экспорта в GIF
            Button(action: onExportGIF) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 12))
                    Text("GIF")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.purple.opacity(0.85))
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Экспортировать выбранный фрагмент как анимированный GIF")
            
            // Кнопка экспорта в MP4
            Button(action: onExportMP4) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("Сохранить MP4")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Экспортировать готовое видео в MP4")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Divider(), alignment: .bottom
        )
    }
}
