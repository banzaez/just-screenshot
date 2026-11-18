import SwiftUI

/// Наглядная карточка статусов системных разрешений macOS в стиле Liquid Glass
struct PermissionsStatusCard: View {
    var permissions = PermissionsMonitor.shared

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    GlassSectionHeader(
                        title: L("permissions.header"),
                        subtitle: L("permissions.subtitle"),
                        systemImage: headerIcon,
                        iconColor: headerColor
                    )

                    summaryBadge
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                permissionRow(
                    icon: "display",
                    iconColor: permissions.screenRecordingGranted ? .green : .orange,
                    title: L("permissions.screen_recording.title"),
                    description: L("permissions.screen_recording.desc"),
                    isGranted: permissions.screenRecordingGranted,
                    isRequired: true,
                    actionTitle: L("permissions.grant"),
                    actionIcon: "lock.open",
                    onGrant: { permissions.requestScreenRecording() }
                )

                if !permissions.screenRecordingGranted {
                    relaunchBanner
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                permissionRow(
                    icon: "keyboard",
                    iconColor: permissions.accessibilityGranted ? .green : .secondary,
                    title: L("permissions.accessibility.title"),
                    description: L("permissions.accessibility.desc"),
                    isGranted: permissions.accessibilityGranted,
                    isRequired: false,
                    actionTitle: L("permissions.grant"),
                    actionIcon: "hand.raised",
                    onGrant: { permissions.requestAccessibility() }
                )
            }
        }
        .onAppear {
            permissions.refresh()
        }
        .task(id: permissions.allGranted) {
            guard !permissions.allGranted else { return }
            while !Task.isCancelled && !permissions.allGranted {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                permissions.refresh()
            }
        }
    }

    // MARK: - Subviews

    private var headerIcon: String {
        if permissions.allGranted {
            return "checkmark.shield.fill"
        }
        return permissions.screenRecordingGranted ? "shield.lefthalf.filled" : "exclamationmark.shield.fill"
    }

    private var headerColor: Color {
        if permissions.allGranted {
            return .green
        }
        return permissions.screenRecordingGranted ? .blue : .orange
    }

    private var summaryBadge: some View {
        let allGranted = permissions.allGranted
        let text = allGranted
            ? L("permissions.summary_all_granted")
            : L("permissions.summary_partial", permissions.grantedCount)
        let color: Color = allGranted ? .green : (permissions.screenRecordingGranted ? .blue : .orange)

        return HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.14))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
        .fixedSize()
    }

    private func permissionRow(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        isGranted: Bool,
        isRequired: Bool,
        actionTitle: String,
        actionIcon: String,
        onGrant: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isGranted {
                statusPill(
                    title: L("permissions.status.granted"),
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            } else {
                HStack(spacing: 8) {
                    statusPill(
                        title: isRequired ? L("permissions.status.required") : L("permissions.status.not_granted"),
                        icon: isRequired ? "exclamationmark.triangle.fill" : "minus.circle.fill",
                        color: isRequired ? .orange : .secondary
                    )

                    GlassButton(title: actionTitle, icon: actionIcon, action: onGrant)
                        .fixedSize()
                }
            }
        }
    }

    private func statusPill(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.12))
        )
        .fixedSize()
    }

    private var relaunchBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(.orange)

            Text(L("permissions.relaunch_hint"))
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            GlassButton(
                title: L("permissions.restart_app"),
                icon: "arrow.clockwise"
            ) {
                permissions.relaunchApp()
            }
            .fixedSize()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
}
