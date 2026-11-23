import SwiftUI

struct HotkeyDualCardView: View {
    let action: AppSettings.ShortcutAction
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let primaryShortcut: ShortcutKey?
    let altShortcut: ShortcutKey?
    @Binding var recordingTarget: HotkeyTarget?
    let onRecordPrimary: (ShortcutKey) -> Void
    let onRecordAlternate: (ShortcutKey) -> Void
    let onClearPrimary: (() -> Void)?
    let onClearAlternate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            GlassIconBadge(
                systemImage: icon,
                color: iconColor,
                size: 38,
                cornerRadius: 10,
                iconSize: 16
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            HStack(spacing: 14) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L("settings.hotkeys.primary"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    SingleShortcutPillView(
                        target: .primary(action),
                        shortcut: primaryShortcut,
                        recordingTarget: $recordingTarget,
                        onRecord: onRecordPrimary,
                        onClear: primaryShortcut != nil ? onClearPrimary : nil
                    )
                }
                .frame(minWidth: 136, alignment: .trailing)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(L("settings.hotkeys.secondary"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    SingleShortcutPillView(
                        target: .alternate(action),
                        shortcut: altShortcut,
                        recordingTarget: $recordingTarget,
                        onRecord: onRecordAlternate,
                        onClear: altShortcut != nil ? onClearAlternate : nil
                    )
                }
                .frame(minWidth: 136, alignment: .trailing)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.28), location: 0.0),
                            .init(color: Color.white.opacity(0.08), location: 0.4),
                            .init(color: Color.white.opacity(0.02), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}
