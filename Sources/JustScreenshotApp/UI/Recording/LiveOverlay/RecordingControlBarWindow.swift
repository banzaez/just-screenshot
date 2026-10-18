import Cocoa
import SwiftUI

/// Плавающее окно с контроллером записи (таймер, пауза, стоп, отмена)
public final class RecordingControlBarWindow: NSWindow {
    public init(
        initialPosition: CGPoint,
        windowManager: AppWindowManager,
        onPauseResume: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        let size = CGSize(width: 280, height: 50)
        let rect = NSRect(
            x: initialPosition.x - size.width / 2,
            y: initialPosition.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        
        super.init(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.title = JustScreenshotWindowTitles.recordingBar
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.animationBehavior = .none
        
        let barView = RecordingControlBarView(
            windowManager: windowManager,
            onPauseResume: onPauseResume,
            onStop: onStop,
            onCancel: onCancel
        )
        
        self.contentView = NSHostingView(rootView: barView)
    }
}
