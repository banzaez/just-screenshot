import Foundation
import ScreenCaptureKit
import Cocoa
import os.lock

/// Сервис захвата экрана через ScreenCaptureKit и CoreGraphics
@MainActor
public final class ScreenCaptureService {
    public static let shared = ScreenCaptureService()
    
    private struct ContentCacheEntry: @unchecked Sendable {
        let excludeDesktop: Bool
        let onScreenOnly: Bool
        let content: SCShareableContent
        let date: Date
    }
    
    nonisolated private static let contentCacheTTL: TimeInterval = 0.2
    nonisolated private static let contentCacheLock = OSAllocatedUnfairLock<ContentCacheEntry?>(initialState: nil)
    
    private init() {}
    
    /// Проверка наличия разрешения на запись экрана
    public func hasScreenCapturePermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
    
    /// Проверка и запрос разрешений на запись экрана
    @discardableResult
    public func checkAndRequestPermissions() async -> Bool {
        if #available(macOS 14.4, *) {
            return CGRequestScreenCaptureAccess()
        } else {
            return CGPreflightScreenCaptureAccess()
        }
    }
    
    /// Гарантирует наличие разрешения перед началом скриншота или записи
    public func ensurePermission() async -> Bool {
        if hasScreenCapturePermission() {
            return true
        }
        
        let granted = await checkAndRequestPermissions()
        if granted {
            return true
        }
        
        showPermissionAlert()
        return false
    }
    
    /// Показ диалога с переходом в системные настройки
    public func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = L("alert.permission_title")
        alert.informativeText = L("alert.permission_informative")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("alert.open_settings"))
        alert.addButton(withTitle: L("alert.cancel"))
        
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    /// Захват определенной области экрана
    public func captureRect(_ rect: CGRect, excludingWindowIDs: [CGWindowID] = []) async throws -> NSImage {
        // Короткая пауза, чтобы скрытый оверлей успел уйти из композитинга WindowServer.
        try? await Task.sleep(nanoseconds: 16_000_000)
        
        let appKitRect = ScreenCoordinateSpace.appKitRect(fromQuartz: rect)
        let matchingScreen = NSScreen.screens.first(where: { $0.frame.intersects(appKitRect) })
            ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
        let scaleHint = matchingScreen?.backingScaleFactor ?? 2.0
        let ids = excludingWindowIDs
        return try await Task.detached(priority: .userInitiated) {
            try await Self.captureRectImage(rect: rect, excludingWindowIDs: ids, scaleHint: scaleHint)
        }.value
    }
    
    /// Захват экрана целиком через ScreenCaptureKit.
    public func captureScreenWithSCK(screen: NSScreen) async throws -> CGImage {
        let frame = screen.frame
        let scale = screen.backingScaleFactor
        return try await Task.detached(priority: .userInitiated) {
            try await Self.captureDisplayImage(frame: frame, scale: scale)
        }.value
    }
    
    /// Захват конкретного окна
    public func captureWindow(windowID: CGWindowID) async throws -> NSImage {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return try await Task.detached(priority: .userInitiated) {
            try await Self.captureWindowImage(windowID: windowID, scale: scale)
        }.value
    }
    
    /// Получение списка активных окон для hover-подсветки.
    public func getVisibleWindows() async throws -> [SCWindow] {
        try await Task.detached(priority: .userInitiated) {
            WindowSnapshot(windows: try await Self.fetchVisibleWindows())
        }.value.windows
    }
    
    // MARK: - Background capture
    
    nonisolated private static func shareableContent(
        excludeDesktopWindows: Bool,
        onScreenWindowsOnly: Bool
    ) async throws -> SCShareableContent {
        let cachedEntry: ContentCacheEntry? = contentCacheLock.withLock { entry in
            guard let entry,
                  entry.excludeDesktop == excludeDesktopWindows,
                  entry.onScreenOnly == onScreenWindowsOnly,
                  Date().timeIntervalSince(entry.date) < contentCacheTTL else {
                return nil
            }
            return entry
        }
        if let cachedEntry {
            return cachedEntry.content
        }
        let content = try await SCShareableContent.excludingDesktopWindows(
            excludeDesktopWindows,
            onScreenWindowsOnly: onScreenWindowsOnly
        )
        let newEntry = ContentCacheEntry(
            excludeDesktop: excludeDesktopWindows,
            onScreenOnly: onScreenWindowsOnly,
            content: content,
            date: Date()
        )
        contentCacheLock.withLock { entry in
            entry = newEntry
        }
        return content
    }
    
    nonisolated private static func captureRectImage(
        rect: CGRect,
        excludingWindowIDs: [CGWindowID],
        scaleHint: CGFloat
    ) async throws -> NSImage {
        let content = try await shareableContent(excludeDesktopWindows: true, onScreenWindowsOnly: true)
        
        guard let display = content.displays.first(where: { disp in
            displayFrame(disp).intersects(rect)
        }) ?? content.displays.first else {
            throw NSError(domain: "ScreenCaptureService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Экран не найден"])
        }
        
        let excludedWindows = overlayWindows(in: content, excludingWindowIDs: excludingWindowIDs)
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        
        // Определение реального масштаба рендеринга (Retina backingScale / CGDisplayMode)
        let displayScale: CGFloat = {
            if let mode = CGDisplayCopyDisplayMode(display.displayID), mode.width > 0 {
                let ratio = CGFloat(mode.pixelWidth) / CGFloat(mode.width)
                if ratio >= 1.0 {
                    return ratio
                }
            }
            return scaleHint > 0 ? scaleHint : 2.0
        }()
        
        let localRect = CGRect(
            x: rect.origin.x - CGFloat(display.frame.origin.x),
            y: rect.origin.y - CGFloat(display.frame.origin.y),
            width: rect.width,
            height: rect.height
        )
        
        let targetWidth = max(1, Int(round(rect.width * displayScale)))
        let targetHeight = max(1, Int(round(rect.height * displayScale)))
        
        let config = SCStreamConfiguration()
        config.sourceRect = localRect
        config.width = targetWidth
        config.height = targetHeight
        config.showsCursor = false
        config.scalesToFit = false
        config.colorSpaceName = CGColorSpace.sRGB
        
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: cgImage, size: NSSize(width: rect.width, height: rect.height))
    }
    
    nonisolated private static func captureDisplayImage(frame: CGRect, scale: CGFloat) async throws -> CGImage {
        let content = try await shareableContent(excludeDesktopWindows: true, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { disp in
            displayFrame(disp).intersects(frame)
        }) ?? content.displays.first else {
            throw NSError(domain: "ScreenCaptureService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Дисплей не найден"])
        }
        
        let displayScale: CGFloat = {
            if let mode = CGDisplayCopyDisplayMode(display.displayID), mode.width > 0 {
                let ratio = CGFloat(mode.pixelWidth) / CGFloat(mode.width)
                if ratio >= 1.0 { return ratio }
            }
            return scale > 0 ? scale : 2.0
        }()
        
        let excludedWindows = overlayWindows(in: content, excludingWindowIDs: [])
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        let config = SCStreamConfiguration()
        config.width = max(1, Int(round(frame.width * displayScale)))
        config.height = max(1, Int(round(frame.height * displayScale)))
        config.showsCursor = false
        config.scalesToFit = false
        config.colorSpaceName = CGColorSpace.sRGB
        
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
    
    nonisolated private static func captureWindowImage(windowID: CGWindowID, scale: CGFloat) async throws -> NSImage {
        let content = try await shareableContent(excludeDesktopWindows: false, onScreenWindowsOnly: true)
        guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
            throw NSError(domain: "ScreenCaptureService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Окно не найдено"])
        }
        
        let windowDisplay = content.displays.first(where: { displayFrame($0).intersects(scWindow.frame) }) ?? content.displays.first
        let windowScale: CGFloat = {
            if let disp = windowDisplay, let mode = CGDisplayCopyDisplayMode(disp.displayID), mode.width > 0 {
                let ratio = CGFloat(mode.pixelWidth) / CGFloat(mode.width)
                if ratio >= 1.0 { return ratio }
            }
            return scale > 0 ? scale : 2.0
        }()
        
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = SCStreamConfiguration()
        config.width = max(1, Int(round(scWindow.frame.width * windowScale)))
        config.height = max(1, Int(round(scWindow.frame.height * windowScale)))
        config.showsCursor = false
        config.colorSpaceName = CGColorSpace.sRGB
        
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: cgImage, size: NSSize(width: scWindow.frame.width, height: scWindow.frame.height))
    }
    
    nonisolated private static func fetchVisibleWindows() async throws -> [SCWindow] {
        let content = try await shareableContent(excludeDesktopWindows: true, onScreenWindowsOnly: true)
        let currentPID = ProcessInfo.processInfo.processIdentifier
        return content.windows.filter { win in
            if JustScreenshotWindowTitles.shouldExcludeFromCapture(win, currentPID: currentPID) {
                return false
            }
            guard win.frame.width > 50 && win.frame.height > 50 else { return false }
            guard let title = win.title, !title.isEmpty else {
                return win.owningApplication != nil
            }
            return true
        }
    }
    
    nonisolated private static func overlayWindows(
        in content: SCShareableContent,
        excludingWindowIDs: [CGWindowID]
    ) -> [SCWindow] {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        return content.windows.filter { window in
            if excludingWindowIDs.contains(CGWindowID(window.windowID)) {
                return true
            }
            return JustScreenshotWindowTitles.shouldExcludeFromCapture(window, currentPID: currentPID)
        }
    }
    
    nonisolated private static func displayFrame(_ display: SCDisplay) -> CGRect {
        CGRect(
            x: CGFloat(display.frame.origin.x),
            y: CGFloat(display.frame.origin.y),
            width: CGFloat(display.frame.width),
            height: CGFloat(display.frame.height)
        )
    }
}

/// SCWindow не помечен Sendable, но это неизменяемый снимок списка окон.
private struct WindowSnapshot: @unchecked Sendable {
    let windows: [SCWindow]
}
