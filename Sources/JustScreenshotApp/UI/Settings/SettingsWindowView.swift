import AppKit
import SwiftUI

/// Представление окна Настроек приложения
public struct SettingsWindowView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var launchAtLogin = LaunchAtLoginManager.shared

    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general
        case hotkeys
        case recording

        var id: String { rawValue }
        
        @MainActor
        var localizedTitle: String {
            switch self {
            case .general: return L("settings.tab.general")
            case .hotkeys: return L("settings.tab.hotkeys")
            case .recording: return L("settings.tab.recording")
            }
        }
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .hotkeys: return "command"
            case .recording: return "record.circle"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Вкладки переключения
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.localizedTitle, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:
                        generalSettingsView
                    case .hotkeys:
                        hotkeysSettingsView
                    case .recording:
                        recordingSettingsView
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 620)
        .frame(minHeight: 620)
    }

    // 1. Основные настройки
    private var generalSettingsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Секция выбора языка интерфейса
            VStack(alignment: .leading, spacing: 8) {
                Text(L("settings.language.header"))
                    .font(.headline)

                HStack(spacing: 12) {
                    Picker("", selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text("\(lang.flagIcon)  \(lang.localizedName)")
                                .tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 220)

                    Text(L("settings.language.description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)

            Divider()

            Text(L("settings.system.header"))
                .font(.headline)

            Toggle(
                L("settings.launch_at_login"),
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setLaunchAtLogin($0) }
                ))

            Divider()

            Text(L("settings.capture.header"))
                .font(.headline)

            Toggle(
                L("settings.copy_clipboard"),
                isOn: $settings.copyToClipboardOnCapture)

            Toggle(L("settings.play_sound"), isOn: $settings.playSound)

            Divider()

            Text(L("settings.save_dir.header"))
                .font(.headline)

            HStack {
                Text(
                    settings.defaultSaveDirectoryPath.isEmpty
                        ? L("settings.save_dir.not_selected") : settings.defaultSaveDirectoryPath
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)

                Button(L("settings.choose")) {
                    selectSaveDirectory()
                }
            }
        }
    }

    enum HotkeyTarget: Hashable {
        case primary(String)
        case alternate(String)
    }

    @State private var recordingTarget: HotkeyTarget?

    // 2. Горячие клавиши
    private var hotkeysSettingsView: some View {
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
                hotkeyDualCard(
                    id: "area",
                    icon: "crop",
                    iconColor: .blue,
                    title: L("settings.hotkeys.area_title"),
                    subtitle: L("settings.hotkeys.area_sub"),
                    primaryBinding: $settings.shortcutArea,
                    altBinding: $settings.shortcutAreaAlt
                )

                hotkeyDualCard(
                    id: "window",
                    icon: "macwindow",
                    iconColor: .teal,
                    title: L("settings.hotkeys.window_title"),
                    subtitle: L("settings.hotkeys.window_sub"),
                    primaryBinding: $settings.shortcutWindow,
                    altBinding: $settings.shortcutWindowAlt
                )

                hotkeyDualCard(
                    id: "recording",
                    icon: "record.circle.fill",
                    iconColor: .red,
                    title: L("settings.hotkeys.record_title"),
                    subtitle: L("settings.hotkeys.record_sub"),
                    primaryBinding: $settings.shortcutRecording,
                    altBinding: $settings.shortcutRecordingAlt
                )

                hotkeyDualCard(
                    id: "repeat",
                    icon: "arrow.counterclockwise",
                    iconColor: .purple,
                    title: L("settings.hotkeys.repeat_title"),
                    subtitle: L("settings.hotkeys.repeat_sub"),
                    primaryBinding: $settings.shortcutRepeat,
                    altBinding: $settings.shortcutRepeatAlt
                )

                hotkeyDualCard(
                    id: "history",
                    icon: "clock.arrow.circlepath",
                    iconColor: .orange,
                    title: L("settings.hotkeys.history_title"),
                    subtitle: L("settings.hotkeys.history_sub"),
                    primaryBinding: $settings.shortcutHistory,
                    altBinding: $settings.shortcutHistoryAlt
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

    private func hotkeyDualCard(
        id: String,
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        primaryBinding: Binding<ShortcutKey>,
        altBinding: Binding<ShortcutKey?>
    ) -> some View {
        HStack(spacing: 12) {
            // Иконка
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Название
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Сетка двух слотов фиксированной одинаковой ширины для ровных колонок
            HStack(spacing: 14) {
                // 1. Основной шорткат
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L("settings.hotkeys.primary"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    singleShortcutPill(
                        target: .primary(id),
                        shortcut: primaryBinding.wrappedValue,
                        onRecord: { newKey in
                            primaryBinding.wrappedValue = newKey
                            AppWindowManager.shared.reloadGlobalHotkeys()
                        },
                        onClear: nil
                    )
                }
                .frame(width: 128, alignment: .trailing)

                // 2. Альтернативный шорткат
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L("settings.hotkeys.secondary"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    if recordingTarget == .alternate(id) {
                        recordingPill(target: .alternate(id)) { newKey in
                            altBinding.wrappedValue = newKey
                            AppWindowManager.shared.reloadGlobalHotkeys()
                        }
                    } else if let alt = altBinding.wrappedValue {
                        singleShortcutPill(
                            target: .alternate(id),
                            shortcut: alt,
                            onRecord: { newKey in
                                altBinding.wrappedValue = newKey
                                AppWindowManager.shared.reloadGlobalHotkeys()
                            },
                            onClear: {
                                altBinding.wrappedValue = nil
                                AppWindowManager.shared.reloadGlobalHotkeys()
                            }
                        )
                    } else {
                        Button {
                            recordingTarget = .alternate(id)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                Text(L("settings.hotkeys.add_alt"))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        Color.secondary.opacity(0.35),
                                        style: StrokeStyle(lineWidth: 1, dash: [3]))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 128, alignment: .trailing)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func recordingPill(
        target: HotkeyTarget,
        onRecord: @escaping (ShortcutKey) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Text(L("settings.hotkeys.press_keys"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.blue)

            Button("✕") {
                recordingTarget = nil
            }
            .font(.system(size: 10, weight: .bold))
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.blue, lineWidth: 1.5)
        )
        .background(
            ShortcutRecorderView(
                shortcut: Binding(
                    get: { ShortcutKey(keyCode: 0, keyChar: "") },
                    set: { newKey in
                        onRecord(newKey)
                    }
                )
            ) {
                recordingTarget = nil
            }
            .frame(width: 1, height: 1)
            .opacity(0.01)
        )
    }

    private func singleShortcutPill(
        target: HotkeyTarget,
        shortcut: ShortcutKey,
        onRecord: @escaping (ShortcutKey) -> Void,
        onClear: (() -> Void)?
    ) -> some View {
        let isRecordingThis = recordingTarget == target

        return HStack(spacing: 4) {
            if isRecordingThis {
                HStack(spacing: 6) {
                    Text(L("settings.hotkeys.press_keys"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)

                    Button("✕") {
                        recordingTarget = nil
                    }
                    .font(.system(size: 10, weight: .bold))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue, lineWidth: 1.5)
                )
                .background(
                    ShortcutRecorderView(
                        shortcut: Binding(
                            get: { shortcut },
                            set: { newKey in
                                onRecord(newKey)
                            }
                        )
                    ) {
                        recordingTarget = nil
                    }
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                )
            } else {
                HStack(spacing: 2) {
                    Button {
                        recordingTarget = target
                    } label: {
                        HStack(spacing: 3) {
                            ForEach(shortcut.keySymbols, id: \.self) { sym in
                                Text(sym)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 20, minHeight: 20)
                                    .padding(.horizontal, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(NSColor.controlBackgroundColor))
                                            .shadow(
                                                color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(L("settings.hotkeys.click_to_change"))

                    if let onClear {
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help(L("settings.hotkeys.remove_alt"))
                    }
                }
            }
        }
    }

    // 3. Запись видео
    private var recordingSettingsView: some View {
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

    private func selectSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L("settings.select_button")

        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            settings.defaultSaveDirectoryPath = url.path
        }
    }
}
