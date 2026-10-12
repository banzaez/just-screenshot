import SwiftUI

/// Представление окна Настроек приложения
public struct SettingsWindowView: View {
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
                        GeneralSettingsTab()
                    case .hotkeys:
                        HotkeysSettingsTab()
                    case .recording:
                        RecordingSettingsTab()
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 620)
        .frame(minHeight: 620)
    }
}
