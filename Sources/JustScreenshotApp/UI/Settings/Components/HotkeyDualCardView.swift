import SwiftUI

struct HotkeyDualCardView: View {
    let id: String
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var primaryShortcut: ShortcutKey
    @Binding var altShortcut: ShortcutKey?
    @Binding var recordingTarget: HotkeyTarget?
    let onShortcutChanged: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Иконка в светящейся стеклянной подложке
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                iconColor.opacity(0.24),
                                iconColor.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        iconColor.opacity(0.5),
                                        iconColor.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Текстовое описание действия
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

            // Сетка двух слотов фиксированной одинаковой ширины для ровных колонок
            HStack(spacing: 14) {
                // 1. Основной шорткат
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L("settings.hotkeys.primary"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    SingleShortcutPillView(
                        target: .primary(id),
                        shortcut: primaryShortcut,
                        recordingTarget: $recordingTarget,
                        onRecord: { newKey in
                            primaryShortcut = newKey
                            onShortcutChanged()
                        },
                        onClear: nil
                    )
                }
                .frame(minWidth: 136, alignment: .trailing)

                // 2. Альтернативный шорткат
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L("settings.hotkeys.secondary"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    if recordingTarget == .alternate(id) {
                        EmptyShortcutRecorderPillView(
                            target: .alternate(id),
                            recordingTarget: $recordingTarget
                        ) { newKey in
                            altShortcut = newKey
                            onShortcutChanged()
                        }
                    } else if let alt = altShortcut {
                        SingleShortcutPillView(
                            target: .alternate(id),
                            shortcut: alt,
                            recordingTarget: $recordingTarget,
                            onRecord: { newKey in
                                altShortcut = newKey
                                onShortcutChanged()
                            },
                            onClear: {
                                altShortcut = nil
                                onShortcutChanged()
                            }
                        )
                    } else {
                        Button {
                            recordingTarget = .alternate(id)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                Text(L("settings.hotkeys.add_alt"))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(
                                        Color.white.opacity(0.22),
                                        style: StrokeStyle(lineWidth: 1, dash: [3])
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
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
