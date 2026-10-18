import Foundation
import ScreenCaptureKit
import Cocoa

/// Сервис захвата экрана через ScreenCaptureKit и CoreGraphics
@MainActor
public final class ScreenCaptureService {
    public static let shared = ScreenCaptureService()
    
    nonisolated private static let contentCacheTTL: TimeInterval = 0.2
    nonisolated(unsafe) private static var contentCache: (excludeDesktop: Bool, onScreenOnly: Bool, content: SCShareableContent, date: Date)?
    
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
        
        let scaleHint = NSScreen.main?.backingScaleFactor ?? 2.0
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
        if let cache = contentCache,
           cache.excludeDesktop == excludeDesktopWindows,
           cache.onScreenOnly == onScreenWindowsOnly,
           Date().timeIntervalSince(cache.date) < contentCacheTTL {
            return cache.content
        }
        let content = try await SCShareableContent.excludingDesktopWindows(
            excludeDesktopWindows,
            onScreenWindowsOnly: onScreenWindowsOnly
        )
        contentCache = (excludeDesktopWindows, onScreenWindowsOnly, content, Date())
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
        
        let displayScale: CGFloat = display.frame.width > 0
            ? CGFloat(display.width) / CGFloat(display.frame.width)
            : scaleHint
        
        let localRect = CGRect(
            x: rect.origin.x - CGFloat(display.frame.origin.x),
            y: rect.origin.y - CGFloat(display.frame.origin.y),
            width: rect.width,
            height: rect.height
        )
        
        let config = SCStreamConfiguration()
        config.sourceRect = localRect
        config.width = Int(rect.width * displayScale)
        config.height = Int(rect.height * displayScale)
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
        
        let excludedWindows = overlayWindows(in: content, excludingWindowIDs: [])
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        let config = SCStreamConfiguration()
        config.width = Int(frame.width * scale)
        config.height = Int(frame.height * scale)
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
        
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = SCStreamConfiguration()
        config.width = Int(scWindow.frame.width * scale)
        config.height = Int(scWindow.frame.height * scale)
        config.showsCursor = false
        config.colorSpaceName = CGColorSpace.sRGB
        
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: cgImage, size: NSSize(width: scWindow.frame.width, height: scWindow.frame.height))
    }
    
    nonisolated private static func fetchVisibleWindows() async throws -> [SCWindow] {
        let content = try await shareableContent(excludeDesktopWindows: true, onScreenWindowsOnly: true)
        let currentPID = ProcessInfo.processInfo.processIdentifier
        return content.windows.filter { win in
            if win.owningApplication?.processID == currentPID {
                if JustScreenshotWindowTitles.isOverlayTitle(win.title) ||
                   win.windowLayer >= 1000 {
                    return false
                }
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
            if window.owningApplication?.processID == currentPID {
                if JustScreenshotWindowTitles.isOverlayTitle(window.title) ||
                   window.windowLayer >= 1000 {
                    return true
                }
            }
            return false
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
