import SwiftUI
import AppKit

/// Плавающий оверлей обратного отсчета перед созданием скриншота
public final class CountdownOverlayWindow: NSWindow {
    
    public init(seconds: Int, centerPoint: CGPoint? = nil, onComplete: @escaping () -> Void) {
        let center: CGPoint
        if let centerPoint {
            center = centerPoint
        } else {
            let screen = NSScreen.main ?? NSScreen.screens[0]
            center = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
        }
        let size: CGFloat = 84
        let rect = NSRect(
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
        
        super.init(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.title = JustScreenshotWindowTitles.countdownOverlay
        self.level = .floating
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isReleasedWhenClosed = false
        
        let hostingView = NSHostingView(
            rootView: CountdownView(initialSeconds: seconds, onComplete: onComplete)
        )
        self.contentView = hostingView
    }
}

private struct CountdownView: View {
    let initialSeconds: Int
    let onComplete: () -> Void
    
    @State private var remaining: Int
    @State private var scale: CGFloat = 1.2
    
    init(initialSeconds: Int, onComplete: @escaping () -> Void) {
        self.initialSeconds = initialSeconds
        self.onComplete = onComplete
        self._remaining = State(initialValue: initialSeconds)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
            
            // Круговой прогресс
            Circle()
                .trim(from: 0, to: CGFloat(remaining) / CGFloat(max(1, initialSeconds)))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(4)
                .animation(.easeInOut(duration: 0.3), value: remaining)
            
            Text("\(remaining)")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .scaleEffect(scale)
        }
        .frame(width: 80, height: 80)
        .task {
            animateTick()
            for _ in 1..<initialSeconds {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remaining -= 1
                animateTick()
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            onComplete()
        }
    }
    
    private func animateTick() {
        NSSound(named: "Tink")?.play()
        scale = 1.25
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 1.0
        }
    }
}
