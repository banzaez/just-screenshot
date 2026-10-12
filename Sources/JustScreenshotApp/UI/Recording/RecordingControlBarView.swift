import SwiftUI
import AppKit

/// Плавающая панель управления записью экрана (таймер, пауза/возобновление, стоп, отмена)
public struct RecordingControlBarView: View {
    @ObservedObject var windowManager: AppWindowManager
    var onPauseResume: () -> Void
    var onStop: () -> Void
    var onCancel: () -> Void
    
    @State private var isHovering = false
    
    public init(
        windowManager: AppWindowManager = .shared,
        onPauseResume: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.windowManager = windowManager
        self.onPauseResume = onPauseResume
        self.onStop = onStop
        self.onCancel = onCancel
    }
    
    private var formattedTime: String {
        let total = Int(windowManager.recordingDuration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Drag handle / Индикатор записи
            HStack(spacing: 8) {
                Circle()
                    .fill(windowManager.isRecordingPaused ? Color.orange : Color.red)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                Text(formattedTime)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                
                if windowManager.isRecordingPaused {
                    Text("ПАУЗА")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.leading, 4)
            
            Divider()
                .frame(height: 16)
                .background(Color.white.opacity(0.2))
            
            // Кнопка Пауза / Возобновить
            Button(action: onPauseResume) {
                Image(systemName: windowManager.isRecordingPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(windowManager.isRecordingPaused ? "Возобновить запись" : "Приостановить запись")
            
            // Кнопка Стоп (Завершить и сохранить)
            Button(action: onStop) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                    Text("Готово")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color.red.opacity(0.85))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Остановить запись и сохранить видео")
            
            // Кнопка Отмена (Удалить и отменить запись)
            Button(action: onCancel) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Отменить запись без сохранения")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 5)
        )
        .preferredColorScheme(.dark)
    }
}
