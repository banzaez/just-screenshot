import SwiftUI
import AppKit

struct GeneralSettingsTab: View {
    @Bindable var settings = AppSettings.shared
    var launchAtLogin = LaunchAtLoginManager.shared
    var updater = UpdaterManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PermissionsStatusCard()

            // Язык интерфейса
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    GlassSectionHeader(
                        title: L("settings.language.header"),
                        subtitle: L("settings.language.description"),
                        systemImage: "globe",
                        iconColor: .blue
                    )

                    HStack(spacing: 12) {
                        Picker(L("settings.language.header"), selection: $settings.language) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text("\(lang.flagIcon)  \(lang.localizedName)")
                                    .tag(lang)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 240)
                        .accessibilityLabel(L("settings.language.header"))

                        Spacer()
                    }
                }
            }

            // Система и запуск
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    GlassSectionHeader(
                        title: L("settings.system.header"),
                        systemImage: "macwindow.badge.plus",
                        iconColor: .teal
                    )

                    GlassToggleRow(
                        title: L("settings.launch_at_login"),
                        isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { launchAtLogin.setLaunchAtLogin($0) }
                        )
                    )
                }
            }

            // Скриншоты и захват
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    GlassSectionHeader(
                        title: L("settings.capture.header"),
                        systemImage: "camera.viewfinder",
                        iconColor: .indigo
                    )

                    GlassToggleRow(
                        title: L("settings.copy_clipboard"),
                        isOn: $settings.copyToClipboardOnCapture
                    )

                    GlassDivider()

                    GlassToggleRow(
                        title: L("settings.play_sound"),
                        isOn: $settings.playSound
                    )
                }
            }

            // Папка для сохранения по умолчанию
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

            // О программе и обновления Sparkle
            GlassCard {
                HStack(spacing: 14) {
                    GlassIconBadge(
                        systemImage: "sparkles",
                        color: .purple,
                        size: 38,
                        cornerRadius: 11,
                        iconSize: 17
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Just Screenshot")
                                .font(.system(size: 13.5, weight: .semibold))
                            if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                                Text("v\(appVersion)")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                            }
                        }

                        if let status = updater.lastStatus {
                            Text(status)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(updater.isLastStatusError ? .red : .green)
                        } else {
                            Text(L("updater.subtitle"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    GlassButton(
                        title: updater.isChecking ? L("updater.checking") : L("menu.check_updates"),
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
        .onAppear {
            launchAtLogin.refreshStatus()
        }
    }

    private func selectSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = L("settings.select_button")
        if !settings.defaultSaveDirectoryPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: settings.defaultSaveDirectoryPath, isDirectory: true)
        } else {
            panel.directoryURL = ImageExporter.defaultSaveDirectoryURL()
        }

        NSApp.activate()
        if panel.runModal() == .OK, let url = panel.url {
            settings.defaultSaveDirectoryPath = url.path
        }
    }
}
