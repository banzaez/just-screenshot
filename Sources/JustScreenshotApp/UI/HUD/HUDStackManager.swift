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
        var onDelete: () -> Void
    }

    private final class Entry {
        let id = UUID()
        let itemID: UUID
        let window: NSWindow
        var timeout: Task<Void, Never>?
        var isHovering = false
        var isOCRActive = false

        init(itemID: UUID, window: NSWindow) {
            self.itemID = itemID
            self.window = window
        }
    }

    static let width: CGFloat = 362
    static let height: CGFloat = 122
    private static let spacing: CGFloat = 10
    private static let margin: CGFloat = 24
    private static let maxVisible = 4
    private static let lifetime: UInt64 = 9_000_000_000
    private static let afterHoverLifetime: UInt64 = 3_000_000_000

    private var entries: [Entry] = [] // новые — первые
    private var activeToastWindow: NSWindow?
    private var toastDismissTask: Task<Void, Never>?

    func show(item: CapturedItem, thumbnail: NSImage? = nil, actions: Actions) {
        guard let screen = ScreenCoordinateSpace.targetScreen(for: NSEvent.mouseLocation) else {
            return
        }

        let window = makeFloatingBorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.height),
            title: JustScreenshotWindowTitles.quickAccessHUD
        )

        let entry = Entry(itemID: item.id, window: window)
        let id = entry.id

        let view = QuickAccessOverlayView(
            item: item,
            thumbnail: thumbnail,
            onAnnotate: { [weak self] in self?.dismiss(id: id); actions.onAnnotate() },
            onSave: { actions.onSave() },
            onCopy: { actions.onCopy() },
            onPin: { [weak self] in self?.dismiss(id: id); actions.onPin() },
            onOCR: { [weak self] completion in
                self?.setOCRRunning(id: id, running: true)
                actions.onOCR { text in
                    self?.setOCRRunning(id: id, running: false)
                    completion(text)
                }
            },
            onDelete: { [weak self] in self?.dismiss(id: id); actions.onDelete() },
            onClose: { [weak self] in self?.dismiss(id: id) },
            onHover: { [weak self] hovering in self?.hoverChanged(id: id, hovering: hovering) }
        )
        window.contentView = FirstMouseHostingView(rootView: view)

        let vf = screen.visibleFrame
        window.setFrame(
            NSRect(x: vf.minX + Self.margin - 40, y: vf.minY + Self.margin, width: Self.width, height: Self.height),
            display: false
        )
        window.orderFrontRegardless()

        entries.insert(entry, at: 0)
        while entries.count > Self.maxVisible, let oldest = entries.last {
            dismiss(id: oldest.id, relayout: false)
        }
        startTimer(entry, nanoseconds: Self.lifetime)
        layout(on: screen)
    }

    func dismiss(id: UUID, relayout: Bool = true) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        let entry = entries.remove(at: idx)
        tearDownEntry(entry)
        if relayout {
            layout()
        }
    }

    func dismiss(itemID: UUID) {
        let matchingIDs = entries.filter { $0.itemID == itemID }.map(\.id)
        guard !matchingIDs.isEmpty else { return }
        for id in matchingIDs {
            dismiss(id: id, relayout: false)
        }
        layout()
    }

    func dismissAll() {
        let toRemove = entries
        entries.removeAll()
        for entry in toRemove {
            tearDownEntry(entry)
        }
        toastDismissTask?.cancel()
        toastDismissTask = nil
        if let toast = activeToastWindow {
            toast.orderOut(nil)
            toast.contentView = nil
            toast.close()
            activeToastWindow = nil
        }
    }

    /// Отображение легкого всплывающего тоста (например, при быстром OCR захвате текста)
    func showToast(text: String, icon: String = "checkmark.circle.fill") {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        if let previous = activeToastWindow {
            previous.orderOut(nil)
            previous.contentView = nil
            previous.close()
            activeToastWindow = nil
        }

        guard let screen = ScreenCoordinateSpace.targetScreen(for: NSEvent.mouseLocation) else { return }
        let vf = screen.visibleFrame

        let toastView = HUDToastView(icon: icon, text: text)
        let hostingView = NSHostingView(rootView: toastView)
        let fittingSize = hostingView.fittingSize
        let toastWidth = max(180, fittingSize.width)
        let toastHeight = max(40, fittingSize.height)

        let window = makeFloatingBorderlessWindow(
            contentRect: NSRect(
                x: vf.midX - toastWidth / 2,
                y: vf.minY + 50,
                width: toastWidth,
                height: toastHeight
            ),
            title: JustScreenshotWindowTitles.hudToast
        )
        window.contentView = hostingView
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            window.animator().alphaValue = 1
        }

        activeToastWindow = window
        toastDismissTask = Task { @MainActor [weak self, weak window] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let window else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                window.animator().alphaValue = 0
            }, completionHandler: { [weak self, weak window] in
                Task { @MainActor [weak self, weak window] in
                    window?.orderOut(nil)
                    window?.contentView = nil
                    window?.close()
                    if self?.activeToastWindow === window {
                        self?.activeToastWindow = nil
                    }
                }
            })
        }
    }

    private func makeFloatingBorderlessWindow(contentRect: NSRect, title: String) -> NSWindow {
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.alphaValue = 0
        return window
    }

    private func tearDownEntry(_ entry: Entry) {
        entry.timeout?.cancel()
        entry.timeout = nil
        entry.window.orderOut(nil)
        entry.window.contentView = nil
        entry.window.close()
    }

    private func hoverChanged(id: UUID, hovering: Bool) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        entry.isHovering = hovering
        if hovering || entry.isOCRActive {
            entry.timeout?.cancel()
            entry.timeout = nil
        } else {
            startTimer(entry, nanoseconds: Self.afterHoverLifetime)
        }
    }

    private func setOCRRunning(id: UUID, running: Bool) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        entry.isOCRActive = running
        if running {
            entry.timeout?.cancel()
            entry.timeout = nil
        } else if !entry.isHovering {
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

    private func layout(on preferredScreen: NSScreen? = nil) {
        guard !entries.isEmpty,
              let screen = preferredScreen ?? ScreenCoordinateSpace.targetScreen(for: NSEvent.mouseLocation) else {
            return
        }
        let vf = screen.visibleFrame
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for (i, entry) in entries.enumerated() {
                let frame = NSRect(
                    x: vf.minX + Self.margin,
                    y: vf.minY + Self.margin + CGFloat(i) * (Self.height + Self.spacing),
                    width: Self.width,
                    height: Self.height
                )
                entry.window.animator().setFrame(frame, display: true)
                entry.window.animator().alphaValue = 1
            }
        }
    }
}

/// NSHostingView, принимающий первый клик мыши без предварительной активации окна
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

/// Плавающий компактный тост обратной связи
private struct HUDToastView: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
        )
    }
}
