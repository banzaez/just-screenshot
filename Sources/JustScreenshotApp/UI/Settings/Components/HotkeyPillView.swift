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
                    Text(L("settings.hotkeys.press_keys"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)

                    Button("✕") {
                        recordingTarget = nil
                    }
                    .font(.system(size: 10, weight: .bold))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue, lineWidth: 1.5)
                )
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
                HStack(spacing: 2) {
                    Button {
                        recordingTarget = target
                    } label: {
                        HStack(spacing: 3) {
                            ForEach(shortcut.keySymbols, id: \.self) { sym in
                                Text(sym)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 20, minHeight: 20)
                                    .padding(.horizontal, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(NSColor.controlBackgroundColor))
                                            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(L("settings.hotkeys.click_to_change"))

                    if let onClear {
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
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
            Text(L("settings.hotkeys.press_keys"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.blue)

            Button("✕") {
                recordingTarget = nil
            }
            .font(.system(size: 10, weight: .bold))
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.blue, lineWidth: 1.5)
        )
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
