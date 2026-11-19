import Foundation
import ScreenCaptureKit
import Cocoa
import os.lock

public enum ScreenCaptureError: LocalizedError {
    case displayNotFound
    case windowNotFound
    case emptySelection

    public var errorDescription: String? {
        switch self {
        case .displayNotFound:
            return "Display not found for capture."
        case .windowNotFound:
            return "Target window not found for capture."
        case .emptySelection:
            return "Selected capture region is empty."
        }
    }
}

/// Сервис захвата экрана через ScreenCaptureKit и CoreGraphics
@MainActor
public final class ScreenCaptureService {
    public static let shared = ScreenCaptureService()

    private struct ContentCacheKey: Hashable, Sendable {
        let excludeDesktop: Bool
        let onScreenOnly: Bool
    }

    private struct ContentCacheEntry: @unchecked Sendable {
        let content: SCShareableContent
        let timestamp: ContinuousClock.Instant
    }

    nonisolated private static let contentCacheTTL: Duration = .milliseconds(200)
    nonisolated private static let contentCacheLock = OSAllocatedUnfairLock<[ContentCacheKey: ContentCacheEntry]>(initialState: [:])

    private init() {}

    /// Проверка наличия разрешения на запись экрана
    public func hasScreenCapturePermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Проверка и запрос разрешений на запись экрана
    @discardableResult
    public func checkAndRequestPermissions() async -> Bool {
        CGRequestScreenCaptureAccess()
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

        NSApp.activate()
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemSettings()
        }
    }

    /// Открывает раздел «Запись экрана» в Системных настройках macOS
    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Захват определенной области экрана
    public func captureRect(_ rect: CGRect, excludingWindowIDs: [CGWindowID] = []) async throws -> NSImage {
        guard rect.width > 0.5, rect.height > 0.5 else {
            throw ScreenCaptureError.emptySelection
        }
        // Короткая пауза, чтобы скрытый оверлей успел уйти из композитинга WindowServer.
        try await Task.sleep(nanoseconds: 16_000_000)

        let appKitRect = ScreenCoordinateSpace.appKitRect(fromQuartz: rect)
        let matchingScreen = ScreenCoordinateSpace.targetScreen(for: appKitRect)
            ?? ScreenCoordinateSpace.targetScreen(for: NSEvent.mouseLocation)
        let scaleHint = matchingScreen?.backingScaleFactor ?? 2.0
        let ids = excludingWindowIDs
        return try await Task.detached(priority: .userInitiated) {
            try await Self.captureRectImage(rect: rect, excludingWindowIDs: ids, scaleHint: scaleHint)
        }.value
    }

    /// Захват экрана целиком через ScreenCaptureKit (сопоставление напрямую по CGDirectDisplayID)
    public func captureScreenWithSCK(screen: NSScreen) async throws -> CGImage {
        let displayID = screen.displayID
        let frame = screen.frame
        let scale = screen.backingScaleFactor
        return try await Task.detached(priority: .userInitiated) {
            try await Self.captureDisplayImage(displayID: displayID, frameSize: frame.size, scale: scale)
        }.value
    }

    /// Захват конкретного окна
    public func captureWindow(windowID: CGWindowID) async throws -> NSImage {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return try await Task.detached(priority: .userInitiated) {
            try await Self.captureWindowImage(windowID: windowID, scale: scale)
        }.value
    }

    /// Получение списка активных окон для hover-подсветки
    public func getVisibleWindows() async throws -> [SCWindow] {
        try await Task.detached(priority: .userInitiated) {
            WindowSnapshot(windows: try await Self.fetchVisibleWindows())
        }.value.windows
    }

    /// Масштаб дисплея в пикселях (Retina backingScaleFactor через CGDisplayCopyDisplayMode)
    nonisolated static func displayScale(for display: SCDisplay?, fallback: CGFloat) -> CGFloat {
        if let display, let mode = CGDisplayCopyDisplayMode(display.displayID), mode.width > 0 {
            let ratio = CGFloat(mode.pixelWidth) / CGFloat(mode.width)
            if ratio >= 1.0 {
                return ratio
            }
        }
        return fallback > 0 ? fallback : 2.0
    }

    nonisolated static func matchingDisplay(in content: SCShareableContent, for quartzRect: CGRect) -> SCDisplay? {
        var bestDisplay: SCDisplay?
        var bestArea: CGFloat = 0
        for display in content.displays {
            let intersection = displayFrame(display).intersection(quartzRect)
            guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { continue }
            let area = intersection.width * intersection.height
            if area > bestArea {
                bestArea = area
                bestDisplay = display
            }
        }
        return bestDisplay ?? content.displays.first
    }

    // MARK: - Background capture

    nonisolated private static func shareableContent(
        excludeDesktopWindows: Bool,
        onScreenWindowsOnly: Bool,
        bypassCache: Bool = false
    ) async throws -> SCShareableContent {
        let key = ContentCacheKey(excludeDesktop: excludeDesktopWindows, onScreenOnly: onScreenWindowsOnly)
        let now = ContinuousClock.now
        if !bypassCache {
            let cachedEntry: ContentCacheEntry? = contentCacheLock.withLock { cache in
                guard let entry = cache[key],
                      now - entry.timestamp < contentCacheTTL else {
                    return nil
                }
                return entry
            }
            if let cachedEntry {
                return cachedEntry.content
            }
        }
        let content = try await SCShareableContent.excludingDesktopWindows(
            excludeDesktopWindows,
            onScreenWindowsOnly: onScreenWindowsOnly
        )
        let newEntry = ContentCacheEntry(content: content, timestamp: ContinuousClock.now)
        contentCacheLock.withLock { cache in
            cache[key] = newEntry
        }
        return content
    }

    nonisolated private static func captureRectImage(
        rect: CGRect,
        excludingWindowIDs: [CGWindowID],
        scaleHint: CGFloat
    ) async throws -> NSImage {
        let content = try await shareableContent(excludeDesktopWindows: true, onScreenWindowsOnly: true, bypassCache: true)

        guard let display = matchingDisplay(in: content, for: rect) else {
            throw ScreenCaptureError.displayNotFound
        }

        let excludedWindows = overlayWindows(in: content, excludingWindowIDs: excludingWindowIDs)
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        let displayScale = displayScale(for: display, fallback: scaleHint)

        let rawLocalRect = CGRect(
            x: rect.origin.x - CGFloat(display.frame.origin.x),
            y: rect.origin.y - CGFloat(display.frame.origin.y),
            width: rect.width,
            height: rect.height
        )
        let displayBounds = CGRect(origin: .zero, size: display.frame.size)
        let clamped = rawLocalRect.intersection(displayBounds)
        let localRect = (!clamped.isNull && clamped.width > 0.5 && clamped.height > 0.5) ? clamped : rawLocalRect

        let targetWidth = max(1, Int(round(localRect.width * displayScale)))
        let targetHeight = max(1, Int(round(localRect.height * displayScale)))

        let config = SCStreamConfiguration()
        config.sourceRect = localRect
        config.width = targetWidth
        config.height = targetHeight
        config.showsCursor = false
        config.scalesToFit = false
        config.colorSpaceName = CGColorSpace.sRGB

        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: cgImage, size: NSSize(width: localRect.width, height: localRect.height))
    }

    nonisolated private static func captureDisplayImage(
        displayID: CGDirectDisplayID,
        frameSize: CGSize,
        scale: CGFloat
    ) async throws -> CGImage {
        let content = try await shareableContent(excludeDesktopWindows: true, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw ScreenCaptureError.displayNotFound
        }

        let displayScale = displayScale(for: display, fallback: scale)
        let excludedWindows = overlayWindows(in: content, excludingWindowIDs: [])
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        let config = SCStreamConfiguration()
        config.width = max(1, Int(round(frameSize.width * displayScale)))
        config.height = max(1, Int(round(frameSize.height * displayScale)))
        config.showsCursor = false
        config.scalesToFit = false
        config.colorSpaceName = CGColorSpace.sRGB

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    nonisolated private static func captureWindowImage(windowID: CGWindowID, scale: CGFloat) async throws -> NSImage {
        let content = try await shareableContent(excludeDesktopWindows: false, onScreenWindowsOnly: true)
        guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
            throw ScreenCaptureError.windowNotFound
        }

        let windowDisplay = matchingDisplay(in: content, for: scWindow.frame)
        let windowScale = displayScale(for: windowDisplay, fallback: scale)

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
