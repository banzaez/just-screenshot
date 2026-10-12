import SwiftUI
import AppKit

/// Плавающий оверлей обратного отсчета перед созданием скриншота
public final class CountdownOverlayWindow: NSWindow {
    
    public init(seconds: Int, onComplete: @escaping () -> Void) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let rect = NSRect(
            x: screen.frame.midX - 70,
            y: screen.frame.midY - 70,
            width: 140,
            height: 140
        )
        
        super.init(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let hostingView = NSHostingView(
            rootView: CountdownView(initialSeconds: seconds, onComplete: { [weak self] in
                self?.orderOut(nil)
                self?.close()
                onComplete()
            })
        )
        self.contentView = hostingView
    }
}

private struct CountdownView: View {
    let initialSeconds: Int
    let onComplete: () -> Void
    
    @State private var remaining: Int
    @State private var scale: CGFloat = 1.3
    
    init(initialSeconds: Int, onComplete: @escaping () -> Void) {
        self.initialSeconds = initialSeconds
        self.onComplete = onComplete
        self._remaining = State(initialValue: initialSeconds)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.75))
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                .shadow(color: .black.opacity(0.4), radius: 10)
            
            Text("\(remaining)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .scaleEffect(scale)
        }
        .frame(width: 130, height: 130)
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
        scale = 1.3
        withAnimation(.easeOut(duration: 0.35)) {
            scale = 1.0
        }
    }
}
