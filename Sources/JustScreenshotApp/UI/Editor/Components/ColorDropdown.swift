import SwiftUI

/// Кнопка с выпадающей палитрой цветов
public struct ColorDropdown: View {
    @Binding var selection: Color
    var title: String = ""
    @State private var isOpen = false
    
    public init(selection: Binding<Color>, title: String = "") {
        self._selection = selection
        self.title = title
    }
    
    public var body: some View {
        Button { isOpen.toggle() } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(selection)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.primary.opacity(0.35), lineWidth: 1))
                Text(title.isEmpty ? L("editor.color") : title).font(.callout)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.07)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L("editor.choose_color"))
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 8), count: 5), spacing: 8) {
                ForEach(EditorPalette.colors, id: \.self) { color in
                    Button {
                        selection = color
                        isOpen = false
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1))
                            .overlay(
                                Circle().stroke(Color.accentColor, lineWidth: 3).padding(-3)
                                    .opacity(selection == color ? 1 : 0)
                            )
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
        }
    }
}
