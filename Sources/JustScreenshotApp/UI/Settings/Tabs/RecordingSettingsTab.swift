import SwiftUI

struct RecordingSettingsTab: View {
    @Bindable var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Карточка: Параметры живого оверлея при записи
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    GlassSectionHeader(
                        title: L("settings.recording.params"),
                        systemImage: "record.circle.fill",
                        iconColor: .red
                    )

                    // 1. Пульт управления
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L("settings.recording.show_bar"))
                                .font(.system(size: 13))
                                .foregroundColor(.primary)

                            Text(L("settings.recording.show_bar_desc"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle(
                            "",
                            isOn: $settings.showFloatingBarDuringRecording
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    // 2. Отображение нажатий клавиш (HUD)
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L("settings.recording.show_keystrokes"))
                                .font(.system(size: 13))
                                .foregroundColor(.primary)

                            Text(L("settings.recording.show_keystrokes_desc"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle(
                            "",
                            isOn: $settings.showKeystrokesDuringRecording
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: settings.showKeystrokesDuringRecording) { _, newValue in
                            if newValue && !AccessibilityPermissionHelper.isGranted {
                                AccessibilityPermissionHelper.requestAccess()
                            }
                        }
                    }

                    if settings.showKeystrokesDuringRecording && !AccessibilityPermissionHelper.isGranted {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))

                            Text(L("settings.recording.accessibility_needed"))
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer()

                            GlassButton(
                                title: L("settings.recording.accessibility_button"),
                                icon: "lock.shield"
                            ) {
                                AccessibilityPermissionHelper.requestAccess()
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.orange.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    // 3. Подсветка кликов мыши
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L("settings.recording.show_clicks"))
                                .font(.system(size: 13))
                                .foregroundColor(.primary)

                            Text(L("settings.recording.show_clicks_desc"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle(
                            "",
                            isOn: $settings.showClicksDuringRecording
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                }
            }

            // Карточка: Формат и кодек
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    GlassSectionHeader(
                        title: L("settings.recording.format_header"),
                        systemImage: "film.stack.fill",
                        iconColor: .indigo
                    )

                    VStack(spacing: 10) {
                        HStack {
                            Text(L("settings.recording.codec_label"))
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Apple H.264 (MP4)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)

                        HStack {
                            Text(L("settings.recording.cursor_label"))
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(L("settings.recording.cursor_enabled"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)

                        HStack {
                            Text(L("settings.recording.editor_label"))
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(L("settings.recording.editor_open"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                        }
                    }
                }
            }
        }
    }
}
