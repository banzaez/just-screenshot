import SwiftUI
import AppKit

/// Плавающий оверлей Quick Access в углу экрана
public struct QuickAccessOverlayView: View {
    public let item: CapturedItem
    public let onAnnotate: () -> Void
    public let onSave: () -> Void
    public let onCopy: () -> Void
    public let onPin: () -> Void
    public let onOCR: (@escaping (String) -> Void) -> Void
    public let onDelete: () -> Void
    public let onClose: () -> Void
    public let onHover: (Bool) -> Void
    
    @State private var feedback: String?
    @State private var feedbackTask: Task<Void, Never>?
    @State private var isThumbnailHovered = false
    @State private var justCopied = false
    
    public init(
        item: CapturedItem,
        onAnnotate: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onPin: @escaping () -> Void,
        onOCR: @escaping (@escaping (String) -> Void) -> Void,
        onDelete: @escaping () -> Void = {},
        onClose: @escaping () -> Void,
        onHover: @escaping (Bool) -> Void
    ) {
        self.item = item
        self.onAnnotate = onAnnotate
        self.onSave = onSave
        self.onCopy = onCopy
        self.onPin = onPin
        self.onOCR = onOCR
        self.onDelete = onDelete
        self.onClose = onClose
        self.onHover = onHover
    }
    
    private func flash(_ text: String) {
        feedbackTask?.cancel()
        feedback = text
        feedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if !Task.isCancelled {
                feedback = nil
            }
        }
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Превью скриншота (клик открывает редактор, перетаскивание — Drag & Drop файла)
            ZStack {
                Image(nsImage: item.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 132, height: 98)
                    .background(Color.black.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isThumbnailHovered ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.22),
                                lineWidth: isThumbnailHovered ? 1.5 : 1
                            )
                    )
                    .shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 2)
                
                if isThumbnailHovered && feedback == nil {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.38))
                        .frame(width: 132, height: 98)
                        .overlay(
                            Image(systemName: "slider.horizontal.below.square.and.square.filled")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                        )
                        .transition(.opacity)
                }
                
                if let feedback {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.82))
                        .frame(width: 132, height: 98)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.green)
                                Text(feedback)
                                    .font(.system(size: 11, weight: .bold))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.white)
                            }
                            .padding(6)
                        )
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: feedback)
            .animation(.easeOut(duration: 0.15), value: isThumbnailHovered)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onHover { isThumbnailHovered = $0 }
            .onTapGesture(perform: onAnnotate)
            .help(L("hud.editor"))
            .onDrag {
                if let tempURL = ImageExporter.saveTemporaryPNG(item.image) {
                    return NSItemProvider(object: tempURL as NSURL)
                }
                return NSItemProvider(object: item.image)
            }
            
            // Правая часть: заголовок + управление и нижний ряд действий (ровно под ширину 5 кнопок: 5*34 + 4*6 = 194pt)
            VStack(alignment: .leading, spacing: 8) {
                // Верхняя строка: название + разрешение слева, Удалить и Закрыть справа
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("hud.screenshot"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("\(Int(item.image.size.width)) × \(Int(item.image.size.height)) px")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 4)
                    
                    HStack(spacing: 5) {
                        HUDHeaderCircleButton(
                            icon: "trash",
                            tooltip: L("history.delete_button"),
                            isDestructive: true,
                            action: onDelete
                        )
                        
                        HUDHeaderCircleButton(
                            icon: "xmark",
                            tooltip: L("editor.close"),
                            isDestructive: false,
                            action: onClose
                        )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onAnnotate)
                
                Spacer(minLength: 0)
                
                // Нижняя строка: 5 иконочных кнопок (5 * 34 + 4 * 6 = 194pt)
                HStack(spacing: 6) {
                    // 1. Открыть редактор
                    HUDActionIconButton(
                        icon: "pencil.and.outline",
                        style: .primary,
                        tooltip: L("hud.editor"),
                        action: onAnnotate
                    )
                    
                    // 2. Скопировать в буфер
                    HUDActionIconButton(
                        icon: justCopied ? "checkmark" : "doc.on.doc",
                        style: justCopied ? .success : .secondary,
                        tooltip: L("editor.copy")
                    ) {
                        onCopy()
                        flash(L("hud.copied"))
                        withAnimation(.easeInOut(duration: 0.15)) { justCopied = true }
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.4))
                            withAnimation(.easeInOut(duration: 0.15)) { justCopied = false }
                        }
                    }
                    
                    // 3. Сохранить как (Скачать файл)
                    HUDActionIconButton(
                        icon: "arrow.down.to.line",
                        style: .secondary,
                        tooltip: L("hud.save_as"),
                        action: onSave
                    )
                    
                    // 4. Закрепить поверх окон
                    HUDActionIconButton(
                        icon: "pin",
                        style: .secondary,
                        tooltip: L("hud.pin_top"),
                        action: onPin
                    )
                    
                    // 5. Распознать текст (OCR)
                    HUDActionIconButton(
                        icon: "text.viewfinder",
                        style: .secondary,
                        tooltip: L("hud.ocr_button")
                    ) {
                        flash(L("hud.recognizing"))
                        onOCR { text in
                            flash(text.isEmpty ? L("hud.ocr_not_found") : L("hud.ocr_copied", text.count))
                        }
                    }
                }
            }
            .frame(width: 194)
        }
        .padding(12)
        .frame(width: 362, height: 122)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onAnnotate)
        .shadow(color: .black.opacity(0.38), radius: 16, x: 0, y: 8)
        .onHover(perform: onHover)
    }
}

// MARK: - Кнопки плашки Quick Access HUD

private struct HUDHeaderCircleButton: View {
    let icon: String
    let tooltip: String
    let isDestructive: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(backgroundColor)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
    
    private var foregroundColor: Color {
        if isDestructive {
            return isHovered ? .white : .red
        }
        return isHovered ? .primary : .secondary
    }
    
    private var backgroundColor: Color {
        if isDestructive {
            return isHovered ? Color.red.opacity(0.85) : Color.red.opacity(0.14)
        }
        return isHovered ? Color.primary.opacity(0.18) : Color.primary.opacity(0.09)
    }
}

private struct HUDActionIconButton: View {
    enum Style {
        case primary
        case secondary
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
                .frame(width: 34, height: 32)
                .foregroundStyle(foregroundColor)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(borderColor, lineWidth: 0.8)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
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
        case .secondary:
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isHovered ? Color.accentColor.opacity(0.88) : Color.accentColor
        case .success:
            return Color.green
        case .secondary:
            return isHovered ? Color.primary.opacity(0.16) : Color.primary.opacity(0.08)
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .success:
            return Color.white.opacity(0.2)
        case .secondary:
            return Color.primary.opacity(isHovered ? 0.22 : 0.1)
        }
    }
}
