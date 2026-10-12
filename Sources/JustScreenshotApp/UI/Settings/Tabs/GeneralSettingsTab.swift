import SwiftUI
import AppKit

struct GeneralSettingsTab: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var launchAtLogin = LaunchAtLoginManager.shared

    var body: some View {
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
