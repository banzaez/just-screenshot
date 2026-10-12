import SwiftUI
import AppKit

/// Нижняя панель: фон (пресеты, отступ, тень), закрыть / копировать / сохранить
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
        HStack(spacing: 12) {
            // Группа фона с выпадающим меню и настройками
            backdropControlGroup
            
            Spacer(minLength: 12)
            
            Button(L("editor.close"), action: onClose)
                .keyboardShortcut("w", modifiers: [.command])
                .controlSize(.regular)
            
            Button(action: onCopy) {
                Label(L("editor.copy"), systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .keyboardShortcut("c", modifiers: [.command, .shift])
            
            Button {
                onSaveToHistory()
                withAnimation(.easeInOut(duration: 0.2)) { justSavedToHistory = true }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    withAnimation(.easeInOut(duration: 0.2)) { justSavedToHistory = false }
                }
            } label: {
                Label(
                    justSavedToHistory ? L("editor.saved") : L("editor.save"),
                    systemImage: justSavedToHistory ? "checkmark.circle.fill" : "square.and.arrow.down"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(justSavedToHistory ? .green : nil)
            .keyboardShortcut("s", modifiers: [.command])
            .help(L("editor.save_history_help"))
            
            Button(action: onSave) {
                Label(L("editor.export"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .keyboardShortcut("e", modifiers: [.command])
            .help(L("editor.export_help"))
        }
    }
    
    // MARK: - Группа настроек фона с выпадающим меню и компактными ползунками
    
    private var backdropControlGroup: some View {
        HStack(spacing: 8) {
            // Переключатель фона (галочка / checkbox)
            Toggle(L("editor.backdrop"), isOn: $showBackdrop)
                .toggleStyle(.checkbox)
                .font(.system(size: 12, weight: .medium))
            
            if showBackdrop {
                // Выбор пресета градиента/фона исключительно цветами (кружки-свотчи)
                HStack(spacing: 6) {
                    ForEach(BackdropPreset.allCases) { preset in
                        Button {
                            backdropPreset = preset
                        } label: {
                            Circle()
                                .fill(preset.gradient)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(backdropPreset == preset ? 0.9 : 0.25), lineWidth: backdropPreset == preset ? 2 : 0.8)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 1)
                                        .opacity(backdropPreset == preset ? 1 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(preset.rawValue)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.04))
                )
                
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 2)
                
                // Компактные стильные ползунки параметров
                compactSlider(
                    label: L("editor.padding"),
                    icon: "arrow.up.left.and.arrow.down.right",
                    value: $backdropPadding,
                    range: 16...120,
                    step: 2,
                    unit: L("editor.unit_px")
                )
                
                compactSlider(
                    label: L("editor.corners"),
                    icon: "square.dashed",
                    value: $backdropCornerRadius,
                    range: 0...32,
                    step: 2,
                    unit: L("editor.unit_px")
                )
                
                // Переключатель тени
                Toggle(isOn: $addShadow) {
                    Image(systemName: "shadow")
                        .font(.system(size: 11, weight: .semibold))
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .tint(addShadow ? .accentColor : nil)
                .controlSize(.mini)
                .help(L("editor.shadow_help"))
                
                if addShadow {
                    compactSlider(
                        label: L("editor.shadow"),
                        icon: "circle.lefthalf.striped.horizontal",
                        value: $backdropShadowRadius,
                        range: 4...60,
                        step: 4,
                        unit: L("editor.unit_px")
                    )
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(showBackdrop ? Color.primary.opacity(0.03) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(showBackdrop ? Color.primary.opacity(0.08) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: showBackdrop)
        .animation(.easeInOut(duration: 0.2), value: addShadow)
    }
    
    // MARK: - Элегантный компактный ползунок со значением
    
    @ViewBuilder
    private func compactSlider(
        label: String,
        icon: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat,
        unit: String
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Slider(value: value, in: range, step: step)
                .frame(width: 58)
                .controlSize(.mini)
            
            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 18, alignment: .trailing)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(0.04))
        )
        .help("\(label): \(Int(value.wrappedValue)) \(unit)")
    }
}
