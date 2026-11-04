import SwiftUI
import AppKit

/// Фильтр элементов истории
public enum HistoryFilter: String, CaseIterable, Identifiable {
    case all
    case photos
    case videos
    
    public var id: String { rawValue }
    
    @MainActor
    var title: String {
        switch self {
        case .all: return L("history.filter.all")
        case .photos: return L("history.filter.photos")
        case .videos: return L("history.filter.videos")
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .photos: return "camera.viewfinder"
        case .videos: return "video.fill"
        }
    }
}

/// Окно истории снимков и видеозаписей: фильтрация, сетка миниатюр, открытие в редакторе, Drag & Drop, копирование, сохранение и удаление
public struct HistoryWindowView: View {
    private var store = HistoryStore.shared
    
    public let onEdit: (HistoryEntry) -> Void
    public let onPin: (HistoryEntry) -> Void
    public let onCopy: (HistoryEntry) -> Void
    
    @State private var selectedFilter: HistoryFilter = .all
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
    
    private var filteredEntries: [HistoryEntry] {
        switch selectedFilter {
        case .all:
            return store.entries
        case .photos:
            return store.entries.filter { $0.kind == .image }
        case .videos:
            return store.entries.filter { $0.kind == .video }
        }
    }
    
    private func count(for filter: HistoryFilter) -> Int {
        switch filter {
        case .all:
            return store.entries.count
        case .photos:
            return store.entries.reduce(0) { $0 + ($1.kind == .image ? 1 : 0) }
        case .videos:
            return store.entries.reduce(0) { $0 + ($1.kind == .video ? 1 : 0) }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Верхняя панель с фильтрами по типу медиа (Все / Скриншоты / Видео)
            HStack(spacing: 12) {
                Label(L("history.title"), systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach(HistoryFilter.allCases) { filter in
                        let isSelected = selectedFilter == filter
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedFilter = filter
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: filter.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(filter.title)
                                    .font(.system(size: 12, weight: .medium))
                                Text("\(count(for: filter))")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule().fill(
                                            isSelected
                                                ? Color.white.opacity(0.24)
                                                : Color.primary.opacity(0.08)
                                        )
                                    )
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isSelected ? Color.accentColor : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                
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
            
            if filteredEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: selectedFilter == .videos ? "video.slash" : "photo.on.rectangle.angled")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text(L("history.empty_title")).font(.title3)
                    Text(L("history.empty_subtitle"))
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 290), spacing: 14)], spacing: 14) {
                        ForEach(filteredEntries) { entry in
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
        .frame(minWidth: 580, minHeight: 420)
        .onAppear {
            store.pruneMissingFiles()
        }
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
    
    private var store = HistoryStore.shared
    @State private var thumbnail: NSImage?
    @State private var hovering = false
    @State private var copiedFeedback = false
    
    init(
        entry: HistoryEntry,
        onEdit: @escaping () -> Void,
        onPin: @escaping () -> Void,
        onCopy: @escaping () -> Void
    ) {
        self.entry = entry
        self.onEdit = onEdit
        self.onPin = onPin
        self.onCopy = onCopy
        _thumbnail = State(initialValue: HistoryStore.shared.cachedThumbnail(for: entry))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(6)
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                }
                
                // Бейдж видео с длительностью в углу превью
                if entry.kind == .video {
                    VStack {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 10, weight: .bold))
                                if let duration = entry.duration {
                                    Text(Self.formatDuration(duration))
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                } else {
                                    Text("MP4")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.72))
                            )
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                
                // Панель быстрых действий при наведении
                if hovering {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.48))
                    
                    HStack(spacing: 6) {
                        HistoryCardActionButton(
                            icon: entry.kind == .video ? "film" : "pencil.tip.crop.circle",
                            title: L("history.edit"),
                            action: onEdit
                        )
                        
                        HistoryCardActionButton(
                            icon: copiedFeedback ? "checkmark" : "doc.on.doc",
                            title: L("editor.copy"),
                            isSuccess: copiedFeedback
                        ) {
                            onCopy()
                            withAnimation(.easeInOut(duration: 0.15)) {
                                copiedFeedback = true
                            }
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(1.2))
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    copiedFeedback = false
                                }
                            }
                        }
                        
                        HistoryCardActionButton(
                            icon: "arrow.down.to.line",
                            title: L("hud.save_as")
                        ) {
                            store.saveAs(entry)
                        }
                        
                        if entry.kind == .image {
                            HistoryCardActionButton(
                                icon: "pin",
                                title: L("history.pin"),
                                action: onPin
                            )
                        }
                        
                        HistoryCardActionButton(
                            icon: "folder",
                            title: L("history.reveal_finder")
                        ) {
                            store.revealInFinder(entry)
                        }
                        
                        HistoryCardActionButton(
                            icon: "trash",
                            title: L("history.delete_button"),
                            isDestructive: true
                        ) {
                            store.delete(entry)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.55))
                    )
                }
            }
            .frame(height: 145)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        hovering ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.08),
                        lineWidth: hovering ? 1.5 : 1
                    )
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture(perform: onEdit)
            .onDrag {
                let url = store.fileURL(for: entry)
                if FileManager.default.fileExists(atPath: url.path) {
                    return NSItemProvider(object: url as NSURL)
                }
                return NSItemProvider()
            }
            .task(id: entry.id) {
                if thumbnail == nil {
                    thumbnail = await store.thumbnailAsync(for: entry)
                }
            }
            
            HStack(spacing: 6) {
                Image(systemName: entry.kind == .video ? "video.fill" : "photo")
                    .font(.system(size: 10))
                    .foregroundStyle(entry.kind == .video ? Color.accentColor : Color.secondary)
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
            Button(L("hud.save_as")) { store.saveAs(entry) }
            if entry.kind == .image {
                Button(L("history.pin"), action: onPin)
            }
            Button(L("history.reveal_finder")) { store.revealInFinder(entry) }
            Divider()
            Button(L("history.delete_button"), role: .destructive) { store.delete(entry) }
        }
    }
    
    private static func formatDuration(_ seconds: Double) -> String {
        let total = max(1, Int(seconds.rounded()))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

private struct HistoryCardActionButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    var isSuccess: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(foregroundColor)
                .background(
                    Circle()
                        .fill(backgroundColor)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(title)
        .accessibilityLabel(title)
    }
    
    private var foregroundColor: Color {
        if isSuccess { return .green }
        if isDestructive { return isHovered ? .white : .red }
        return .white
    }
    
    private var backgroundColor: Color {
        if isSuccess { return Color.green.opacity(0.22) }
        if isDestructive { return isHovered ? Color.red.opacity(0.85) : Color.red.opacity(0.22) }
        return isHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.1)
    }
}
