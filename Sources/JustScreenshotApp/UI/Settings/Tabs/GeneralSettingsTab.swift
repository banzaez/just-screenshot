import SwiftUI
import AppKit

struct GeneralSettingsTab: View {
    @Bindable var settings = AppSettings.shared
    var launchAtLogin = LaunchAtLoginManager.shared
    var updater = UpdaterManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Секция: Выбор языка интерфейса
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    GlassSectionHeader(
                        title: L("settings.language.header"),
                        subtitle: L("settings.language.description"),
                        systemImage: "globe",
                        iconColor: .blue
                    )

                    HStack(spacing: 12) {
                        Picker("", selection: $settings.language) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text("\(lang.flagIcon)  \(lang.localizedName)")
                                    .tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 240)

                        Spacer()
                    }
                }
            }

            // Секция: Система и запуск
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    GlassSectionHeader(
                        title: L("settings.system.header"),
                        systemImage: "macwindow.badge.plus",
                        iconColor: .teal
                    )

                    HStack {
                        Text(L("settings.launch_at_login"))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)

                        Spacer()

                        Toggle(
                            "",
                            isOn: Binding(
                                get: { launchAtLogin.isEnabled },
                                set: { launchAtLogin.setLaunchAtLogin($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                }
            }

            // Секция: Скриншоты и захват
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    GlassSectionHeader(
                        title: L("settings.capture.header"),
                        systemImage: "camera.viewfinder",
                        iconColor: .indigo
                    )

                    HStack {
                        Text(L("settings.copy_clipboard"))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)

                        Spacer()

                        Toggle(
                            "",
                            isOn: $settings.copyToClipboardOnCapture
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    HStack {
                        Text(L("settings.play_sound"))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)

                        Spacer()

                        Toggle(
                            "",
                            isOn: $settings.playSound
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                }
            }

            // Секция: Папка для сохранения по умолчанию
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    GlassSectionHeader(
                        title: L("settings.save_dir.header"),
                        systemImage: "folder.fill",
                        iconColor: .orange
                    )

                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13))
                            Text(
                                settings.defaultSaveDirectoryPath.isEmpty
                                    ? L("settings.save_dir.not_selected")
                                    : settings.defaultSaveDirectoryPath
                            )
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        )

                        GlassButton(title: L("settings.choose"), icon: "folder.badge.gearshape") {
                            selectSaveDirectory()
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }

            // Секция: О программе и обновления Sparkle
            GlassCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.28), Color.purple.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 38, height: 38)
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(Color.purple.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: Color.purple.opacity(0.25), radius: 6, x: 0, y: 2)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.purple)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Just Screenshot")
                                .font(.system(size: 13.5, weight: .semibold))
                            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.0")")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                        }
                        
                        if let status = updater.lastStatus {
                            Text(status)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                        } else {
                            Text("Sparkle Autoupdate")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    GlassButton(
                        title: updater.isChecking ? "Проверка…" : L("menu.check_updates"),
                        icon: "arrow.triangle.2.circlepath",
                        isLoading: updater.isChecking
                    ) {
                        updater.checkForUpdates()
                    }
                    .disabled(!updater.canCheckForUpdates || updater.isChecking)
                    .fixedSize(horizontal: true, vertical: false)
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
