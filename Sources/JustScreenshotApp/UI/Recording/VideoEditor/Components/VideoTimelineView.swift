import SwiftUI

/// Интерактивный таймлайн для покадрового скраббинга и точной обрезки Trim In / Trim Out
public struct VideoTimelineView: View {
    @ObservedObject var model: VideoEditorModel
    @State private var isDraggingPlayhead = false
    
    public init(model: VideoEditorModel) {
        self.model = model
    }
    
    private func formatTime(_ time: Double) -> String {
        let totalSec = max(0, Int(time))
        let min = totalSec / 60
        let sec = totalSec % 60
        let ms = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", min, sec, ms)
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
            
            // Сама дорожка таймлайна с кадрами и маркерами
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let totalDuration = max(0.1, model.duration)
                
                let startX = CGFloat(model.trimStart / totalDuration) * width
                let endX = CGFloat(model.trimEnd / totalDuration) * width
                let currentX = CGFloat(model.currentTime / totalDuration) * width
                
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
                    
                    // Затемнение неактивных областей за пределами Trim
                    // До Trim In
                    if startX > 0 {
                        Rectangle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: max(0, startX), height: height)
                            .cornerRadius(6)
                    }
                    // После Trim Out
                    if endX < width {
                        Rectangle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: max(0, width - endX), height: height)
                            .offset(x: endX)
                            .cornerRadius(6)
                    }
                    
                    // Подсветка активного диапазона (Trim In ... Trim Out)
                    Rectangle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: max(0, endX - startX), height: height)
                        .offset(x: startX)
                    
                    // Ручка Trim Start (желтая)
                    TrimHandleView(isStart: true)
                        .offset(x: max(0, startX - 8))
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    let newSec = Double(val.location.x / width) * totalDuration
                                    model.trimStart = max(0, min(newSec, model.trimEnd - 0.2))
                                    if model.currentTime < model.trimStart {
                                        model.seek(to: model.trimStart)
                                    }
                                }
                        )
                    
                    // Ручка Trim End (желтая)
                    TrimHandleView(isStart: false)
                        .offset(x: min(width - 8, endX - 8))
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    let newSec = Double(val.location.x / width) * totalDuration
                                    model.trimEnd = min(totalDuration, max(newSec, model.trimStart + 0.2))
                                    if model.currentTime > model.trimEnd {
                                        model.seek(to: model.trimEnd)
                                    }
                                }
                        )
                    
                    // Бегунок воспроизведения (Playhead - белая вертикальная линия с шапкой)
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: height)
                    }
                    .offset(x: max(0, min(width - 12, currentX - 6)))
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                isDraggingPlayhead = true
                                let newSec = Double(val.location.x / width) * totalDuration
                                model.seek(to: newSec)
                            }
                            .onEnded { _ in
                                isDraggingPlayhead = false
                            }
                    )
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { val in
                            let newSec = Double(val.location.x / width) * totalDuration
                            model.seek(to: newSec)
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
            if inside {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
