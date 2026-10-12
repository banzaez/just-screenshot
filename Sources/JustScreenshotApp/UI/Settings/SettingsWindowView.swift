import SwiftUI
import AppKit

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
        .frame(width: 540)
        .frame(minHeight: 520, maxHeight: 720)
    }
    
    // 1. Основные настройки
    private var generalSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Система и запуск")
                .font(.headline)
            
            Toggle("Запускать Just Screenshot при входе в систему", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setLaunchAtLogin($0) }
            ))
            
            Divider()
            
            Text("Скриншоты")
                .font(.headline)
            
            Toggle("Автоматически копировать снимок в буфер обмена", isOn: $settings.copyToClipboardOnCapture)
            
            Toggle("Воспроизводить звук затвора и записи", isOn: $settings.playSound)
            
            Divider()
            
            Text("Папка для сохранения по умолчанию")
                .font(.headline)
            
            HStack {
                Text(settings.defaultSaveDirectoryPath.isEmpty ? "Не выбрана" : settings.defaultSaveDirectoryPath)
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
    
    enum HotkeyTarget: String, Identifiable {
        case area, window, recording, history
        var id: String { rawValue }
    }
    
    @State private var recordingTarget: HotkeyTarget?
    
    // 2. Горячие клавиши
    private var hotkeysSettingsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Глобальные сочетания клавиш")
                        .font(.headline)
                    Text("Нажмите на сочетание клавиш для изменения или назначьте новые")
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
                        Text("Сброс")
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
            
            VStack(spacing: 8) {
                hotkeyCard(
                    target: .area,
                    icon: "crop",
                    iconColor: .blue,
                    title: "Снимок произвольной области",
                    subtitle: "Выделение рамкой любого фрагмента экрана",
                    shortcutBinding: $settings.shortcutArea
                )
                
                hotkeyCard(
                    target: .window,
                    icon: "macwindow",
                    iconColor: .teal,
                    title: "Снимок окна приложения",
                    subtitle: "Интерактивный выбор открытого окна кликом",
                    shortcutBinding: $settings.shortcutWindow
                )
                
                hotkeyCard(
                    target: .recording,
                    icon: "record.circle.fill",
                    iconColor: .red,
                    title: "Запись экрана в видео",
                    subtitle: "Захват выбранной области в MP4 с плавающим пультом",
                    shortcutBinding: $settings.shortcutRecording
                )
                
                hotkeyCard(
                    target: .history,
                    icon: "clock.arrow.circlepath",
                    iconColor: .orange,
                    title: "История снимков",
                    subtitle: "Галерея всех ранее сделанных скриншотов",
                    shortcutBinding: $settings.shortcutHistory
                )
            }
            
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("Кликните по клавишам, чтобы задать новое сочетание (ESC для отмены).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
    
    private func hotkeyCard(
        target: HotkeyTarget,
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        shortcutBinding: Binding<ShortcutKey>
    ) -> some View {
        let isRecordingThis = recordingTarget == target
        
        return HStack(spacing: 12) {
            // Иконка действия
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Заголовок и пояснение
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Режим записи или отображение кейкапов
            if isRecordingThis {
                HStack(spacing: 8) {
                    Text("Нажмите клавиши…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Button("Отмена") {
                        recordingTarget = nil
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue, lineWidth: 1.5)
                )
                .background(
                    ShortcutRecorderView(shortcut: Binding(
                        get: { shortcutBinding.wrappedValue },
                        set: { newKey in
                            shortcutBinding.wrappedValue = newKey
                            AppWindowManager.shared.reloadGlobalHotkeys()
                        }
                    )) {
                        recordingTarget = nil
                    }
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                )
            } else {
                Button {
                    recordingTarget = target
                } label: {
                    HStack(spacing: 4) {
                        ForEach(shortcutBinding.wrappedValue.keySymbols, id: \.self) { sym in
                            Text(sym)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .frame(minWidth: 26, minHeight: 24)
                                .padding(.horizontal, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Нажмите, чтобы изменить сочетание клавиш")
            }
        }
        .padding(10)
        .background(isRecordingThis ? Color.blue.opacity(0.08) : Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isRecordingThis ? Color.blue.opacity(0.5) : Color.white.opacity(0.07), lineWidth: 1)
        )
    }
    
    // 3. Запись видео
    private var recordingSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Параметры видео")
                .font(.headline)
            
            Toggle("Показывать плавающую панель со временем и кнопками паузы/стоп", isOn: $settings.showFloatingBarDuringRecording)
            
            Text("Когда флажок включен, внизу записываемой области отображается стильный пульт управления.")
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
