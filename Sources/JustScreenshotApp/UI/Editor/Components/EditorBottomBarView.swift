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
    
    public let onClose: () -> Void
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
        onClose: @escaping () -> Void,
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
        self.onClose = onClose
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
        HStack(spacing: 8) {
            EditorIconButton(
                "rectangle.on.rectangle.angled",
                title: L("editor.backdrop"),
                isActive: showBackdrop,
                width: 32
            ) {
                showBackdrop.toggle()
            }
            
            if showBackdrop {
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
                
                EditorIconButton(
                    "slider.horizontal.3",
                    title: L("editor.padding"),
                    isActive: showAdjustPopover,
                    width: 30
                ) {
                    showAdjustPopover.toggle()
                }
                .popover(isPresented: $showAdjustPopover, arrowEdge: .top) {
                    adjustPopover
                }
                
                EditorIconButton(
                    "shadow",
                    title: L("editor.shadow_help"),
                    isActive: addShadow,
                    width: 30
                ) {
                    addShadow.toggle()
                }
            }
        }
        .padding(4)
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
        HStack(spacing: 4) {
            EditorIconButton("xmark", title: L("editor.close"), width: 32, action: onClose)
                .keyboardShortcut("w", modifiers: [.command])
            
            EditorIconButton("doc.on.doc", title: L("editor.copy"), width: 32, action: onCopy)
                .keyboardShortcut("c", modifiers: [.command, .shift])
            
            Button {
                onSaveToHistory()
                withAnimation(.easeInOut(duration: 0.2)) { justSavedToHistory = true }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    withAnimation(.easeInOut(duration: 0.2)) { justSavedToHistory = false }
                }
            } label: {
                Image(systemName: justSavedToHistory ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 32, height: 30)
                    .foregroundStyle(Color.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(justSavedToHistory ? Color.green : Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
            .help(L("editor.save_history_help"))
            .keyboardShortcut("s", modifiers: [.command])
            .accessibilityLabel(justSavedToHistory ? L("editor.saved") : L("editor.save"))
            
            EditorIconButton("square.and.arrow.up", title: L("editor.export"), width: 32, action: onSave)
                .keyboardShortcut("e", modifiers: [.command])
        }
        .padding(4)
        .background(capsuleBackground)
    }
    
    private var capsuleBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.05))
    }
}
