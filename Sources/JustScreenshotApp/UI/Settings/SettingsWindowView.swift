import SwiftUI

/// Представление окна Настроек приложения в каноничном стиле Liquid Glass (macOS Glass)
public struct SettingsWindowView: View {
    @State private var selectedTab: SettingsTab = .general
    @State private var hoveredTab: SettingsTab? = nil
    @Namespace private var tabNamespace

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
            case .general: return "gearshape.fill"
            case .hotkeys: return "command"
            case .recording: return "record.circle.fill"
            }
        }
    }

    public init() {}

    public var body: some View {
        ZStack {
            // Нативное размытие рабочего стола (Frosted Glass / Vibrancy)
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow, state: .active)
                .ignoresSafeArea()

            // Верхний световой блик стеклянной поверхности
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.18), location: 0.0),
                    .init(color: Color.white.opacity(0.04), location: 0.12),
                    .init(color: Color.clear, location: 0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Тонкая внутренняя световая фаска стекла по периметру окна
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.28), location: 0.0),
                            .init(color: Color.white.opacity(0.08), location: 0.35),
                            .init(color: Color.white.opacity(0.02), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Интегрированный стеклянный хедер с плавающим селектором
                headerBar

                // Разделитель с деликатным бликом
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.02), location: 0.0),
                                .init(color: Color.white.opacity(0.18), location: 0.5),
                                .init(color: Color.white.opacity(0.02), location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                // Скроллируемая область контента настроек
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(minWidth: 620, idealWidth: 660, maxWidth: .infinity, minHeight: 620, maxHeight: .infinity)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 0) {
            // Отступ слева под кнопки окна macOS ("светофор")
            Spacer()
                .frame(width: 76)

            Spacer()

            // Плавающий селектор вкладок Liquid Glass
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    let isHovered = hoveredTab == tab && !isSelected

                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(tab.localizedTitle)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        }
                        .foregroundColor(isSelected ? .primary : (isHovered ? .primary.opacity(0.9) : .secondary))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.accentColor.opacity(0.28),
                                                Color.accentColor.opacity(0.14)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.accentColor.opacity(0.70),
                                                        Color.accentColor.opacity(0.25)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .matchedGeometryEffect(id: "activeTabIndicator", in: tabNamespace)
                                    .shadow(color: Color.accentColor.opacity(0.25), radius: 8, x: 0, y: 2)
                            } else if isHovered {
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        hoveredTab = isHovering ? tab : nil
                    }
                }
            }
            .padding(4)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.40), location: 0.0),
                                .init(color: Color.white.opacity(0.14), location: 0.45),
                                .init(color: Color.white.opacity(0.04), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)

            Spacer()

            // Балансировочный отступ справа
            Spacer()
                .frame(width: 76)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(height: 58)
    }
}
