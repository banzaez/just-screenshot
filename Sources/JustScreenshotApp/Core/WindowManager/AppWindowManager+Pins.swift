import AppKit
import SwiftUI

extension AppWindowManager {
    // MARK: - Закрепление поверх окон (Pins)
    
    public func pin(image: NSImage, id: UUID) {
        let pinID = UUID()
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let scale = min(1, (visible.width * 0.6) / image.size.width, (visible.height * 0.6) / image.size.height)
        let size = NSSize(width: max(120, image.size.width * scale), height: max(80, image.size.height * scale))
        let offset = CGFloat(pins.count % 8) * 28
        let origin = NSPoint(x: visible.midX - size.width / 2 + offset, y: visible.midY - size.height / 2 - offset)
        
        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .resizable], backing: .buffered, defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.aspectRatio = size
        window.minSize = NSSize(width: 100, height: 70)
        
        window.contentView = NSHostingView(rootView: PinnedImageView(
            image: image,
            onClose: { [weak self] in self?.closePin(id: pinID) },
            onEdit: { [weak self] in self?.openAnnotationEditor(item: CapturedItem(image: image, rect: .zero)) }
        ))
        
        let managed = ManagedWindow(window: window) { [weak self] closed in
            self?.pins = self?.pins.filter { $0.value !== closed } ?? [:]
        }
        pins[pinID] = managed
        window.orderFrontRegardless()
    }
    
    func closePin(id: UUID) {
        guard let managed = pins.removeValue(forKey: id) else { return }
        managed.closeSilently()
    }
}
