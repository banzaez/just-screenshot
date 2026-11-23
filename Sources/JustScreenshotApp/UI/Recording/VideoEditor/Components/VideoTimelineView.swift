import SwiftUI

/// Интерактивный таймлайн для покадрового скраббинга и точной обрезки Trim In / Trim Out
public struct VideoTimelineView: View {
    var model: VideoEditorModel
    @State private var isDraggingPlayhead = false

    public init(model: VideoEditorModel) {
        self.model = model
    }

    private func formatTime(_ time: Double) -> String {
        let safe = (time.isFinite && !time.isNaN) ? max(0, time) : 0
        let totalCentiseconds = Int((safe * 100).rounded())
        let min = totalCentiseconds / 6000
        let sec = (totalCentiseconds / 100) % 60
        let cs = totalCentiseconds % 100
        return String(format: "%02d:%02d.%02d", min, sec, cs)
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Метки времени: Trim Start, Playhead Current, Trim End
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.to.line")
                        .font(.system(size: 10))
                    Text(L("video_editor.trim_in", formatTime(model.trimStart)))
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundColor(.yellow)

                Spacer()

                Text(formatTime(model.currentTime))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 4) {
                    Text(L("video_editor.trim_out", formatTime(model.trimEnd)))
                        .font(.system(size: 11, design: .monospaced))
                    Image(systemName: "arrow.left.to.line")
                        .font(.system(size: 10))
                }
                .foregroundColor(.yellow)
            }
            .padding(.horizontal, 4)

            // Дорожка таймлайна с кадрами и маркерами
            GeometryReader { geo in
                let width = max(1, geo.size.width)
                let height = max(1, geo.size.height)
                let totalDuration = max(0.1, model.duration)

                let startX = min(width, max(0, CGFloat(model.trimStart / totalDuration) * width))
                let endX = min(width, max(startX, CGFloat(model.trimEnd / totalDuration) * width))
                let currentX = min(width, max(0, CGFloat(model.currentTime / totalDuration) * width))

                ZStack(alignment: .leading) {
                    // Фоновая лента кадров (Filmstrip)
                    HStack(spacing: 0) {
                        if model.thumbnails.isEmpty {
                            Rectangle()
                                .fill(Color.black.opacity(0.4))
                        } else {
                            ForEach(0..<model.thumbnails.count, id: \.self) { idx in
                                Image(nsImage: model.thumbnails[idx])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: width / CGFloat(model.thumbnails.count), height: height)
                                    .clipped()
                            }
                        }
                    }
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                    // Затемнение до Trim In
                    if startX > 0 {
                        Rectangle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: startX, height: height)
                            .cornerRadius(6)
                    }

                    // Затемнение после Trim Out (cornerRadius ДО offset)
                    if endX < width {
                        Rectangle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: max(0, width - endX), height: height)
                            .cornerRadius(6)
                            .offset(x: endX)
                    }

                    // Подсветка активного диапазона (Trim In ... Trim Out)
                    Rectangle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: max(0, endX - startX), height: height)
                        .offset(x: startX)

                    // Маркеры кликов для Smart Zoom и подсветки кликов
                    if model.isSmartZoomEnabled || model.isClickHighlightsEnabled {
                        ForEach(Array(model.cursorTrack.clickTimestamps.enumerated()), id: \.offset) { _, ts in
                            let markerX = min(width - 3, max(3, CGFloat(ts / totalDuration) * width))
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 5, height: 5)
                                .shadow(color: .black.opacity(0.6), radius: 1)
                                .offset(x: markerX - 2.5, y: height / 2 - 5)
                                .allowsHitTesting(false)
                        }
                    }

                    // Красные маркеры нажатий клавиш на таймлайне
                    if model.isKeystrokesEnabled {
                        ForEach(Array(model.keystrokeTrack.timestamps(filter: model.keystrokeFilter).enumerated()), id: \.offset) { _, ts in
                            let markerX = min(width - 3, max(3, CGFloat(ts / totalDuration) * width))
                            Circle()
                                .fill(Color.red)
                                .frame(width: 5, height: 5)
                                .shadow(color: .black.opacity(0.6), radius: 1)
                                .offset(x: markerX - 2.5, y: height / 2 - 11)
                                .allowsHitTesting(false)
                        }
                    }

                    // Ручка Trim Start
                    TrimHandleView(isStart: true)
                        .offset(x: max(0, startX - 8))
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    let newSec = Double(val.location.x / width) * totalDuration
                                    model.hasUserEditedTrim = true
                                    model.trimStart = max(0, min(newSec, model.trimEnd - 0.2))
                                    if model.currentTime < model.trimStart {
                                        model.seek(to: model.trimStart, exact: false)
                                    }
                                }
                                .onEnded { _ in
                                    model.seek(to: max(model.currentTime, model.trimStart), exact: true)
                                }
                        )

                    // Ручка Trim End
                    TrimHandleView(isStart: false)
                        .offset(x: max(0, min(width - 16, endX - 8)))
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    let newSec = Double(val.location.x / width) * totalDuration
                                    model.hasUserEditedTrim = true
                                    model.trimEnd = min(totalDuration, max(newSec, model.trimStart + 0.2))
                                    if model.currentTime > model.trimEnd {
                                        model.seek(to: model.trimEnd, exact: false)
                                    }
                                }
                                .onEnded { _ in
                                    model.seek(to: min(model.currentTime, model.trimEnd), exact: true)
                                }
                        )

                    // Бегунок воспроизведения (Playhead)
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: max(1, height - 10))
                    }
                    .offset(x: max(0, min(width - 10, currentX - 5)))
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                isDraggingPlayhead = true
                                let newSec = Double(val.location.x / width) * totalDuration
                                model.seek(to: newSec, exact: false)
                            }
                            .onEnded { val in
                                isDraggingPlayhead = false
                                let newSec = Double(val.location.x / width) * totalDuration
                                model.seek(to: newSec, exact: true)
                            }
                    )
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { val in
                            let newSec = Double(val.location.x / width) * totalDuration
                            model.seek(to: newSec, exact: true)
                        }
                )
            }
            .frame(height: 52)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.25))
    }
}

private struct TrimHandleView: View {
    let isStart: Bool

    @State private var isHovering = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.yellow)
                .frame(width: 16, height: 52)

            Image(systemName: isStart ? "chevron.right" : "chevron.left")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.black)
        }
        .shadow(color: .black.opacity(0.4), radius: 3)
        .onHover { inside in
            guard inside != isHovering else { return }
            isHovering = inside
            if inside {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            if isHovering {
                isHovering = false
                NSCursor.pop()
            }
        }
    }
}
