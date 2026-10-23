import Cocoa
import SwiftUI

/// Плавающее окно с контроллером записи (настройки, запуск, таймер, пауза, стоп, отмена)
public final class RecordingControlBarWindow: NSWindow {
    private var isRecordingMode = false
    
    public init(
        initialPosition: CGPoint,
        windowManager: AppWindowManager,
        onStartRecording: @escaping () -> Void = {},
        onSelectPreset: @escaping (CGRect) -> Void = { _ in },
        onRequestNewArea: @escaping () -> Void = {},
        onToggleDimming: @escaping () -> Void = {},
        onPauseResume: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        let isRec = windowManager.isRecording
        self.isRecordingMode = isRec
        let size = isRec ? CGSize(width: 350, height: 56) : CGSize(width: 680, height: 56)
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
            onStartRecording: onStartRecording,
            onSelectPreset: onSelectPreset,
            onRequestNewArea: onRequestNewArea,
            onToggleDimming: onToggleDimming,
            onPauseResume: onPauseResume,
            onStop: onStop,
            onCancel: onCancel
        )
        
        self.contentView = NSHostingView(rootView: barView)
    }
    
    public func updateForRecordingMode() {
        guard !isRecordingMode else { return }
        isRecordingMode = true
        animateToSize(CGSize(width: 350, height: 56))
    }
    
    public func updateForSetupMode() {
        guard isRecordingMode else { return }
        isRecordingMode = false
        animateToSize(CGSize(width: 680, height: 56))
    }
    
    public func updatePosition(center: NSPoint) {
        let size = frame.size
        let newOrigin = NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        setFrameOrigin(newOrigin)
    }
    
    private func animateToSize(_ newSize: CGSize) {
        let currentCenter = NSPoint(x: frame.midX, y: frame.midY)
        let newRect = NSRect(
            x: currentCenter.x - newSize.width / 2,
            y: currentCenter.y - newSize.height / 2,
            width: newSize.width,
            height: newSize.height
        )
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newRect, display: true)
        }
    }
}
