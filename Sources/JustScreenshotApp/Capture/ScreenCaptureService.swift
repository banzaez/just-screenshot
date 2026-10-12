import Foundation
import ScreenCaptureKit
import Cocoa

/// Сервис захвата экрана через ScreenCaptureKit и CoreGraphics
@MainActor
public final class ScreenCaptureService {
    public static let shared = ScreenCaptureService()
    
    private init() {}
    
    /// Проверка наличия разрешения на запись экрана
    public func hasScreenCapturePermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
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
        
        // Показываем диалог с предложением открыть системные настройки
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
        // Минимальная пауза 35 мс для завершения анимации/скрытия и синхронизации буфера WindowServer
        try? await Task.sleep(nanoseconds: 35_000_000)
        
        // Проверяем доступный контент через ScreenCaptureKit
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        
        guard let display = content.displays.first(where: { disp in
            let dispRect = CGRect(x: CGFloat(disp.frame.origin.x),
                                  y: CGFloat(disp.frame.origin.y),
                                  width: CGFloat(disp.frame.width),
                                  height: CGFloat(disp.frame.height))
            return dispRect.intersects(rect)
        }) ?? content.displays.first else {
            throw NSError(domain: "ScreenCaptureService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Экран не найден"])
        }
        
        // Фильтр исключения окон: переданные ID и любые оверлеи текущего приложения
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let excludedWindows = content.windows.filter { window in
            if excludingWindowIDs.contains(CGWindowID(window.windowID)) {
                return true
            }
            if window.owningApplication?.processID == currentPID {
                if window.title == "JustScreenshotAreaOverlay" ||
                   window.title == "JustScreenshotCountdownOverlay" ||
                   window.windowLayer >= 1000 {
                    return true
                }
            }
            return false
        }
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        
        // Вычисляем точный масштаб отображения для целевого монитора
        let displayScale: CGFloat = display.frame.width > 0 ? CGFloat(display.width) / CGFloat(display.frame.width) : (NSScreen.main?.backingScaleFactor ?? 2.0)
        
        // Приводим rect к локальной системе координат выбранного монитора
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
        let size = NSSize(width: rect.width, height: rect.height)
        let nsImage = NSImage(cgImage: cgImage, size: size)
        return nsImage
    }
    
    /// Захват экрана целиком через современный ScreenCaptureKit (SCScreenshotManager)
    public func captureScreenWithSCK(screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { disp in
            let frame = CGRect(x: CGFloat(disp.frame.origin.x),
                                y: CGFloat(disp.frame.origin.y),
                                width: CGFloat(disp.frame.width),
                                height: CGFloat(disp.frame.height))
            return frame.intersects(screen.frame)
        }) ?? content.displays.first else {
            throw NSError(domain: "ScreenCaptureService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Дисплей не найден"])
        }
        
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let excludedWindows = content.windows.filter { window in
            if window.owningApplication?.processID == currentPID {
                if window.title == "JustScreenshotAreaOverlay" ||
                   window.title == "JustScreenshotCountdownOverlay" ||
                   window.windowLayer >= 1000 {
                    return true
                }
            }
            return false
        }
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        let config = SCStreamConfiguration()
        config.width = Int(screen.frame.width * screen.backingScaleFactor)
        config.height = Int(screen.frame.height * screen.backingScaleFactor)
        config.showsCursor = false
        config.scalesToFit = false
        config.colorSpaceName = CGColorSpace.sRGB
        
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
    
    /// Захват конкретного окна
    public func captureWindow(windowID: CGWindowID) async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
            throw NSError(domain: "ScreenCaptureService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Окно не найдено"])
        }
        
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = SCStreamConfiguration()
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        config.width = Int(scWindow.frame.width * scale)
        config.height = Int(scWindow.frame.height * scale)
        config.showsCursor = false
        config.colorSpaceName = CGColorSpace.sRGB
        
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: cgImage, size: NSSize(width: scWindow.frame.width, height: scWindow.frame.height))
    }
    
    /// Получение списка активных окон для hover-подсветки
    public func getVisibleWindows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        return content.windows.filter { win in
            guard win.frame.width > 50 && win.frame.height > 50 else { return false }
            guard let title = win.title, !title.isEmpty else {
                // Если заголовка нет, проверяем имя приложения
                return win.owningApplication != nil
            }
            return true
        }
    }
}
