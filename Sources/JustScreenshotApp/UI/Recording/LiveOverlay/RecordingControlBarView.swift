import SwiftUI
import AppKit

/// Плавающая панель управления записью экрана.
/// В режиме подготовки (.isRecordingPreparing) отображает настройки (разрешение/пресеты, нажатия клавиш, клики, затемнение экрана, таймер) и кнопку «Запись».
/// В режиме активной записи (.isRecording) отображает таймер, паузу/возобновление, стоп (Done) и отмену (Trash).
public struct RecordingControlBarView: View {
    @ObservedObject var windowManager: AppWindowManager
    @ObservedObject var settings: AppSettings = .shared
    
    var onStartRecording: () -> Void
    var onSelectPreset: (CGRect) -> Void
    var onRequestNewArea: () -> Void
    var onToggleDimming: () -> Void
    var onPauseResume: () -> Void
    var onStop: () -> Void
    var onCancel: () -> Void
    
    public init(
        windowManager: AppWindowManager = .shared,
        onStartRecording: @escaping () -> Void = {},
        onSelectPreset: @escaping (CGRect) -> Void = { _ in },
        onRequestNewArea: @escaping () -> Void = {},
        onToggleDimming: @escaping () -> Void = {},
        onPauseResume: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.windowManager = windowManager
        self.onStartRecording = onStartRecording
        self.onSelectPreset = onSelectPreset
        self.onRequestNewArea = onRequestNewArea
        self.onToggleDimming = onToggleDimming
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
        Group {
            if windowManager.isRecording {
                activeRecordingBar
            } else {
                setupControlBar
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 7)
        )
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Панель настройки перед записью (Setup Mode)
    
    private var setupControlBar: some View {
        HStack(spacing: 14) {
            // Выбор разрешения / пресетов
            Menu {
                Button("1920 × 1080 (1080p)") {
                    onSelectPreset(presetRect(width: 1920, height: 1080))
                }
                Button("1280 × 720 (720p)") {
                    onSelectPreset(presetRect(width: 1280, height: 720))
                }
                Button("854 × 480 (480p)") {
                    onSelectPreset(presetRect(width: 854, height: 480))
                }
                Divider()
                Button(L("recording.bar.fullscreen")) {
                    onSelectPreset(fullScreenRect())
                }
                Divider()
                Button(L("recording.bar.select_new_area")) {
                    onRequestNewArea()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "aspectratio")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(Int(windowManager.recordingRect.width)) × \(Int(windowManager.recordingRect.height))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                        .fixedSize()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.white.opacity(0.12))
                .cornerRadius(7)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(L("recording.bar.presets"))
            
            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.2))
            
            // Настройки записи (переключатели)
            HStack(spacing: 9) {
                // Нажатия клавиш
                Button(action: {
                    settings.showKeystrokesDuringRecording.toggle()
                    if settings.showKeystrokesDuringRecording && !AccessibilityPermissionHelper.isGranted {
                        AccessibilityPermissionHelper.requestAccess()
                    }
                }) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(settings.showKeystrokesDuringRecording ? .white : .white.opacity(0.45))
                        .frame(width: 32, height: 32)
                        .background(settings.showKeystrokesDuringRecording ? Color.blue.opacity(0.85) : Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help(L("recording.bar.keystrokes_help"))
                .accessibilityLabel(L("recording.bar.keystrokes_help"))
                
                // Клики мыши
                Button(action: {
                    settings.showClicksDuringRecording.toggle()
                }) {
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(settings.showClicksDuringRecording ? .white : .white.opacity(0.45))
                        .frame(width: 32, height: 32)
                        .background(settings.showClicksDuringRecording ? Color.blue.opacity(0.85) : Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help(L("recording.bar.clicks_help"))
                .accessibilityLabel(L("recording.bar.clicks_help"))
                
                // Затемнение экрана вокруг области записи
                Button(action: {
                    settings.dimOutsideRecordingArea.toggle()
                    onToggleDimming()
                }) {
                    Image(systemName: settings.dimOutsideRecordingArea ? "circle.lefthalf.filled" : "circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(settings.dimOutsideRecordingArea ? .white : .white.opacity(0.45))
                        .frame(width: 32, height: 32)
                        .background(settings.dimOutsideRecordingArea ? Color.blue.opacity(0.85) : Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help(L("recording.bar.dim_help"))
                .accessibilityLabel(L("recording.bar.dim_help"))
                
                // Таймер обратного отсчета (0с или 3с)
                Button(action: {
                    settings.recordingCountdownSeconds = settings.recordingCountdownSeconds > 0 ? 0 : 3
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .semibold))
                        if settings.recordingCountdownSeconds > 0 {
                            Text("\(settings.recordingCountdownSeconds)s")
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .foregroundColor(settings.recordingCountdownSeconds > 0 ? .white : .white.opacity(0.45))
                    .padding(.horizontal, settings.recordingCountdownSeconds > 0 ? 8 : 7)
                    .frame(height: 32)
                    .background(settings.recordingCountdownSeconds > 0 ? Color.blue.opacity(0.85) : Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help(L("recording.bar.countdown_help"))
                .accessibilityLabel(L("recording.bar.countdown_help"))
            }
            .fixedSize()
            
            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.2))
            
            // Кнопка запуска записи
            Button(action: onStartRecording) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                    Text(L("recording.bar.start_record"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize()
                    Image(systemName: "return")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(Color.red.opacity(0.9))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(L("recording.bar.start_help"))
            .accessibilityLabel(L("recording.bar.start_help"))
            
            // Кнопка закрытия / отмены
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(L("alert.cancel"))
            .accessibilityLabel(L("alert.cancel"))
        }
    }
    
    // MARK: - Панель во время записи (Active Recording Mode)
    
    private var activeRecordingBar: some View {
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
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityLabel(L("recording.bar.timer_a11y", formattedTime))
                
                if windowManager.isRecordingPaused {
                    Text(L("recording.bar.pause_badge"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.leading, 4)
            .accessibilityElement(children: .combine)
            .fixedSize()
            
            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.2))
                .accessibilityHidden(true)
            
            Button(action: onPauseResume) {
                Image(systemName: windowManager.isRecordingPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(windowManager.isRecordingPaused ? L("recording.bar.resume_help") : L("recording.bar.pause_help"))
            .accessibilityLabel(windowManager.isRecordingPaused ? L("recording.bar.resume_help") : L("recording.bar.pause_help"))
            
            Button(action: onStop) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 9, height: 9)
                    Text(L("recording.bar.done"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize()
                }
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Color.red.opacity(0.85))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(L("recording.bar.done_help"))
            .accessibilityLabel(L("recording.bar.done_help"))
            
            Button(action: onCancel) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(L("recording.bar.cancel_help"))
            .accessibilityLabel(L("recording.bar.cancel_help"))
        }
    }
    
    // MARK: - Helpers для расчета прямоугольников пресетов
    
    private func presetRect(width: CGFloat, height: CGFloat) -> CGRect {
        let center = CGPoint(x: windowManager.recordingRect.midX, y: windowManager.recordingRect.midY)
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(center, $0.frame, false) })
            ?? NSScreen.screens.first(where: { $0.frame.intersects(windowManager.recordingRect) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        
        let screenFrame = targetScreen.frame
        let w = min(width, screenFrame.width)
        let h = min(height, screenFrame.height)
        var x = center.x - w / 2
        var y = center.y - h / 2
        
        x = max(screenFrame.minX, min(screenFrame.maxX - w, x))
        y = max(screenFrame.minY, min(screenFrame.maxY - h, y))
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    private func fullScreenRect() -> CGRect {
        let center = CGPoint(x: windowManager.recordingRect.midX, y: windowManager.recordingRect.midY)
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(center, $0.frame, false) })
            ?? NSScreen.screens.first(where: { $0.frame.intersects(windowManager.recordingRect) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        return targetScreen.frame
    }
}
