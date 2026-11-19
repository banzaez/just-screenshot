import AppKit

/// Конвертация между AppKit (origin снизу) и Quartz/ScreenCaptureKit (origin сверху) + поиск целевого экрана
@MainActor
enum ScreenCoordinateSpace {
    /// Высота «главного» дисплея (origin == .zero) — база для Quartz Y
    static var primaryDisplayHeight: CGFloat {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? NSScreen.screens.first?.frame.height
            ?? 900
    }

    /// Целевой экран для прямоугольника (с максимальной площадью пересечения)
    static func targetScreen(for rect: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return NSScreen.main }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let containing = screens.first(where: { $0.frame.contains(center) }) {
            return containing
        }
        var bestScreen: NSScreen?
        var bestArea: CGFloat = 0
        for screen in screens {
            let intersection = screen.frame.intersection(rect)
            guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { continue }
            let area = intersection.width * intersection.height
            if area > bestArea {
                bestArea = area
                bestScreen = screen
            }
        }
        return bestScreen ?? NSScreen.main ?? screens.first
    }

    /// Целевой экран для точки (например, позиции курсора)
    static func targetScreen(for point: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        return screens.first(where: { NSMouseInRect(point, $0.frame, false) })
            ?? NSScreen.main
            ?? screens.first
    }

    /// Quartz CGRect → AppKit global CGRect
    static func appKitRect(fromQuartz rect: CGRect, primaryHeight: CGFloat? = nil) -> CGRect {
        let h = primaryHeight ?? primaryDisplayHeight
        return CGRect(
            x: rect.origin.x,
            y: h - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// AppKit global CGRect → Quartz CGRect
    static func quartzRect(fromAppKit rect: CGRect, primaryHeight: CGFloat? = nil) -> CGRect {
        let h = primaryHeight ?? primaryDisplayHeight
        return CGRect(
            x: rect.origin.x,
            y: h - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Точка в системе экрана (AppKit, относительно screen.frame) → Quartz global
    static func quartzPoint(
        fromScreenLocal point: CGPoint,
        screenFrame: CGRect,
        primaryHeight: CGFloat? = nil
    ) -> CGPoint {
        let h = primaryHeight ?? primaryDisplayHeight
        let globalAppKitX = screenFrame.origin.x + point.x
        let globalAppKitY = screenFrame.origin.y + point.y
        return CGPoint(x: globalAppKitX, y: h - globalAppKitY)
    }

    /// Rect в системе экрана (AppKit) → Quartz global
    static func quartzRect(
        fromScreenLocal rect: CGRect,
        screenFrame: CGRect,
        primaryHeight: CGFloat? = nil
    ) -> CGRect {
        let h = primaryHeight ?? primaryDisplayHeight
        let globalAppKitX = screenFrame.origin.x + rect.origin.x
        let globalAppKitY = screenFrame.origin.y + rect.origin.y
        return CGRect(
            x: globalAppKitX,
            y: h - globalAppKitY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Quartz window frame → rect в координатах view оверлея (screen-local AppKit)
    static func screenLocalRect(
        fromQuartzFrame quartzFrame: CGRect,
        screenFrame: CGRect,
        primaryHeight: CGFloat? = nil
    ) -> CGRect {
        let h = primaryHeight ?? primaryDisplayHeight
        let globalAppKitY = h - quartzFrame.origin.y - quartzFrame.height
        return CGRect(
            x: quartzFrame.origin.x - screenFrame.origin.x,
            y: globalAppKitY - screenFrame.origin.y,
            width: quartzFrame.width,
            height: quartzFrame.height
        )
    }
}
