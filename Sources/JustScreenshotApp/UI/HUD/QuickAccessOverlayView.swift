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
    public let onClose: () -> Void
    public let onHover: (Bool) -> Void
    
    @State private var feedback: String?
    @State private var feedbackTask: Task<Void, Never>?
    
    public init(
        item: CapturedItem,
        onAnnotate: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onPin: @escaping () -> Void,
        onOCR: @escaping (@escaping (String) -> Void) -> Void,
        onClose: @escaping () -> Void,
        onHover: @escaping (Bool) -> Void
    ) {
        self.item = item
        self.onAnnotate = onAnnotate
        self.onSave = onSave
        self.onCopy = onCopy
        self.onPin = onPin
        self.onOCR = onOCR
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
        HStack(spacing: 14) {
            ZStack {
                Image(nsImage: item.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 96)
                    .background(Color.black.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .shadow(radius: 6)
                
                if let feedback {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.78))
                        .frame(width: 140, height: 96)
                        .overlay(
                            Text(feedback)
                                .font(.system(size: 12, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.green)
                                .padding(6)
                        )
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: feedback)
            .onDrag {
                if let tempURL = ImageExporter.saveTemporaryPNG(item.image) {
                    return NSItemProvider(object: tempURL as NSURL)
                }
                return NSItemProvider(object: item.image)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("hud.screenshot"))
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(Int(item.image.size.width)) × \(Int(item.image.size.height)) px")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.secondary.opacity(0.2)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(L("editor.close"))
                }
                
                HStack(spacing: 6) {
                    Button(action: onAnnotate) {
                        Label(L("hud.editor"), systemImage: "pencil.tip.crop.circle")
                            .font(.system(size: 12, weight: .medium))
                            .frame(height: 28)
                            .padding(.horizontal, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderedProminent)
                    
                    EditorIconButton("doc.on.doc", title: L("editor.copy"), width: 30) {
                        onCopy()
                        flash(L("hud.copied"))
                    }
                    EditorIconButton("square.and.arrow.down", title: L("hud.save_as"), width: 30, action: onSave)
                    EditorIconButton("pin", title: L("hud.pin_top"), width: 30, action: onPin)
                    EditorIconButton("text.viewfinder", title: L("hud.ocr_button"), width: 30) {
                        flash(L("hud.recognizing"))
                        onOCR { text in
                            flash(text.isEmpty ? L("hud.ocr_not_found") : L("hud.ocr_copied", text.count))
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 440, height: 124)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.28), lineWidth: 1.2))
        )
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
        .onHover(perform: onHover)
    }
}
