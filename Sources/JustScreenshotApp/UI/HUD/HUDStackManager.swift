import SwiftUI
import AppKit

/// Стек плавающих всплывающих окон (Quick Access): новые снизу, старые поднимаются выше,
/// каждое закрывается само по таймеру (с паузой при наведении)
@MainActor
final class HUDStackManager {
    struct Actions {
        var onAnnotate: () -> Void
        var onSave: () -> Void
        var onCopy: () -> Void
        var onPin: () -> Void
        var onOCR: (@escaping (String) -> Void) -> Void
    }
    
    private final class Entry {
        let id = UUID()
        let window: NSWindow
        var timeout: Task<Void, Never>?
        init(window: NSWindow) { self.window = window }
    }
    
    private static let width: CGFloat = 440
    private static let height: CGFloat = 124
    private static let spacing: CGFloat = 10
    private static let margin: CGFloat = 24
    private static let maxVisible = 4
    private static let lifetime: UInt64 = 9_000_000_000
    private static let afterHoverLifetime: UInt64 = 3_000_000_000
    
    private var entries: [Entry] = [] // новые — первые
    
    func show(item: CapturedItem, actions: Actions) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.height),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.alphaValue = 0
        
        let entry = Entry(window: window)
        let id = entry.id
        
        let view = QuickAccessOverlayView(
            item: item,
            onAnnotate: { [weak self] in self?.dismiss(id: id); actions.onAnnotate() },
            onSave: { actions.onSave() },
            onCopy: { actions.onCopy() },
            onPin: { [weak self] in self?.dismiss(id: id); actions.onPin() },
            onOCR: { actions.onOCR($0) },
            onClose: { [weak self] in self?.dismiss(id: id) },
            onHover: { [weak self] hovering in self?.hoverChanged(id: id, hovering: hovering) }
        )
        window.contentView = NSHostingView(rootView: view)
        
        // Стартовая позиция чуть левее, затем анимируется на место
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            window.setFrame(
                NSRect(x: vf.minX + Self.margin - 40, y: vf.minY + Self.margin, width: Self.width, height: Self.height),
                display: false
            )
        }
        window.orderFrontRegardless()
        
        entries.insert(entry, at: 0)
        while entries.count > Self.maxVisible, let oldest = entries.last {
            dismiss(id: oldest.id)
        }
        startTimer(entry, nanoseconds: Self.lifetime)
        layout()
    }
    
    func dismiss(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        let entry = entries.remove(at: idx)
        entry.timeout?.cancel()
        entry.window.orderOut(nil)
        entry.window.contentView = nil
        entry.window.close()
        layout()
    }
    
    func dismissAll() {
        for e in entries { dismiss(id: e.id) }
    }
    
    private func hoverChanged(id: UUID, hovering: Bool) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        if hovering {
            entry.timeout?.cancel()
            entry.timeout = nil
        } else {
            startTimer(entry, nanoseconds: Self.afterHoverLifetime)
        }
    }
    
    private func startTimer(_ entry: Entry, nanoseconds: UInt64) {
        entry.timeout?.cancel()
        let id = entry.id
        entry.timeout = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            self?.dismiss(id: id)
        }
    }
    
    private func layout() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        for (i, entry) in entries.enumerated() {
            let frame = NSRect(
                x: vf.minX + Self.margin,
                y: vf.minY + Self.margin + CGFloat(i) * (Self.height + Self.spacing),
                width: Self.width, height: Self.height
            )
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                entry.window.animator().setFrame(frame, display: true)
                entry.window.animator().alphaValue = 1
            }
        }
    }
}
