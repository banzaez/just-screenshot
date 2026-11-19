import SwiftUI
import AppKit

struct HotkeysSettingsTab: View {
    private struct Descriptor: Identifiable {
        let action: AppSettings.ShortcutAction
        let icon: String
        let iconColor: Color
        let titleKey: String
        let subtitleKey: String

        var id: String { action.id }
    }

    private static let descriptors: [Descriptor] = [
        Descriptor(action: .area, icon: "crop", iconColor: .blue, titleKey: "settings.hotkeys.area_title", subtitleKey: "settings.hotkeys.area_sub"),
        Descriptor(action: .window, icon: "macwindow", iconColor: .teal, titleKey: "settings.hotkeys.window_title", subtitleKey: "settings.hotkeys.window_sub"),
        Descriptor(action: .recording, icon: "record.circle.fill", iconColor: .red, titleKey: "settings.hotkeys.record_title", subtitleKey: "settings.hotkeys.record_sub"),
        Descriptor(action: .repeatCapture, icon: "arrow.counterclockwise", iconColor: .purple, titleKey: "settings.hotkeys.repeat_title", subtitleKey: "settings.hotkeys.repeat_sub"),
        Descriptor(action: .ocr, icon: "text.viewfinder", iconColor: .indigo, titleKey: "settings.hotkeys.ocr_title", subtitleKey: "settings.hotkeys.ocr_sub"),
        Descriptor(action: .history, icon: "clock.arrow.circlepath", iconColor: .orange, titleKey: "settings.hotkeys.history_title", subtitleKey: "settings.hotkeys.history_sub")
    ]

    var settings = AppSettings.shared
    @State private var recordingTarget: HotkeyTarget?
    @State private var conflictWarning: String?
    @State private var conflictDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassCard(padding: 14) {
                HStack(alignment: .center) {
                    GlassSectionHeader(
                        title: L("settings.hotkeys.title"),
                        subtitle: L("settings.hotkeys.subtitle"),
                        systemImage: "keyboard",
                        iconColor: .cyan
                    )

                    Spacer()

                    GlassButton(
                        title: L("settings.hotkeys.reset_all"),
                        icon: "arrow.counterclockwise"
                    ) {
                        recordingTarget = nil
                        clearConflictWarning()
                        settings.resetHotkeysToDefaults()
                        AppWindowManager.shared.reloadGlobalHotkeys()
                    }
                }
            }

            if let conflictWarning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                    Text(conflictWarning)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            VStack(spacing: 8) {
                ForEach(Self.descriptors) { desc in
                    let pair = settings.shortcutPair(for: desc.action)
                    HotkeyDualCardView(
                        action: desc.action,
                        icon: desc.icon,
                        iconColor: desc.iconColor,
                        title: L(desc.titleKey),
                        subtitle: L(desc.subtitleKey),
                        primaryShortcut: pair.primary,
                        altShortcut: pair.alternate,
                        recordingTarget: $recordingTarget,
                        onRecordPrimary: { newKey in
                            assignShortcut(newKey, to: .primary(desc.action))
                        },
                        onRecordAlternate: { newKey in
                            assignShortcut(newKey, to: .alternate(desc.action))
                        },
                        onClearAlternate: {
                            clearConflictWarning()
                            setAlternateShortcut(nil, for: desc.action)
                            AppWindowManager.shared.reloadGlobalHotkeys()
                        }
                    )
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                Text(L("settings.hotkeys.protected_note"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
        }
        .onDisappear {
            conflictDismissTask?.cancel()
        }
    }

    private func assignShortcut(_ newKey: ShortcutKey, to target: HotkeyTarget) {
        if settings.hasConflict(newKey, excludingTargetID: target.conflictTargetID) {
            NSSound.beep()
            showConflictWarning()
            return
        }

        clearConflictWarning()
        switch target {
        case .primary(let action):
            setPrimaryShortcut(newKey, for: action)
        case .alternate(let action):
            setAlternateShortcut(newKey, for: action)
        }
        AppWindowManager.shared.reloadGlobalHotkeys()
    }

    private func setPrimaryShortcut(_ shortcut: ShortcutKey, for action: AppSettings.ShortcutAction) {
        switch action {
        case .area: settings.shortcutArea = shortcut
        case .window: settings.shortcutWindow = shortcut
        case .recording: settings.shortcutRecording = shortcut
        case .repeatCapture: settings.shortcutRepeat = shortcut
        case .ocr: settings.shortcutOCR = shortcut
        case .history: settings.shortcutHistory = shortcut
        }
    }

    private func setAlternateShortcut(_ shortcut: ShortcutKey?, for action: AppSettings.ShortcutAction) {
        switch action {
        case .area: settings.shortcutAreaAlt = shortcut
        case .window: settings.shortcutWindowAlt = shortcut
        case .recording: settings.shortcutRecordingAlt = shortcut
        case .repeatCapture: settings.shortcutRepeatAlt = shortcut
        case .ocr: settings.shortcutOCRAlt = shortcut
        case .history: settings.shortcutHistoryAlt = shortcut
        }
    }

    private func showConflictWarning() {
        conflictDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            conflictWarning = L("settings.hotkeys.conflict_note")
        }
        conflictDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                conflictWarning = nil
            }
        }
    }

    private func clearConflictWarning() {
        conflictDismissTask?.cancel()
        if conflictWarning != nil {
            withAnimation(.easeInOut(duration: 0.15)) {
                conflictWarning = nil
            }
        }
    }
}
