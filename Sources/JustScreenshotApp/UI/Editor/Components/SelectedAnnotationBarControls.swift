import SwiftUI

/// Общие куски контекстной панели выбранной аннотации (image + video)
enum SelectedAnnotationBarControls {
    
    static let barHeight: CGFloat = 42
    
    struct EmptyHint: View {
        var showShortcuts: Bool = false
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "cursorarrow.click.2")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(L("editor.selected.empty_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if showShortcuts {
                    Text(L("editor.selected.shortcuts_hint"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
        }
    }
    
    struct TitleLabel: View {
        let title: String
        let systemImage: String
        
        var body: some View {
            Label(title, systemImage: systemImage)
                .font(.callout.bold())
                .foregroundStyle(Color.accentColor)
        }
    }
    
    struct FontSizeControls: View {
        let fontSize: CGFloat
        let onSmaller: () -> Void
        let onLarger: () -> Void
        
        var body: some View {
            HStack(spacing: 10) {
                EditorIconButton("textformat.size.smaller", title: L("editor.selected.font_smaller"), action: onSmaller)
                Text("\(Int(fontSize))")
                    .font(.callout.monospacedDigit())
                    .frame(width: 28)
                EditorIconButton("textformat.size.larger", title: L("editor.selected.font_larger"), action: onLarger)
            }
        }
    }
    
    struct RotationControls: View {
        let angle: Double
        let onSetAngle: (Double) -> Void
        var sliderWidth: CGFloat = 110
        var wrapAngle: Bool = false
        
        var body: some View {
            HStack(spacing: 10) {
                EditorIconButton("rotate.left", title: L("editor.selected.rotate_left")) {
                    onSetAngle(normalized(angle - 15))
                }
                Slider(
                    value: Binding(get: { angle }, set: { onSetAngle($0) }),
                    in: -180...180
                )
                .frame(width: sliderWidth)
                EditorIconButton("rotate.right", title: L("editor.selected.rotate_right")) {
                    onSetAngle(normalized(angle + 15))
                }
                Text("\(Int(angle.rounded()))°")
                    .font(.callout.monospacedDigit())
                    .frame(width: wrapAngle ? 36 : 40)
                EditorIconButton("arrow.counterclockwise", title: L("editor.selected.reset_angle")) {
                    onSetAngle(0)
                }
            }
        }
        
        private func normalized(_ value: Double) -> Double {
            guard wrapAngle else { return value }
            var deg = value
            if deg < -180 { deg += 360 }
            if deg > 180 { deg -= 360 }
            return deg
        }
    }
    
    struct ActionButtons: View {
        let onDuplicate: () -> Void
        let onDelete: () -> Void
        let onDeselect: () -> Void
        
        var body: some View {
            HStack(spacing: 10) {
                EditorIconButton("plus.square.on.square", title: L("editor.selected.duplicate"), action: onDuplicate)
                EditorIconButton("trash", title: L("editor.selected.delete"), action: onDelete)
                EditorIconButton("xmark", title: L("editor.selected.deselect"), action: onDeselect)
            }
        }
    }
    
    struct BarChrome<Content: View>: View {
        let isActive: Bool
        var activeOpacity: Double = 0.1
        var inactiveColor: Color = Color(nsColor: .controlBackgroundColor).opacity(0.55)
        var showBottomDivider: Bool = false
        @ViewBuilder var content: () -> Content
        
        var body: some View {
            HStack(spacing: 0) {
                content()
            }
            .frame(height: barHeight)
            .frame(maxWidth: .infinity)
            .background(
                isActive
                    ? Color.accentColor.opacity(activeOpacity)
                    : inactiveColor
            )
            .overlay(alignment: .bottom) {
                if showBottomDivider { Divider() }
            }
            .animation(.easeInOut(duration: 0.15), value: isActive)
        }
    }
}
