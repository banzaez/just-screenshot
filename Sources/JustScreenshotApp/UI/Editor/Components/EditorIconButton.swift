import SwiftUI

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
