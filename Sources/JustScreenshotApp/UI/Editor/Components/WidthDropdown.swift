import SwiftUI

/// Кнопка с выпадающим списком толщины линии
public struct WidthDropdown: View {
    @Binding var selection: CGFloat
    @State private var isOpen = false
    
    public init(selection: Binding<CGFloat>) {
        self._selection = selection
    }
    
    public var body: some View {
        Button { isOpen.toggle() } label: {
            HStack(spacing: 6) {
                Capsule().fill(Color.primary).frame(width: 18, height: max(2, min(selection, 10)))
                Text("\(Int(selection)) px").font(.callout.monospacedDigit())
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.07)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L("editor.line_width"))
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            VStack(spacing: 2) {
                ForEach(EditorPalette.widths, id: \.self) { w in
                    Button {
                        selection = w
                        isOpen = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .opacity(selection == w ? 1 : 0)
                                .frame(width: 14)
                            Capsule().fill(Color.primary).frame(width: 60, height: w)
                            Text("\(Int(w)) px").font(.callout.monospacedDigit())
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .frame(width: 170, height: 28)
                        .background(RoundedRectangle(cornerRadius: 6).fill(selection == w ? Color.accentColor.opacity(0.15) : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }
}
