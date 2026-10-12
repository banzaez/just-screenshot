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
    public let onSaveToHistory: () -> Void
    public let onSave: () -> Void
    
    @State private var justSavedToHistory: Bool = false
    
    public init(
        showBackdrop: Binding<Bool>,
        backdropPreset: Binding<BackdropPreset>,
        backdropPadding: Binding<CGFloat>,
        addShadow: Binding<Bool>,
        onClose: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onSaveToHistory: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self._showBackdrop = showBackdrop
        self._backdropPreset = backdropPreset
        self._backdropPadding = backdropPadding
        self._addShadow = addShadow
        self.onClose = onClose
        self.onCopy = onCopy
        self.onSaveToHistory = onSaveToHistory
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
            
            Button {
                onSaveToHistory()
                withAnimation(.easeInOut(duration: 0.2)) { justSavedToHistory = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeInOut(duration: 0.2)) { justSavedToHistory = false }
                }
            } label: {
                Label(
                    justSavedToHistory ? "Сохранено ✓" : "Сохранить",
                    systemImage: justSavedToHistory ? "checkmark.circle.fill" : "square.and.arrow.down"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(justSavedToHistory ? .green : nil)
            .keyboardShortcut("s", modifiers: [.command])
            .help("Сохранить снимок с аннотациями в историю приложения (⌘S)")
            
            Button(action: onSave) {
                Label("Экспорт…", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut("e", modifiers: [.command])
            .help("Экспортировать в файл через диалог сохранения (⌘E)")
        }
    }
}
