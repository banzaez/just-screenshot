import SwiftUI

struct RecordingSettingsTab: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("settings.recording.params"))
                .font(.headline)

            Toggle(
                L("settings.recording.show_bar"),
                isOn: $settings.showFloatingBarDuringRecording)

            Text(L("settings.recording.show_bar_desc"))
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle(
                L("settings.recording.show_keystrokes"),
                isOn: $settings.showKeystrokesDuringRecording)

            Text(L("settings.recording.show_keystrokes_desc"))
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Text(L("settings.recording.format_header"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L("settings.recording.codec_label"))
                    Spacer()
                    Text("Apple H.264 (MP4)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text(L("settings.recording.cursor_label"))
                    Spacer()
                    Text(L("settings.recording.cursor_enabled"))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text(L("settings.recording.editor_label"))
                    Spacer()
                    Text(L("settings.recording.editor_open"))
                        .foregroundColor(.secondary)
                }
            }
            .font(.system(size: 13))
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
        }
    }
}
