import SwiftUI
import AppKit

/// Нативный размытый визуальный эффект macOS (Frosted Glass / Vibrancy)
public struct VisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State

    public init(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        if nsView.material != material { nsView.material = material }
        if nsView.blendingMode != blendingMode { nsView.blendingMode = blendingMode }
        if nsView.state != state { nsView.state = state }
    }
}

/// Единый фон окон в стиле Frosted / Liquid Glass
public struct GlassWindowBackground: View {
    public var showSpecularRim: Bool

    public init(showSpecularRim: Bool = true) {
        self.showSpecularRim = showSpecularRim
    }

    public var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow, state: .active)
                .ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.14), location: 0.0),
                    .init(color: Color.white.opacity(0.03), location: 0.16),
                    .init(color: Color.clear, location: 0.4)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if showSpecularRim {
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
            }
        }
    }
}

/// Тонкий разделитель для стеклянных карточек и тулбаров
public struct GlassDivider: View {
    public var isHeaderSeparator: Bool

    public init(isHeaderSeparator: Bool = false) {
        self.isHeaderSeparator = isHeaderSeparator
    }

    public var body: some View {
        if isHeaderSeparator {
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
        } else {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

/// Светящаяся стеклянная подложка под системную иконку
public struct GlassIconBadge: View {
    public let systemImage: String
    public var color: Color
    public var size: CGFloat
    public var cornerRadius: CGFloat
    public var iconSize: CGFloat

    public init(
        systemImage: String,
        color: Color = .blue,
        size: CGFloat = 34,
        cornerRadius: CGFloat = 11,
        iconSize: CGFloat = 15
    ) {
        self.systemImage = systemImage
        self.color = color
        self.size = size
        self.cornerRadius = cornerRadius
        self.iconSize = iconSize
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.28), color.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [color.opacity(0.65), color.opacity(0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: color.opacity(0.25), radius: 6, x: 0, y: 2)

            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

/// Стандартная строка переключателя внутри GlassCard
public struct GlassToggleRow: View {
    public let title: String
    public var subtitle: String?
    @Binding public var isOn: Bool

    public init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(title)
        }
    }
}

/// Контейнер карточки в каноничном стиле Liquid Glass (macOS Glass)
public struct GlassCard<Content: View>: View {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(
        cornerRadius: CGFloat = 15,
        padding: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.08), location: 0.0),
                                        .init(color: Color.white.opacity(0.02), location: 0.4),
                                        .init(color: Color.clear, location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.40), location: 0.0),
                                .init(color: Color.white.opacity(0.14), location: 0.3),
                                .init(color: Color.white.opacity(0.03), location: 0.8),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
    }
}

/// Заголовок секции настроек со светящейся стеклянной подложкой иконки
public struct GlassSectionHeader: View {
    public let title: String
    public var subtitle: String?
    public var systemImage: String?
    public var iconColor: Color

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        iconColor: Color = .blue
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.iconColor = iconColor
    }

    public var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                GlassIconBadge(systemImage: systemImage, color: iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Кнопка в каноничном стиле Frosted Glass
public struct GlassButton: View {
    public let title: String
    public var icon: String?
    public var role: ButtonRole?
    public var isLoading: Bool = false
    public let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    public init(
        title: String,
        icon: String? = nil,
        role: ButtonRole? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.role = role
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        let activeHover = isHovered && isEnabled
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(role == .destructive ? (activeHover ? .red : .red.opacity(0.9)) : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(activeHover ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(activeHover ? 0.45 : 0.28), location: 0.0),
                                .init(color: Color.white.opacity(activeHover ? 0.18 : 0.08), location: 0.5),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(activeHover ? 0.12 : 0.04), radius: 4, x: 0, y: 1)
            .opacity(isEnabled ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
