import SwiftUI

struct HotkeysSettingsTab: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var recordingTarget: HotkeyTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("settings.hotkeys.title"))
                        .font(.headline)
                    Text(L("settings.hotkeys.subtitle"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    settings.resetHotkeysToDefaults()
                    AppWindowManager.shared.reloadGlobalHotkeys()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text(L("settings.hotkeys.reset_all"))
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
            }

            VStack(spacing: 10) {
                HotkeyDualCardView(
                    id: "area",
                    icon: "crop",
                    iconColor: .blue,
                    title: L("settings.hotkeys.area_title"),
                    subtitle: L("settings.hotkeys.area_sub"),
                    primaryShortcut: $settings.shortcutArea,
                    altShortcut: $settings.shortcutAreaAlt,
                    recordingTarget: $recordingTarget,
                    onShortcutChanged: {
                        AppWindowManager.shared.reloadGlobalHotkeys()
                    }
                )

                HotkeyDualCardView(
                    id: "window",
                    icon: "macwindow",
                    iconColor: .teal,
                    title: L("settings.hotkeys.window_title"),
                    subtitle: L("settings.hotkeys.window_sub"),
                    primaryShortcut: $settings.shortcutWindow,
                    altShortcut: $settings.shortcutWindowAlt,
                    recordingTarget: $recordingTarget,
                    onShortcutChanged: {
                        AppWindowManager.shared.reloadGlobalHotkeys()
                    }
                )

                HotkeyDualCardView(
                    id: "recording",
                    icon: "record.circle.fill",
                    iconColor: .red,
                    title: L("settings.hotkeys.record_title"),
                    subtitle: L("settings.hotkeys.record_sub"),
                    primaryShortcut: $settings.shortcutRecording,
                    altShortcut: $settings.shortcutRecordingAlt,
                    recordingTarget: $recordingTarget,
                    onShortcutChanged: {
                        AppWindowManager.shared.reloadGlobalHotkeys()
                    }
                )

                HotkeyDualCardView(
                    id: "repeat",
                    icon: "arrow.counterclockwise",
                    iconColor: .purple,
                    title: L("settings.hotkeys.repeat_title"),
                    subtitle: L("settings.hotkeys.repeat_sub"),
                    primaryShortcut: $settings.shortcutRepeat,
                    altShortcut: $settings.shortcutRepeatAlt,
                    recordingTarget: $recordingTarget,
                    onShortcutChanged: {
                        AppWindowManager.shared.reloadGlobalHotkeys()
                    }
                )

                HotkeyDualCardView(
                    id: "history",
                    icon: "clock.arrow.circlepath",
                    iconColor: .orange,
                    title: L("settings.hotkeys.history_title"),
                    subtitle: L("settings.hotkeys.history_sub"),
                    primaryShortcut: $settings.shortcutHistory,
                    altShortcut: $settings.shortcutHistoryAlt,
                    recordingTarget: $recordingTarget,
                    onShortcutChanged: {
                        AppWindowManager.shared.reloadGlobalHotkeys()
                    }
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(L("settings.hotkeys.protected_note"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
}
