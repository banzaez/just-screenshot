import SwiftUI

struct HotkeysSettingsTab: View {
    @Bindable var settings = AppSettings.shared
    @State private var recordingTarget: HotkeyTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Информационный стеклянный баннер с кнопкой сброса
            GlassCard(padding: 14) {
                HStack(alignment: .center) {
                    GlassSectionHeader(
                        title: L("settings.hotkeys.title"),
                        subtitle: L("settings.hotkeys.subtitle"),
                        systemImage: "keyboard",
                        iconColor: .cyan
                    )

                    Spacer()

                    GlassButton(
                        title: L("settings.hotkeys.reset_all"),
                        icon: "arrow.counterclockwise"
                    ) {
                        settings.resetHotkeysToDefaults()
                        AppWindowManager.shared.reloadGlobalHotkeys()
                    }
                }
            }

            // Список карточек шорткатов
            VStack(spacing: 8) {
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
                    id: "ocr",
                    icon: "text.viewfinder",
                    iconColor: .indigo,
                    title: L("settings.hotkeys.ocr_title"),
                    subtitle: L("settings.hotkeys.ocr_sub"),
                    primaryShortcut: $settings.shortcutOCR,
                    altShortcut: $settings.shortcutOCRAlt,
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

            // Заметка о системных сочетаниях клавиш
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                Text(L("settings.hotkeys.protected_note"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
        }
    }
}
