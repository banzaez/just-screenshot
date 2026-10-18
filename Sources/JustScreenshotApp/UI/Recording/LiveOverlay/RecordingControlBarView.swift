import SwiftUI
import AppKit

/// Плавающая панель управления записью экрана (таймер, пауза/возобновление, стоп, отмена)
public struct RecordingControlBarView: View {
    @ObservedObject var windowManager: AppWindowManager
    var onPauseResume: () -> Void
    var onStop: () -> Void
    var onCancel: () -> Void
    
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
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(windowManager.isRecordingPaused ? Color.orange : Color.red)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
                
                Text(formattedTime)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .accessibilityLabel(L("recording.bar.timer_a11y", formattedTime))
                
                if windowManager.isRecordingPaused {
                    Text(L("recording.bar.pause_badge"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.leading, 4)
            .accessibilityElement(children: .combine)
            
            Divider()
                .frame(height: 16)
                .background(Color.white.opacity(0.2))
                .accessibilityHidden(true)
            
            Button(action: onPauseResume) {
                Image(systemName: windowManager.isRecordingPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(windowManager.isRecordingPaused ? L("recording.bar.resume_help") : L("recording.bar.pause_help"))
            .accessibilityLabel(windowManager.isRecordingPaused ? L("recording.bar.resume_help") : L("recording.bar.pause_help"))
            
            Button(action: onStop) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                    Text(L("recording.bar.done"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color.red.opacity(0.85))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(L("recording.bar.done_help"))
            .accessibilityLabel(L("recording.bar.done_help"))
            
            Button(action: onCancel) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(L("recording.bar.cancel_help"))
            .accessibilityLabel(L("recording.bar.cancel_help"))
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
