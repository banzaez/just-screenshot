import SwiftUI
import AppKit

/// Окно истории снимков: сетка миниатюр, открытие в редакторе, копирование, закрепление, удаление
public struct HistoryWindowView: View {
    @ObservedObject private var store = HistoryStore.shared
    
    public let onEdit: (HistoryEntry) -> Void
    public let onPin: (HistoryEntry) -> Void
    public let onCopy: (HistoryEntry) -> Void
    
    @State private var confirmClear = false
    
    public init(
        onEdit: @escaping (HistoryEntry) -> Void,
        onPin: @escaping (HistoryEntry) -> Void,
        onCopy: @escaping (HistoryEntry) -> Void
    ) {
        self.onEdit = onEdit
        self.onPin = onPin
        self.onCopy = onCopy
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L("history.title"), systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Text("\(store.entries.count)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.1)))
                Spacer()
                Button(role: .destructive) { confirmClear = true } label: {
                    Label(L("history.clear_all"), systemImage: "trash")
                }
                .disabled(store.entries.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            if store.entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text(L("history.empty_title")).font(.title3)
                    Text(L("history.empty_subtitle"))
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210, maximum: 280), spacing: 14)], spacing: 14) {
                        ForEach(store.entries) { entry in
                            HistoryCard(
                                entry: entry,
                                onEdit: { onEdit(entry) },
                                onPin: { onPin(entry) },
                                onCopy: { onCopy(entry) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 400)
        .confirmationDialog(L("history.clear_confirm_title"), isPresented: $confirmClear) {
            Button(L("history.clear_all"), role: .destructive) { store.clear() }
            Button(L("alert.cancel"), role: .cancel) {}
        }
    }
}

private struct HistoryCard: View {
    let entry: HistoryEntry
    let onEdit: () -> Void
    let onPin: () -> Void
    let onCopy: () -> Void
    
    @ObservedObject private var store = HistoryStore.shared
    @State private var hovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06))
                if let thumb = store.thumbnail(for: entry) {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(6)
                }
                
                if hovering {
                    RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.45))
                    HStack(spacing: 6) {
                        EditorIconButton("pencil.tip.crop.circle", title: L("history.edit"), action: onEdit)
                        EditorIconButton("doc.on.doc", title: L("editor.copy"), action: onCopy)
                        EditorIconButton("pin", title: L("history.pin"), action: onPin)
                        EditorIconButton("folder", title: L("history.reveal_finder")) { store.revealInFinder(entry) }
                        EditorIconButton("trash", title: L("history.delete_button")) { store.delete(entry) }
                    }
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onHover { hovering = $0 }
            .onTapGesture(count: 2, perform: onEdit)
            
            HStack {
                Text(entry.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                Spacer()
                Text("\(entry.width) × \(entry.height)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            Button(L("history.edit"), action: onEdit)
            Button(L("editor.copy"), action: onCopy)
            Button(L("history.pin"), action: onPin)
            Button(L("history.reveal_finder")) { store.revealInFinder(entry) }
            Divider()
            Button(L("history.delete_button"), role: .destructive) { store.delete(entry) }
        }
    }
}
