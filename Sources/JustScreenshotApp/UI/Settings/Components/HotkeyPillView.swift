import SwiftUI

enum HotkeyTarget: Hashable {
    case primary(String)
    case alternate(String)
}

struct SingleShortcutPillView: View {
    let target: HotkeyTarget
    let shortcut: ShortcutKey
    @Binding var recordingTarget: HotkeyTarget?
    let onRecord: (ShortcutKey) -> Void
    let onClear: (() -> Void)?

    var isRecordingThis: Bool {
        recordingTarget == target
    }

    var body: some View {
        HStack(spacing: 4) {
            if isRecordingThis {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.blue.opacity(0.8), radius: 4)

                    Text(L("settings.hotkeys.press_keys"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)

                    Button("✕") {
                        recordingTarget = nil
                    }
                    .font(.system(size: 10, weight: .bold))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.blue, lineWidth: 1.5)
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 1)
                .background(
                    ShortcutRecorderView(
                        shortcut: Binding(
                            get: { shortcut },
                            set: { newKey in onRecord(newKey) }
                        )
                    ) {
                        recordingTarget = nil
                    }
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                )
            } else {
                HStack(spacing: 4) {
                    Button {
                        recordingTarget = target
                    } label: {
                        HStack(spacing: 3) {
                            ForEach(Array(shortcut.keySymbols.enumerated()), id: \.offset) { _, sym in
                                Text(sym)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, sym.count > 1 ? 6 : 4)
                                    .frame(minWidth: 22, minHeight: 22)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.20),
                                                        Color.white.opacity(0.08)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.40),
                                                        Color.white.opacity(0.12)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.12), radius: 1.5, x: 0, y: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(L("settings.hotkeys.click_to_change"))

                    if let onClear {
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                        .help(L("settings.hotkeys.remove_alt"))
                    }
                }
            }
        }
    }
}

struct EmptyShortcutRecorderPillView: View {
    let target: HotkeyTarget
    @Binding var recordingTarget: HotkeyTarget?
    let onRecord: (ShortcutKey) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
                .shadow(color: Color.blue.opacity(0.8), radius: 4)

            Text(L("settings.hotkeys.press_keys"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.blue)

            Button("✕") {
                recordingTarget = nil
            }
            .font(.system(size: 10, weight: .bold))
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.blue.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.blue, lineWidth: 1.5)
        )
        .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 1)
        .background(
            ShortcutRecorderView(
                shortcut: Binding(
                    get: { ShortcutKey(keyCode: 0, keyChar: "") },
                    set: { newKey in onRecord(newKey) }
                )
            ) {
                recordingTarget = nil
            }
            .frame(width: 1, height: 1)
            .opacity(0.01)
        )
    }
}
