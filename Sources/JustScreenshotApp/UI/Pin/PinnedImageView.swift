import SwiftUI
import AppKit

/// Закреплённый поверх всех окон снимок (Pin to screen) с регулировкой прозрачности колесиком и режимом сквозного клика
public struct PinnedImageView: View {
    public let image: NSImage
    public var state: PinState
    public let onClose: () -> Void
    public let onEdit: () -> Void
    public let onToggleClickThrough: ((Bool) -> Void)?

    @State private var hovering = false
    @State private var opacity: Double = 1.0
    @State private var showOpacityBadge = false
    @State private var opacityHideTask: Task<Void, Never>?

    public init(
        image: NSImage,
        state: PinState = PinState(),
        onClose: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onToggleClickThrough: ((Bool) -> Void)? = nil
    ) {
        self.image = image
        self.state = state
        self.onClose = onClose
        self.onEdit = onEdit
        self.onToggleClickThrough = onToggleClickThrough
    }

    private func handleScroll(delta: CGFloat, isPrecise: Bool) {
        let step: Double
        if isPrecise {
            step = Double(delta) * 0.005
        } else {
            step = delta > 0 ? 0.05 : -0.05
        }
        let next = min(1.0, max(0.15, opacity + step))
        opacity = (next * 100).rounded() / 100

        withAnimation(.easeOut(duration: 0.15)) {
            showOpacityBadge = true
        }
        opacityHideTask?.cancel()
        opacityHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.2)) {
                    showOpacityBadge = false
                }
            }
        }
    }

    public var body: some View {
        ZStack {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(opacity)

            PinScrollListenerView(onScroll: handleScroll)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showOpacityBadge {
                Text("\(Int(opacity * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.78)))
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            if state.isClickThrough && !hovering {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(4)
                            .background(Color.black.opacity(0.55), in: Circle())
                        Spacer()
                    }
                    .padding(6)
                }
                .transition(.opacity)
            }

            if hovering {
                VStack {
                    HStack(spacing: 4) {
                        Spacer()

                        EditorIconButton(
                            state.isClickThrough ? "lock.fill" : "lock.open",
                            title: state.isClickThrough ? L("pin.click_through_hint") : L("pin.click_through"),
                            width: 30
                        ) {
                            let next = !state.isClickThrough
                            state.isClickThrough = next
                            onToggleClickThrough?(next)
                        }

                        EditorIconButton("pencil", title: L("history.edit"), width: 30, action: onEdit)
                        EditorIconButton("xmark", title: L("pin.unpin"), width: 30, action: onClose)
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.38), location: 0.0),
                                        .init(color: Color.white.opacity(0.12), location: 0.4),
                                        .init(color: Color.white.opacity(0.04), location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 2)
                    .padding(8)
                    .transition(.opacity)

                    Spacer()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(state.isClickThrough ? Color.orange.opacity(0.5) : Color.white.opacity(0.35), lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.easeOut(duration: 0.15), value: state.isClickThrough)
        .onDisappear {
            opacityHideTask?.cancel()
            opacityHideTask = nil
        }
        .onDrag {
            ImageExporter.makeDragItemProvider(for: image)
        }
        .contextMenu {
            Button(L("editor.copy")) { ImageExporter.copyToClipboard(image) }
            Button(state.isClickThrough ? L("pin.unlock_pins") : L("pin.click_through")) {
                let next = !state.isClickThrough
                state.isClickThrough = next
                onToggleClickThrough?(next)
            }
            Menu(L("pin.opacity")) {
                ForEach([1.0, 0.8, 0.6, 0.4, 0.2], id: \.self) { v in
                    Button("\(Int(v * 100))%") { opacity = v }
                }
            }
            Divider()
            Button(L("pin.unpin"), action: onClose)
        }
    }
}

// MARK: - Перехватчик прокрутки колесика мыши

private struct PinScrollListenerView: NSViewRepresentable {
    let onScroll: (CGFloat, Bool) -> Void

    func makeNSView(context: Context) -> ScrollCatcherView {
        let view = ScrollCatcherView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollCatcherView, context: Context) {
        nsView.onScroll = onScroll
    }

    final class ScrollCatcherView: NSView {
        var onScroll: ((CGFloat, Bool) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            guard event.momentumPhase == [] else {
                super.scrollWheel(with: event)
                return
            }
            let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
            if abs(delta) > 0.05 {
                onScroll?(delta, event.hasPreciseScrollingDeltas)
            } else {
                super.scrollWheel(with: event)
            }
        }
    }
}
