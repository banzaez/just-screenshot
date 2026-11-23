import AppKit
import AVFoundation
import ImageIO
import Observation
import UniformTypeIdentifiers

/// Тип медиафайла в истории
public enum HistoryMediaKind: String, Codable, Hashable, Sendable {
    case image
    case video
}

/// Запись истории снимков и видеозаписей
public struct HistoryEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let width: Int
    public let height: Int
    public let kind: HistoryMediaKind
    public let duration: Double?
    public let externalFilePath: String?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        width: Int,
        height: Int,
        kind: HistoryMediaKind = .image,
        duration: Double? = nil,
        externalFilePath: String? = nil
    ) {
        self.id = id
        self.date = date
        self.width = width
        self.height = height
        self.kind = kind
        self.duration = duration
        self.externalFilePath = externalFilePath
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, width, height, kind, duration, externalFilePath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.date = try container.decode(Date.self, forKey: .date)
        self.width = try container.decode(Int.self, forKey: .width)
        self.height = try container.decode(Int.self, forKey: .height)
        self.kind = try container.decodeIfPresent(HistoryMediaKind.self, forKey: .kind) ?? .image
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        self.externalFilePath = try container.decodeIfPresent(String.self, forKey: .externalFilePath)
    }
}

/// Хранилище истории: PNG-снимки, ссылки на MP4-видеозаписи + index.json
@Observable
@MainActor
public final class HistoryStore {
    public static let shared = HistoryStore()

    public private(set) var entries: [HistoryEntry] = []

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let indexURL: URL
    @ObservationIgnored private let maxEntries = 300
    @ObservationIgnored private let thumbnails = NSCache<NSUUID, NSImage>()
    @ObservationIgnored private var pendingImageWrites: [UUID: (image: NSImage, task: Task<Void, Never>)] = [:]
    @ObservationIgnored private var inFlightThumbnails: [UUID: Task<NSImage?, Never>] = [:]
    @ObservationIgnored private var saveIndexTask: Task<Void, Never>?
    @ObservationIgnored private let indexWriteQueue = DispatchQueue(label: "com.justscreenshot.history.index")
    @ObservationIgnored nonisolated(unsafe) private var terminateObserver: NSObjectProtocol?

    internal init(directory: URL? = nil, observeTermination: Bool = true) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("JustScreenshot/History", isDirectory: true)
        }
        self.indexURL = self.directory.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        thumbnails.countLimit = 200
        thumbnails.totalCostLimit = 64 * 1024 * 1024 // 64 MB лимит для миниатюр
        loadIndex()

        if observeTermination {
            terminateObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.flushPendingWrites()
                }
            }
        }
    }

    deinit {
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
        }
    }

    public func fileURL(for entry: HistoryEntry) -> URL {
        if let externalPath = entry.externalFilePath, !externalPath.isEmpty {
            return URL(fileURLWithPath: externalPath)
        }
        let ext = entry.kind == .video ? "mp4" : "png"
        return directory.appendingPathComponent("\(entry.id.uuidString).\(ext)")
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded.filter { FileManager.default.fileExists(atPath: fileURL(for: $0).path) }
    }

    /// Перепроверяет наличие файлов на диске (пропускает записи с незавершённой фоновой записью PNG)
    public func pruneMissingFiles() {
        let valid = entries.filter { entry in
            if pendingImageWrites[entry.id] != nil { return true }
            return FileManager.default.fileExists(atPath: fileURL(for: entry).path)
        }
        if valid.count != entries.count {
            entries = valid
            saveIndex()
        }
    }

    private func saveIndex() {
        let currentEntries = self.entries
        let url = self.indexURL
        let queue = self.indexWriteQueue
        saveIndexTask?.cancel()
        saveIndexTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            Self.writeIndexSynchronously(currentEntries, to: url, on: queue)
        }
    }

    /// Синхронная сериализованная запись index.json и ожидание незавершённых PNG-записей при выходе
    public func flushPendingWrites() {
        saveIndexTask?.cancel()
        saveIndexTask = nil
        let currentEntries = self.entries
        let url = self.indexURL
        Self.writeIndexSynchronously(currentEntries, to: url, on: indexWriteQueue)
    }

    nonisolated private static func writeIndexSynchronously(
        _ entries: [HistoryEntry],
        to url: URL,
        on queue: DispatchQueue
    ) {
        queue.sync {
            do {
                let data = try JSONEncoder().encode(entries)
                try data.write(to: url, options: .atomic)
            } catch {
                AppLogger.history.error("Failed to save history index: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Добавление снимка в историю (новые — в начале) с фоновым кодированием/записью PNG без блокировки MainActor
    @discardableResult
    public func add(_ image: NSImage, id: UUID = UUID(), preencodedPNG: Data? = nil) -> HistoryEntry? {
        guard let cgImage = ImageExporter.cgImage(from: image) else { return nil }
        let entry = HistoryEntry(
            id: id,
            date: Date(),
            width: max(1, Int(image.size.width)),
            height: max(1, Int(image.size.height)),
            kind: .image
        )
        let url = fileURL(for: entry)

        // Легковесная миниатюра (<0.5 МБ вместо 40–60 МБ оригинала в RAM)
        let thumb = Self.makeThumbnail(from: cgImage)
        let cost = max(1, Int(thumb.size.width * thumb.size.height * 4))
        thumbnails.setObject(thumb, forKey: id as NSUUID, cost: cost)

        pendingImageWrites[id]?.task.cancel()
        let writeTask = Task.detached(priority: .utility) { [weak self] in
            defer {
                Task { @MainActor [weak self] in
                    self?.pendingImageWrites.removeValue(forKey: id)
                }
            }
            guard !Task.isCancelled else { return }
            let data = preencodedPNG ?? ImageExporter.pngData(from: cgImage)
            guard !Task.isCancelled, let data else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                AppLogger.history.error("Failed to write history PNG \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        pendingImageWrites[id] = (image: image, task: writeTask)

        insertAndTrim(entry)
        return entry
    }

    /// Ожидание завершения фоновой записи конкретного снимка (для тестов и немедленного drag/export)
    internal func waitForPendingWrite(id: UUID) async {
        if let task = pendingImageWrites[id]?.task {
            await task.value
        }
    }

    /// Добавление записанного или экспортированного видео в историю
    @discardableResult
    public func addVideo(
        url: URL,
        width: Int,
        height: Int,
        duration: Double,
        id: UUID = UUID()
    ) -> HistoryEntry {
        let standardizedPath = url.standardizedFileURL.path
        if let existing = entries.first(where: { fileURL(for: $0).standardizedFileURL.path == standardizedPath }) {
            thumbnails.removeObject(forKey: existing.id as NSUUID)
            entries.removeAll { $0.id == existing.id }
        }

        let entry = HistoryEntry(
            id: id,
            date: Date(),
            width: max(1, width),
            height: max(1, height),
            kind: .video,
            duration: max(0, duration),
            externalFilePath: standardizedPath
        )
        insertAndTrim(entry)
        return entry
    }

    private func insertAndTrim(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        entries.insert(entry, at: 0)

        while entries.count > maxEntries, let last = entries.popLast() {
            pendingImageWrites.removeValue(forKey: last.id)?.task.cancel()
            thumbnails.removeObject(forKey: last.id as NSUUID)
            if last.externalFilePath == nil {
                Self.removeURLsInBackground([fileURL(for: last)])
            }
        }
        saveIndex()
    }

    /// Полное изображение для редактирования (учитывает незавершённую фоновую запись)
    public func image(for entry: HistoryEntry) -> NSImage? {
        guard entry.kind == .image else { return nil }
        if let pending = pendingImageWrites[entry.id] {
            return pending.image
        }
        guard let img = NSImage(contentsOf: fileURL(for: entry)) else { return nil }
        img.size = NSSize(width: entry.width, height: entry.height)
        return img
    }

    /// Возвращает URL файла если он уже на диске, иначе nil
    public func existingFileURL(for entry: HistoryEntry) -> URL? {
        let url = fileURL(for: entry)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Мгновенное получение уже закэшированной в памяти миниатюры без I/O и задержек
    public func cachedThumbnail(for entry: HistoryEntry) -> NSImage? {
        thumbnails.object(forKey: entry.id as NSUUID)
    }

    /// Асинхронная загрузка миниатюры с дедупликацией параллельных запросов
    public func thumbnailAsync(for entry: HistoryEntry) async -> NSImage? {
        if let cached = thumbnails.object(forKey: entry.id as NSUUID) { return cached }
        if let existingTask = inFlightThumbnails[entry.id] {
            return await existingTask.value
        }

        let url = fileURL(for: entry)
        let kind = entry.kind
        let id = entry.id
        let pendingWrite = pendingImageWrites[id]?.task

        let task = Task<NSImage?, Never> {
            await pendingWrite?.value
            let cg = await Task.detached(priority: .userInitiated) {
                if kind == .video {
                    return await Self.decodeVideoThumbnailCGImage(at: url)
                } else {
                    return Self.decodeThumbnailCGImage(at: url)
                }
            }.value
            guard !Task.isCancelled, let cg else { return nil }
            let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            let cost = max(1, cg.width * cg.height * 4)
            self.thumbnails.setObject(img, forKey: id as NSUUID, cost: cost)
            return img
        }
        inFlightThumbnails[id] = task
        let result = await task.value
        inFlightThumbnails.removeValue(forKey: id)
        return result
    }

    nonisolated private static func makeThumbnail(from cgImage: CGImage, maxDimension: CGFloat = 560) -> NSImage {
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        guard w > maxDimension || h > maxDimension else {
            return NSImage(cgImage: cgImage, size: NSSize(width: w, height: h))
        }
        let scale = maxDimension / max(w, h)
        let thumbW = max(1, Int((w * scale).rounded()))
        let thumbH = max(1, Int((h * scale).rounded()))
        // Всегда используем совместимое sRGB-пространство для CGContext, чтобы не падать на indexed/CMYK
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: thumbW,
            height: thumbH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return NSImage(cgImage: cgImage, size: NSSize(width: w, height: h))
        }
        ctx.interpolationQuality = .medium
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: thumbW, height: thumbH))
        guard let thumbCG = ctx.makeImage() else {
            return NSImage(cgImage: cgImage, size: NSSize(width: w, height: h))
        }
        return NSImage(cgImage: thumbCG, size: NSSize(width: thumbW, height: thumbH))
    }

    nonisolated private static func decodeThumbnailCGImage(at url: URL) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 560,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
    }

    nonisolated private static func decodeVideoThumbnailCGImage(at url: URL) async -> CGImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 560, height: 560)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        let previewTime = CMTime(seconds: 0.15, preferredTimescale: 600)
        if let result = try? await generator.image(at: previewTime) {
            return result.image
        }
        return (try? await generator.image(at: .zero))?.image
    }

    /// Копирование элемента истории в буфер обмена
    public func copyToClipboard(_ entry: HistoryEntry) {
        switch entry.kind {
        case .image:
            if let img = image(for: entry) {
                ImageExporter.copyToClipboard(img)
            }
        case .video:
            let url = fileURL(for: entry)
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([url as NSURL])
        }
    }

    /// Сохранение элемента истории через диалог «Сохранить как…»
    @discardableResult
    public func saveAs(_ entry: HistoryEntry) -> Bool {
        switch entry.kind {
        case .image:
            guard let img = image(for: entry) else { return false }
            return ImageExporter.saveImageWithDialog(img)
        case .video:
            let sourceURL = fileURL(for: entry)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else { return false }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.mpeg4Movie]
            panel.canCreateDirectories = true
            panel.directoryURL = ImageExporter.defaultSaveDirectoryURL()
            panel.nameFieldStringValue = sourceURL.lastPathComponent
            NSApp.activate()
            guard panel.runModal() == .OK, let destURL = panel.url else { return false }
            if destURL.standardizedFileURL == sourceURL.standardizedFileURL { return true }

            Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                let tempURL = destURL.deletingLastPathComponent()
                    .appendingPathComponent(".tmp-\(UUID().uuidString)-\(destURL.lastPathComponent)")
                do {
                    try fm.copyItem(at: sourceURL, to: tempURL)
                    _ = try fm.replaceItemAt(destURL, withItemAt: tempURL)
                } catch {
                    try? fm.removeItem(at: tempURL)
                    AppLogger.history.error("Failed to export history video copy: \(error.localizedDescription, privacy: .public)")
                }
            }
            return true
        }
    }

    public func delete(_ entry: HistoryEntry) {
        delete(id: entry.id)
    }

    public func delete(id: UUID) {
        pendingImageWrites.removeValue(forKey: id)?.task.cancel()
        inFlightThumbnails.removeValue(forKey: id)?.cancel()

        let matching = entries.filter { $0.id == id }
        entries.removeAll { $0.id == id }
        thumbnails.removeObject(forKey: id as NSUUID)

        if matching.isEmpty {
            let fallbackPNG = directory.appendingPathComponent("\(id.uuidString).png")
            Self.removeURLsInBackground([fallbackPNG])
        } else {
            let internalURLs = matching.filter { $0.externalFilePath == nil }.map { fileURL(for: $0) }
            let externalURLs = matching.filter { $0.externalFilePath != nil }.flatMap { externalFilesForEntry($0) }
            Self.removeURLsInBackground(internalURLs)
            Self.trashURLsInBackground(externalURLs)
        }
        saveIndex()
    }

    /// Удаление видео из истории и перемещение файла в Корзину
    public func deleteVideo(at videoURL: URL) {
        let targetPath = videoURL.standardizedFileURL.path
        let matching = entries.filter { fileURL(for: $0).standardizedFileURL.path == targetPath }
        if matching.isEmpty {
            let trackURL = CursorTrackRecorder.companionTrackURL(for: videoURL)
            let keysURL = KeystrokeTrackRecorder.companionTrackURL(for: videoURL)
            Self.trashURLsInBackground([videoURL, trackURL, keysURL])
        } else {
            for item in matching {
                delete(id: item.id)
            }
        }
    }

    /// Очистка истории: внутренние PNG удаляются, а внешние видеозаписи пользователя на диске НЕ затрагиваются
    public func clear() {
        for (_, pending) in pendingImageWrites {
            pending.task.cancel()
        }
        pendingImageWrites.removeAll()
        for (_, task) in inFlightThumbnails {
            task.cancel()
        }
        inFlightThumbnails.removeAll()

        let internalURLs = entries
            .filter { $0.externalFilePath == nil }
            .map { fileURL(for: $0) }
        Self.removeURLsInBackground(internalURLs)
        entries.removeAll()
        thumbnails.removeAllObjects()
        saveIndex()
    }

    private func externalFilesForEntry(_ entry: HistoryEntry) -> [URL] {
        let url = fileURL(for: entry)
        if entry.kind == .video {
            return [
                url,
                CursorTrackRecorder.companionTrackURL(for: url),
                KeystrokeTrackRecorder.companionTrackURL(for: url)
            ]
        }
        return [url]
    }

    private nonisolated static func removeURLsInBackground(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            for url in urls {
                try? fm.removeItem(at: url)
            }
        }
    }

    private nonisolated static func trashURLsInBackground(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            for url in urls where fm.fileExists(atPath: url.path) {
                do {
                    try fm.trashItem(at: url, resultingItemURL: nil)
                } catch {
                    AppLogger.history.error("Failed to trash file \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    public func revealInFinder(_ entry: HistoryEntry) {
        let url = fileURL(for: entry)
        guard FileManager.default.fileExists(atPath: url.path) else {
            pruneMissingFiles()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
