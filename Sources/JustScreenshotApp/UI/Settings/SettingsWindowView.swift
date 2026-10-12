import AppKit
import SwiftUI

/// Представление окна Настроек приложения
public struct SettingsWindowView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var launchAtLogin = LaunchAtLoginManager.shared

    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "Основные"
        case hotkeys = "Горячие клавиши"
        case recording = "Запись видео"

        var id: String { rawValue }
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
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
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
        .frame(width: 560)
        .frame(minHeight: 620)
    }

    // 1. Основные настройки
    private var generalSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Система и запуск")
                .font(.headline)

            Toggle(
                "Запускать Just Screenshot при входе в систему",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setLaunchAtLogin($0) }
                ))

            Divider()

            Text("Скриншоты")
                .font(.headline)

            Toggle(
                "Автоматически копировать снимок в буфер обмена",
                isOn: $settings.copyToClipboardOnCapture)

            Toggle("Воспроизводить звук затвора и записи", isOn: $settings.playSound)

            Divider()

            Text("Папка для сохранения по умолчанию")
                .font(.headline)

            HStack {
                Text(
                    settings.defaultSaveDirectoryPath.isEmpty
                        ? "Не выбрана" : settings.defaultSaveDirectoryPath
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)

                Button("Выбрать…") {
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
                    Text("Глобальные сочетания клавиш")
                        .font(.headline)
                    Text(
                        "Назначайте основные и альтернативные (вторые) сочетания или одиночные функциональные клавиши F1-F12."
                    )
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
                        Text("Сбросить все")
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
                    title: "Снимок произвольной области",
                    subtitle: "Выделение рамкой любого фрагмента экрана",
                    primaryBinding: $settings.shortcutArea,
                    altBinding: $settings.shortcutAreaAlt
                )

                hotkeyDualCard(
                    id: "window",
                    icon: "macwindow",
                    iconColor: .teal,
                    title: "Снимок окна приложения",
                    subtitle: "Интерактивный выбор открытого окна кликом",
                    primaryBinding: $settings.shortcutWindow,
                    altBinding: $settings.shortcutWindowAlt
                )

                hotkeyDualCard(
                    id: "recording",
                    icon: "record.circle.fill",
                    iconColor: .red,
                    title: "Запись экрана в видео",
                    subtitle: "Захват выбранной области в MP4 с плавающим пультом",
                    primaryBinding: $settings.shortcutRecording,
                    altBinding: $settings.shortcutRecordingAlt
                )

                hotkeyDualCard(
                    id: "repeat",
                    icon: "arrow.counterclockwise",
                    iconColor: .purple,
                    title: "Повторить предыдущий захват",
                    subtitle: "Мгновенный снимок той же самой области экрана",
                    primaryBinding: $settings.shortcutRepeat,
                    altBinding: $settings.shortcutRepeatAlt
                )

                hotkeyDualCard(
                    id: "history",
                    icon: "clock.arrow.circlepath",
                    iconColor: .orange,
                    title: "История снимков",
                    subtitle: "Галерея всех ранее сделанных скриншотов",
                    primaryBinding: $settings.shortcutHistory,
                    altBinding: $settings.shortcutHistoryAlt
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(
                    "Системные сочетания (⌘Q, ⌘W, ⌘H, ⌘Tab, ⌘Space) защищены от случайного переназначения."
                )
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

            // 1. Основной шорткат
            VStack(alignment: .trailing, spacing: 2) {
                Text("Основной")
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

            // 2. Альтернативный шорткат
            VStack(alignment: .trailing, spacing: 2) {
                Text("Второй")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                if let alt = altBinding.wrappedValue {
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
                        Text("+ Добавить")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        Color.secondary.opacity(0.3),
                                        style: StrokeStyle(lineWidth: 1, dash: [3]))
                            )
                    }
                    .buttonStyle(.plain)
                    .background(
                        Group {
                            if recordingTarget == .alternate(id) {
                                ShortcutRecorderView(
                                    shortcut: Binding(
                                        get: { ShortcutKey(keyCode: 0, keyChar: "") },
                                        set: { newKey in
                                            altBinding.wrappedValue = newKey
                                            AppWindowManager.shared.reloadGlobalHotkeys()
                                        }
                                    )
                                ) {
                                    recordingTarget = nil
                                }
                                .frame(width: 1, height: 1)
                                .opacity(0.01)
                            }
                        }
                    )
                }
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
                    Text("Нажмите клавиши…")
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
                    .help("Кликните для изменения сочетания клавиш")

                    if let onClear {
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Удалить этот альтернативный шорткат")
                    }
                }
            }
        }
    }

    // 3. Запись видео
    private var recordingSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Параметры видео")
                .font(.headline)

            Toggle(
                "Показывать плавающую панель со временем и кнопками паузы/стоп",
                isOn: $settings.showFloatingBarDuringRecording)

            Text(
                "Когда флажок включен, внизу записываемой области отображается стильный пульт управления."
            )
            .font(.caption)
            .foregroundColor(.secondary)

            Toggle(
                "Отображать нажатия клавиш и сочетания (Keystrokes HUD)",
                isOn: $settings.showKeystrokesDuringRecording)

            Text(
                "Показывает всплывающие бейджи с нажимаемыми шорткатами (⌘, ⌥, ⇧ и буквы) внутри рамки записи."
            )
            .font(.caption)
            .foregroundColor(.secondary)

            Divider()

            Text("Формат и кодек")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Кодек записи:")
                    Spacer()
                    Text("Apple H.264 (MP4)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Захват курсора мыши:")
                    Spacer()
                    Text("Включен")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Окно редактирования:")
                    Spacer()
                    Text("Открывать сразу после записи")
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
        panel.prompt = "Выбрать"

        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            settings.defaultSaveDirectoryPath = url.path
        }
    }
}
