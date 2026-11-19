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
        let initialSize = isRec ? CGSize(width: 340, height: 52) : CGSize(width: 560, height: 52)
        let rect = NSRect(
            x: initialPosition.x - initialSize.width / 2,
            y: initialPosition.y - initialSize.height / 2,
            width: initialSize.width,
            height: initialSize.height
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

        let hosting = NSHostingView(rootView: barView)
        self.contentView = hosting
        resizeToFitContent(center: initialPosition, animated: false)
    }

    public func updateForRecordingMode() {
        guard !isRecordingMode else { return }
        isRecordingMode = true
        Task { @MainActor [weak self] in
            // Даем SwiftUI один цикл для переключения дерева на activeRecordingBar
            self?.resizeToFitContent(center: nil, animated: true)
        }
    }

    public func updatePosition(center: NSPoint) {
        let size = frame.size
        let newOrigin = NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        setFrameOrigin(newOrigin)
    }

    private func resizeToFitContent(center: NSPoint?, animated: Bool) {
        contentView?.layoutSubtreeIfNeeded()
        let fitting = contentView?.fittingSize ?? CGSize(width: isRecordingMode ? 340 : 560, height: 52)
        let fallbackWidth: CGFloat = isRecordingMode ? 320 : 500
        let rawWidth = fitting.width > 0 ? ceil(fitting.width) : fallbackWidth
        let rawHeight = max(52, fitting.height > 0 ? ceil(fitting.height) : 52)

        let targetCenter = center ?? NSPoint(x: frame.midX, y: frame.midY)
        let visibleFrame = ScreenCoordinateSpace.targetScreen(for: targetCenter)?.visibleFrame
            ?? ScreenCoordinateSpace.targetScreen(for: frame)?.visibleFrame
        let clampedWidth = visibleFrame.map { min(rawWidth, max(280, $0.width - 24)) } ?? rawWidth
        let newSize = CGSize(width: clampedWidth, height: rawHeight)

        var originX = targetCenter.x - newSize.width / 2
        var originY = targetCenter.y - newSize.height / 2
        if let visibleFrame {
            originX = min(max(visibleFrame.minX + 12, originX), max(visibleFrame.minX + 12, visibleFrame.maxX - newSize.width - 12))
            originY = min(max(visibleFrame.minY + 12, originY), max(visibleFrame.minY + 12, visibleFrame.maxY - newSize.height - 12))
        }

        let newRect = NSRect(origin: CGPoint(x: originX, y: originY), size: newSize)
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(newRect, display: true)
            }
        } else {
            setFrame(newRect, display: true)
        }
    }
}
