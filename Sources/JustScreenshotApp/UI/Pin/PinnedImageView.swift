import SwiftUI
import AppKit

/// Закреплённый поверх всех окон снимок (Pin to screen)
public struct PinnedImageView: View {
    public let image: NSImage
    public let onClose: () -> Void
    public let onEdit: () -> Void
    
    @State private var hovering = false
    @State private var opacity: Double = 1.0
    
    public init(image: NSImage, onClose: @escaping () -> Void, onEdit: @escaping () -> Void) {
        self.image = image
        self.onClose = onClose
        self.onEdit = onEdit
    }
    
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(opacity)
            
            if hovering {
                HStack(spacing: 4) {
                    EditorIconButton("pencil", title: L("history.edit"), width: 30, action: onEdit)
                    EditorIconButton("xmark", title: L("pin.unpin"), width: 30, action: onClose)
                }
                .padding(6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9))
                .padding(8)
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.35), lineWidth: 1))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .onDrag {
            if let tempURL = ImageExporter.saveTemporaryPNG(image) {
                return NSItemProvider(object: tempURL as NSURL)
            }
            return NSItemProvider(object: image)
        }
        .contextMenu {
            Button(L("editor.copy")) { ImageExporter.copyToClipboard(image) }
            Menu(L("pin.opacity")) {
                ForEach([1.0, 0.8, 0.6, 0.4], id: \.self) { v in
                    Button("\(Int(v * 100))%") { opacity = v }
                }
            }
            Divider()
            Button(L("pin.unpin"), action: onClose)
        }
    }
}
