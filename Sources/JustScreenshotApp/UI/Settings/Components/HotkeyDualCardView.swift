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
            // Иконка
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Название
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

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
                .frame(width: 128, alignment: .trailing)

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
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        Color.secondary.opacity(0.35),
                                        style: StrokeStyle(lineWidth: 1, dash: [3]))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 128, alignment: .trailing)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}
