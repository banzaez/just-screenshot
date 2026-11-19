import AppKit
import SwiftUI

extension AppWindowManager {
    // MARK: - Закрепление поверх окон (Pins)

    public func pin(image: NSImage, id: UUID) {
        guard image.size.width > 0, image.size.height > 0 else { return }

        if let existing = pins.first(where: { $0.value.sourceItemID == id }) {
            existing.value.managed.bringToFront()
            return
        }

        let pinID = UUID()
        let state = PinState()
        let visible = ScreenCoordinateSpace.targetScreen(for: NSEvent.mouseLocation)?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
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
            state: state,
            onClose: { [weak self] in self?.closePin(id: pinID) },
            onEdit: { [weak self] in self?.openAnnotationEditor(item: CapturedItem(id: id, image: image, rect: .zero)) },
            onToggleClickThrough: { [weak self] isLocked in self?.setPinClickThrough(id: pinID, isLocked: isLocked) }
        ))

        let managed = ManagedWindow(window: window) { [weak self] _ in
            self?.removePinMetadata(id: pinID)
        }
        pins[pinID] = PinRecord(managed: managed, state: state, sourceItemID: id)
        window.orderFrontRegardless()
    }

    public func setPinClickThrough(id: UUID, isLocked: Bool) {
        guard let record = pins[id] else { return }
        record.state.isClickThrough = isLocked
        record.managed.window.ignoresMouseEvents = isLocked
        if isLocked {
            lockedPinIDs.insert(id)
            ensurePinOptionMonitors()
        } else {
            lockedPinIDs.remove(id)
            if lockedPinIDs.isEmpty {
                removePinOptionMonitors()
            }
        }
        hasLockedPins = !lockedPinIDs.isEmpty
    }

    public func unlockAllPins() {
        for id in lockedPinIDs {
            if let record = pins[id] {
                record.state.isClickThrough = false
                record.managed.window.ignoresMouseEvents = false
            }
        }
        lockedPinIDs.removeAll()
        removePinOptionMonitors()
        hasLockedPins = false
    }

    func closePin(id: UUID) {
        removePinMetadata(id: id)
        guard let record = pins.removeValue(forKey: id) else { return }
        record.managed.closeSilently()
    }

    func closePinsForItem(id: UUID) {
        let matchingIDs = pins.filter { $0.value.sourceItemID == id }.map(\.key)
        for pinID in matchingIDs {
            closePin(id: pinID)
        }
    }

    private func removePinMetadata(id: UUID) {
        lockedPinIDs.remove(id)
        pins.removeValue(forKey: id)
        if lockedPinIDs.isEmpty {
            removePinOptionMonitors()
        }
        hasLockedPins = !lockedPinIDs.isEmpty
    }

    private func ensurePinOptionMonitors() {
        guard pinOptionLocalMonitor == nil else { return }

        let handleFlagsChanged: @MainActor (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            let isOptionPressed = event.modifierFlags.contains(.option)
            for id in self.lockedPinIDs {
                self.pins[id]?.managed.window.ignoresMouseEvents = !isOptionPressed
            }
        }

        if pinOptionGlobalMonitor == nil {
            pinOptionGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
                Task { @MainActor in
                    handleFlagsChanged(event)
                }
            }
        }
        pinOptionLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            MainActor.assumeIsolated {
                handleFlagsChanged(event)
            }
            return event
        }

        if pinResignActiveObserver == nil {
            pinResignActiveObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    for id in self.lockedPinIDs {
                        self.pins[id]?.managed.window.ignoresMouseEvents = true
                    }
                }
            }
        }
    }

    private func removePinOptionMonitors() {
        if let gMon = pinOptionGlobalMonitor {
            NSEvent.removeMonitor(gMon)
            pinOptionGlobalMonitor = nil
        }
        if let lMon = pinOptionLocalMonitor {
            NSEvent.removeMonitor(lMon)
            pinOptionLocalMonitor = nil
        }
        if let obs = pinResignActiveObserver {
            NotificationCenter.default.removeObserver(obs)
            pinResignActiveObserver = nil
        }
    }
}
