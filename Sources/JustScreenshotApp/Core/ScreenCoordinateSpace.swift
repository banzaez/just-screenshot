import AppKit

/// Конвертация между AppKit (origin снизу) и Quartz/ScreenCaptureKit (origin сверху)
enum ScreenCoordinateSpace {
    /// Высота «главного» дисплея (origin == .zero) — база для Quartz Y
    static var primaryDisplayHeight: CGFloat {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? 900
    }
    
    /// Quartz CGRect → AppKit global CGRect
    static func appKitRect(fromQuartz rect: CGRect, primaryHeight: CGFloat = primaryDisplayHeight) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
    
    /// Точка в системе экрана (AppKit, относительно screen.frame) → Quartz global
    static func quartzPoint(
        fromScreenLocal point: CGPoint,
        screenFrame: CGRect,
        primaryHeight: CGFloat = primaryDisplayHeight
    ) -> CGPoint {
        let globalAppKit = CGPoint(
            x: screenFrame.origin.x + point.x,
            y: screenFrame.origin.y + point.y
        )
        return CGPoint(x: globalAppKit.x, y: primaryHeight - globalAppKit.y)
    }
    
    /// Rect в системе экрана (AppKit) → Quartz global
    static func quartzRect(
        fromScreenLocal rect: CGRect,
        screenFrame: CGRect,
        primaryHeight: CGFloat = primaryDisplayHeight
    ) -> CGRect {
        let globalAppKitX = screenFrame.origin.x + rect.origin.x
        let globalAppKitY = screenFrame.origin.y + rect.origin.y
        return CGRect(
            x: globalAppKitX,
            y: primaryHeight - globalAppKitY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
    
    /// Quartz window frame → rect в координатах view оверлея (screen-local AppKit)
    static func screenLocalRect(
        fromQuartzFrame quartzFrame: CGRect,
        screenFrame: CGRect,
        primaryHeight: CGFloat = primaryDisplayHeight
    ) -> CGRect {
        let globalAppKitY = primaryHeight - quartzFrame.origin.y - quartzFrame.height
        return CGRect(
            x: quartzFrame.origin.x - screenFrame.origin.x,
            y: globalAppKitY - screenFrame.origin.y,
            width: quartzFrame.width,
            height: quartzFrame.height
        )
    }
}
