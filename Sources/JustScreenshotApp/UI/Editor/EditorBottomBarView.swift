import SwiftUI
import AppKit

/// Нижняя панель: фон (пресеты, отступ, тень), закрыть / копировать / сохранить
public struct EditorBottomBarView: View {
    @Binding public var showBackdrop: Bool
    @Binding public var backdropPreset: BackdropPreset
    @Binding public var backdropPadding: CGFloat
    @Binding public var addShadow: Bool
    
    public let onClose: () -> Void
    public let onCopy: () -> Void
    public let onSave: () -> Void
    
    public init(
        showBackdrop: Binding<Bool>,
        backdropPreset: Binding<BackdropPreset>,
        backdropPadding: Binding<CGFloat>,
        addShadow: Binding<Bool>,
        onClose: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self._showBackdrop = showBackdrop
        self._backdropPreset = backdropPreset
        self._backdropPadding = backdropPadding
        self._addShadow = addShadow
        self.onClose = onClose
        self.onCopy = onCopy
        self.onSave = onSave
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Toggle("Красивый фон", isOn: $showBackdrop)
                .toggleStyle(.switch)
                .controlSize(.small)
            
            if showBackdrop {
                HStack(spacing: 6) {
                    ForEach(BackdropPreset.allCases) { preset in
                        Button { backdropPreset = preset } label: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(preset.gradient)
                                .frame(width: 26, height: 22)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(backdropPreset == preset ? Color.accentColor : Color.primary.opacity(0.2), lineWidth: backdropPreset == preset ? 2.5 : 1)
                                )
                                .frame(width: 32, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(preset.rawValue)
                    }
                }
                
                HStack(spacing: 6) {
                    Text("Отступ").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $backdropPadding, in: 16...120, step: 2).frame(width: 90)
                }
                
                Toggle("Тень", isOn: $addShadow)
                    .toggleStyle(.checkbox)
                    .font(.callout)
            }
            
            Spacer(minLength: 8)
            
            Button("Закрыть", action: onClose)
                .keyboardShortcut("w", modifiers: [.command])
                .controlSize(.large)
            
            Button(action: onCopy) {
                Label("Копировать", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut("c", modifiers: [.command, .shift])
            
            Button(action: onSave) {
                Label("Сохранить", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("s", modifiers: [.command])
        }
    }
}
