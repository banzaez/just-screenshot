import SwiftUI
import AppKit
import UniformTypeIdentifiers

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

/// Окно истории снимков и видеозаписей в стиле Liquid Glass
public struct HistoryWindowView: View {
    private static let gridColumns = [GridItem(.adaptive(minimum: 250, maximum: 320), spacing: 14)]

    private var store = HistoryStore.shared

    public let onEdit: (HistoryEntry) -> Void
    public let onPin: (HistoryEntry) -> Void
    public let onCopy: (HistoryEntry) -> Void

    @State private var selectedFilter: HistoryFilter = .all
    @State private var confirmClear = false
    @Namespace private var filterNamespace

    public init(
        onEdit: @escaping (HistoryEntry) -> Void,
        onPin: @escaping (HistoryEntry) -> Void,
        onCopy: @escaping (HistoryEntry) -> Void
    ) {
        self.onEdit = onEdit
        self.onPin = onPin
        self.onCopy = onCopy
    }

    private func entriesSummary() -> (all: Int, photos: Int, videos: Int, visible: [HistoryEntry]) {
        var photos = 0
        var videos = 0
        var visible: [HistoryEntry] = []
        if selectedFilter == .all {
            visible = store.entries
        }
        for entry in store.entries {
            switch entry.kind {
            case .image:
                photos += 1
                if selectedFilter == .photos { visible.append(entry) }
            case .video:
                videos += 1
                if selectedFilter == .videos { visible.append(entry) }
            }
        }
        return (store.entries.count, photos, videos, visible)
    }

    public var body: some View {
        let summary = entriesSummary()

        ZStack {
            GlassWindowBackground(showSpecularRim: false)

            VStack(spacing: 0) {
                headerBar(allCount: summary.all, photosCount: summary.photos, videosCount: summary.videos)

                GlassDivider(isHeaderSeparator: true)

                if summary.visible.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: Self.gridColumns, spacing: 14) {
                            ForEach(summary.visible) { entry in
                                HistoryCard(
                                    entry: entry,
                                    onEdit: { onEdit(entry) },
                                    onPin: { onPin(entry) },
                                    onCopy: { onCopy(entry) }
                                )
                            }
                        }
                        .padding(18)
                    }
                }
            }
        }
        .frame(minWidth: 620, minHeight: 460)
        .onAppear {
            store.pruneMissingFiles()
        }
        .confirmationDialog(
            L("history.clear_confirm_title"),
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button(L("history.clear_all"), role: .destructive) { store.clear() }
            Button(L("alert.cancel"), role: .cancel) {}
        } message: {
            Text(L("history.clear_confirm_message"))
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                Image(systemName: selectedFilter == .videos ? "video.slash" : "photo.on.rectangle.angled")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            Text(selectedFilter == .videos ? L("history.empty_videos_title") : L("history.empty_title"))
                .font(.title3.weight(.semibold))
            Text(selectedFilter == .videos ? L("history.empty_videos_subtitle") : L("history.empty_subtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header Bar

    private func headerBar(allCount: Int, photosCount: Int, videosCount: Int) -> some View {
        HStack(spacing: 8) {
            Spacer()
                .frame(width: 72)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                ForEach(HistoryFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    let filterCount: Int = switch filter {
                    case .all: allCount
                    case .photos: photosCount
                    case .videos: videosCount
                    }
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(filter.title)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                .lineLimit(1)

                            Text("\(filterCount)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.08))
                                )
                        }
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.accentColor.opacity(0.24),
                                                Color.accentColor.opacity(0.12)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.accentColor.opacity(0.55),
                                                        Color.accentColor.opacity(0.20)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .matchedGeometryEffect(id: "activeHistoryFilter", in: filterNamespace)
                                    .shadow(color: Color.accentColor.opacity(0.2), radius: 6, x: 0, y: 2)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.35), location: 0.0),
                                .init(color: Color.white.opacity(0.12), location: 0.5),
                                .init(color: Color.white.opacity(0.04), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            .fixedSize()

            Spacer(minLength: 8)

            GlassButton(
                title: L("history.clear_all"),
                icon: "trash",
                role: .destructive
            ) {
                confirmClear = true
            }
            .disabled(store.entries.isEmpty)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 56)
    }
}

// MARK: - History Card

private struct HistoryCard: View {
    let entry: HistoryEntry
    let onEdit: () -> Void
    let onPin: () -> Void
    let onCopy: () -> Void

    private var store = HistoryStore.shared
    private var localization = LocalizationManager.shared
    @State private var thumbnail: NSImage?
    @State private var thumbnailLoadFailed = false
    @State private var hovering = false
    @State private var copiedFeedback = false
    @State private var copiedFeedbackTask: Task<Void, Never>?

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
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.2))

                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(6)
                } else if thumbnailLoadFailed {
                    Image(systemName: entry.kind == .video ? "video.slash" : "photo")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.secondary)
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
                        .fill(Color.black.opacity(0.42))

                    HStack(spacing: 4) {
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
                            triggerCopy()
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
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
                }
            }
            .frame(height: 145)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture(perform: onEdit)
            .onDrag {
                if let url = store.existingFileURL(for: entry) {
                    return NSItemProvider(object: url as NSURL)
                }
                let entryID = entry.id
                let targetEntry = entry
                let provider = NSItemProvider()
                provider.registerFileRepresentation(
                    forTypeIdentifier: UTType.fileURL.identifier,
                    fileOptions: [.openInPlace],
                    visibility: .all
                ) { completion in
                    Task { @MainActor in
                        await HistoryStore.shared.waitForPendingWrite(id: entryID)
                        completion(HistoryStore.shared.existingFileURL(for: targetEntry), false, nil)
                    }
                    return nil
                }
                return provider
            }
            .task(id: entry.id) {
                if thumbnail == nil {
                    let loaded = await store.thumbnailAsync(for: entry)
                    guard !Task.isCancelled else { return }
                    if let loaded {
                        thumbnail = loaded
                        thumbnailLoadFailed = false
                    } else {
                        thumbnailLoadFailed = true
                    }
                }
            }
            .onDisappear {
                copiedFeedbackTask?.cancel()
                thumbnail = nil
            }

            HStack(spacing: 6) {
                Image(systemName: entry.kind == .video ? "video.fill" : "photo")
                    .font(.system(size: 10))
                    .foregroundStyle(entry.kind == .video ? Color.accentColor : Color.secondary)
                Text(entry.date, format: .dateTime.day().month().hour().minute())
                    .environment(\.locale, localization.currentLanguage.locale)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(entry.width) × \(entry.height)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: hovering ? Color.accentColor.opacity(0.7) : Color.white.opacity(0.28), location: 0.0),
                            .init(color: hovering ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.08), location: 0.4),
                            .init(color: Color.white.opacity(0.02), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: hovering ? 1.5 : 1
                )
        )
        .shadow(color: Color.black.opacity(hovering ? 0.12 : 0.04), radius: hovering ? 8 : 4, x: 0, y: hovering ? 4 : 2)
        .animation(.easeOut(duration: 0.18), value: hovering)
        .contextMenu {
            Button(L("history.edit"), action: onEdit)
            Button(L("editor.copy")) { triggerCopy() }
            Button(L("hud.save_as")) { store.saveAs(entry) }
            if entry.kind == .image {
                Button(L("history.pin"), action: onPin)
            }
            Button(L("history.reveal_finder")) { store.revealInFinder(entry) }
            Divider()
            Button(L("history.delete_button"), role: .destructive) { store.delete(entry) }
        }
    }

    private func triggerCopy() {
        onCopy()
        copiedFeedbackTask?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) {
            copiedFeedback = true
        }
        copiedFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                copiedFeedback = false
            }
        }
    }

    private static func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
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
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 26)
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
        return isHovered ? Color.white.opacity(0.3) : Color.white.opacity(0.12)
    }
}
