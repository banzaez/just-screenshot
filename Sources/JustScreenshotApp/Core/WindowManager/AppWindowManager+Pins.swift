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
            onEdit: { [weak self] in self?.openAnnotationEditor(item: CapturedItem(image: image, rect: .zero)) },
            onToggleClickThrough: { [weak self] isLocked in self?.setPinClickThrough(id: pinID, isLocked: isLocked) }
        ))
        
        let managed = ManagedWindow(window: window) { [weak self] closed in
            self?.closePin(id: pinID)
        }
        pins[pinID] = managed
        window.orderFrontRegardless()
    }
    
    public func setPinClickThrough(id: UUID, isLocked: Bool) {
        guard let managed = pins[id] else { return }
        managed.window.ignoresMouseEvents = isLocked
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
            pins[id]?.window.ignoresMouseEvents = false
        }
        lockedPinIDs.removeAll()
        removePinOptionMonitors()
        hasLockedPins = false
    }
    
    func closePin(id: UUID) {
        lockedPinIDs.remove(id)
        if lockedPinIDs.isEmpty {
            removePinOptionMonitors()
        }
        hasLockedPins = !lockedPinIDs.isEmpty
        guard let managed = pins.removeValue(forKey: id) else { return }
        managed.closeSilently()
    }
    
    private func ensurePinOptionMonitors() {
        guard pinOptionGlobalMonitor == nil else { return }
        
        let handleFlagsChanged: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            let isOptionPressed = event.modifierFlags.contains(.option)
            if Thread.isMainThread {
                for id in self.lockedPinIDs {
                    self.pins[id]?.window.ignoresMouseEvents = !isOptionPressed
                }
            } else {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    for id in self.lockedPinIDs {
                        self.pins[id]?.window.ignoresMouseEvents = !isOptionPressed
                    }
                }
            }
        }
        
        pinOptionGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handleFlagsChanged)
        pinOptionLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handleFlagsChanged(event)
            return event
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
    }
}
