import SwiftUI
import AVKit

/// Кастомное представление AVPlayerView для macOS, не перехватывающее клики за пределами области просмотра
public struct VideoPlayerRepresentable: NSViewRepresentable {
    public let player: AVPlayer
    
    public init(player: AVPlayer) {
        self.player = player
    }
    
    public func makeNSView(context: Context) -> AVPlayerView {
        let view = NonInteractivePlayerView()
        view.player = player
        view.controlsStyle = .none // Мы используем собственный стильный таймлайн и контролы
        view.showsFullScreenToggleButton = false
        return view
    }
    
    public func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }

    public static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player = nil
    }
}

private final class NonInteractivePlayerView: AVPlayerView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
