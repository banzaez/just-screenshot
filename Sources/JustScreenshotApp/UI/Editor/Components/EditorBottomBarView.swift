import SwiftUI
import AppKit

/// Компактная нижняя панель: фон + действия
public struct EditorBottomBarView: View {
    @Binding public var showBackdrop: Bool
    @Binding public var backdropPreset: BackdropPreset
    @Binding public var backdropPadding: CGFloat
    @Binding public var backdropCornerRadius: CGFloat
    @Binding public var backdropShadowRadius: CGFloat
    @Binding public var addShadow: Bool
    @Binding public var justCopied: Bool
    
    public let onClose: () -> Void
    public let onDelete: () -> Void
    public let onCopy: () -> Void
    public let onSaveToHistory: () -> Void
    public let onSave: () -> Void
    
    @State private var justSavedToHistory: Bool = false
    @State private var showAdjustPopover: Bool = false
    
    public init(
        showBackdrop: Binding<Bool>,
        backdropPreset: Binding<BackdropPreset>,
        backdropPadding: Binding<CGFloat>,
        backdropCornerRadius: Binding<CGFloat>,
        backdropShadowRadius: Binding<CGFloat>,
        addShadow: Binding<Bool>,
        justCopied: Binding<Bool> = .constant(false),
        onClose: @escaping () -> Void,
        onDelete: @escaping () -> Void = {},
        onCopy: @escaping () -> Void,
        onSaveToHistory: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self._showBackdrop = showBackdrop
        self._backdropPreset = backdropPreset
        self._backdropPadding = backdropPadding
        self._backdropCornerRadius = backdropCornerRadius
        self._backdropShadowRadius = backdropShadowRadius
        self._addShadow = addShadow
        self._justCopied = justCopied
        self.onClose = onClose
        self.onDelete = onDelete
        self.onCopy = onCopy
        self.onSaveToHistory = onSaveToHistory
        self.onSave = onSave
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            backdropCapsule
            Spacer(minLength: 8)
            actionsCapsule
        }
    }
    
    // MARK: - Backdrop
    
    private var backdropCapsule: some View {
        HStack(spacing: 6) {
            EditorActionIconButton(
                icon: "rectangle.on.rectangle.angled",
                style: showBackdrop ? .primary : .secondary,
                tooltip: L("editor.backdrop")
            ) {
                showBackdrop.toggle()
            }
            
            if showBackdrop {
                Divider()
                    .frame(height: 18)
                    .padding(.horizontal, 2)
                
                HStack(spacing: 5) {
                    ForEach(BackdropPreset.allCases) { preset in
                        Button {
                            backdropPreset = preset
                        } label: {
                            Circle()
                                .fill(preset.gradient)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            Color.primary.opacity(backdropPreset == preset ? 0.95 : 0.2),
                                            lineWidth: backdropPreset == preset ? 1.5 : 0.5
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .help(preset.rawValue)
                    }
                }
                
                EditorActionIconButton(
                    icon: "slider.horizontal.3",
                    style: showAdjustPopover ? .primary : .secondary,
                    tooltip: L("editor.padding")
                ) {
                    showAdjustPopover.toggle()
                }
                .popover(isPresented: $showAdjustPopover, arrowEdge: .top) {
                    adjustPopover
                }
                
                EditorActionIconButton(
                    icon: "shadow",
                    style: addShadow ? .primary : .secondary,
                    tooltip: L("editor.shadow_help")
                ) {
                    addShadow.toggle()
                }
            }
        }
        .padding(5)
        .background(capsuleBackground)
        .animation(.easeInOut(duration: 0.18), value: showBackdrop)
    }
    
    private var adjustPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            adjustRow(
                icon: "arrow.up.left.and.arrow.down.right",
                title: L("editor.padding"),
                value: $backdropPadding,
                range: 16...120,
                step: 2
            )
            adjustRow(
                icon: "square.dashed",
                title: L("editor.corners"),
                value: $backdropCornerRadius,
                range: 0...32,
                step: 2
            )
            if addShadow {
                adjustRow(
                    icon: "circle.lefthalf.striped.horizontal",
                    title: L("editor.shadow"),
                    value: $backdropShadowRadius,
                    range: 4...60,
                    step: 4
                )
            }
        }
        .padding(14)
        .frame(width: 240)
    }
    
    private func adjustRow(
        icon: String,
        title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("\(Int(value.wrappedValue)) \(L("editor.unit_px"))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .controlSize(.small)
        }
    }
    
    // MARK: - Actions
    
    private var actionsCapsule: some View {
        HStack(spacing: 6) {
            // 1. Удалить (из истории и закрыть)
            EditorActionIconButton(
                icon: "trash",
                style: .destructive,
                tooltip: L("history.delete_button"),
                action: onDelete
            )
            
            // 2. Закрыть окно редактора
            EditorActionIconButton(
                icon: "xmark",
                style: .secondary,
                tooltip: L("editor.close"),
                action: onClose
            )
            .keyboardShortcut("w", modifiers: [.command])
            
            Divider()
                .frame(height: 18)
                .padding(.horizontal, 2)
            
            // 3. Копировать в буфер обмена (с визуальным откликом)
            EditorActionIconButton(
                icon: justCopied ? "checkmark" : "doc.on.doc",
                style: justCopied ? .success : .secondary,
                tooltip: justCopied ? L("hud.copied") : L("editor.copy"),
                action: onCopy
            )
            .keyboardShortcut("c", modifiers: [.command, .shift])
            
            // 4. Сохранить в историю приложения
            EditorActionIconButton(
                icon: justSavedToHistory ? "checkmark.circle.fill" : "clock.arrow.circlepath",
                style: justSavedToHistory ? .success : .secondary,
                tooltip: L("editor.save_history_help")
            ) {
                onSaveToHistory()
                withAnimation(.easeInOut(duration: 0.2)) { justSavedToHistory = true }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    withAnimation(.easeInOut(duration: 0.2)) { justSavedToHistory = false }
                }
            }
            .keyboardShortcut("s", modifiers: [.command])
            
            // 5. Сохранить как… (скачать в файл на диск)
            EditorActionIconButton(
                icon: "arrow.down.to.line",
                style: .primary,
                tooltip: L("editor.export_help"),
                action: onSave
            )
            .keyboardShortcut("e", modifiers: [.command])
        }
        .padding(5)
        .background(capsuleBackground)
    }
    
    private var capsuleBackground: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(Color.primary.opacity(0.05))
    }
}

private struct EditorActionIconButton: View {
    enum Style {
        case primary
        case secondary
        case destructive
        case success
    }
    
    let icon: String
    let style: Style
    let tooltip: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 36, height: 30)
                .foregroundStyle(foregroundColor)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(borderColor, lineWidth: 0.8)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .success:
            return .white
        case .destructive:
            return isHovered ? .white : .red
        case .secondary:
            return .primary.opacity(0.9)
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isHovered ? Color.accentColor.opacity(0.9) : Color.accentColor
        case .success:
            return Color.green
        case .destructive:
            return isHovered ? Color.red.opacity(0.85) : Color.red.opacity(0.12)
        case .secondary:
            return isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.05)
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .success:
            return Color.white.opacity(0.18)
        case .destructive:
            return Color.red.opacity(isHovered ? 0.4 : 0.2)
        case .secondary:
            return Color.primary.opacity(isHovered ? 0.16 : 0.06)
        }
    }
}
