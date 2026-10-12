import SwiftUI
import AppKit

/// Палитра цветов редактора и пресеты фона
public enum EditorPalette {
    public static let colors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .cyan, .blue, .indigo, .purple, .pink, .white, .gray, .black
    ]
    public static let widths: [CGFloat] = [1, 2, 3, 4, 6, 8, 12, 16]
}

/// Пресеты "красивого фона"
public enum BackdropPreset: String, CaseIterable, Identifiable, Sendable {
    case aurora = "Аврора"
    case ocean = "Океан"
    case sunset = "Закат"
    case forest = "Лес"
    case graphite = "Графит"
    case snow = "Снег"
    
    public var id: String { rawValue }
    
    public var colors: [Color] {
        switch self {
        case .aurora: return [Color(red: 0.36, green: 0.28, blue: 0.95), Color(red: 0.75, green: 0.30, blue: 0.85)]
        case .ocean: return [Color(red: 0.10, green: 0.45, blue: 0.95), Color(red: 0.20, green: 0.85, blue: 0.90)]
        case .sunset: return [Color(red: 1.0, green: 0.55, blue: 0.20), Color(red: 0.95, green: 0.25, blue: 0.55)]
        case .forest: return [Color(red: 0.07, green: 0.50, blue: 0.40), Color(red: 0.55, green: 0.85, blue: 0.45)]
        case .graphite: return [Color(white: 0.18), Color(white: 0.38)]
        case .snow: return [Color(white: 0.92), Color(red: 0.80, green: 0.86, blue: 0.97)]
        }
    }
    
    public var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    @MainActor
    public var localizedName: String {
        switch self {
        case .aurora: return L("preset.aurora")
        case .ocean: return L("preset.ocean")
        case .sunset: return L("preset.sunset")
        case .forest: return L("preset.forest")
        case .graphite: return L("preset.graphite")
        case .snow: return L("preset.snow")
        }
    }
}

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

/// Иконочная кнопка с полной областью нажатия
public struct EditorIconButton: View {
    let systemName: String
    var title: String? = nil
    var isActive: Bool = false
    var width: CGFloat = 36
    let action: () -> Void
    
    public init(_ systemName: String, title: String? = nil, isActive: Bool = false, width: CGFloat = 36, action: @escaping () -> Void) {
        self.systemName = systemName
        self.title = title
        self.isActive = isActive
        self.width = width
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: width, height: 32)
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: 7).fill(isActive ? Color.accentColor : Color.primary.opacity(0.06)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title ?? "")
    }
}
