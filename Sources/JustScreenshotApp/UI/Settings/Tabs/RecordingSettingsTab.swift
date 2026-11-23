import SwiftUI

struct RecordingSettingsTab: View {
    @Bindable var settings = AppSettings.shared
    var permissions = PermissionsMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    GlassSectionHeader(
                        title: L("settings.recording.params"),
                        systemImage: "record.circle.fill",
                        iconColor: .red
                    )

                    GlassToggleRow(
                        title: L("settings.recording.show_bar"),
                        subtitle: L("settings.recording.show_bar_desc"),
                        isOn: $settings.showFloatingBarDuringRecording
                    )

                    if !permissions.accessibilityGranted {
                        GlassDivider()

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
                                permissions.requestAccessibility()
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
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    GlassSectionHeader(
                        title: L("settings.recording.format_header"),
                        systemImage: "film.stack.fill",
                        iconColor: .indigo
                    )

                    VStack(spacing: 10) {
                        formatRow(title: L("settings.recording.codec_label"), value: "Apple H.264 (MP4)")
                        GlassDivider()
                        formatRow(title: L("settings.recording.cursor_label"), value: L("settings.recording.cursor_enabled"))
                        GlassDivider()
                        formatRow(title: L("settings.recording.editor_label"), value: L("settings.recording.editor_open"))
                    }
                }
            }
        }
        .onAppear {
            permissions.refresh()
        }
    }

    private func formatRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
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
