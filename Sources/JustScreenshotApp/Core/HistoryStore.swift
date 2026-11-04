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

/// Хранилище истории: PNG-снимки, MP4-видеозаписи + index.json в Application Support/JustScreenshot/History
@Observable
@MainActor
public final class HistoryStore {
    public static let shared = HistoryStore()
    
    public private(set) var entries: [HistoryEntry] = []
    
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let indexURL: URL
    @ObservationIgnored private let maxEntries = 300
    @ObservationIgnored private let thumbnails = NSCache<NSUUID, NSImage>()
    @ObservationIgnored private var saveIndexTask: Task<Void, Never>?
    
    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("JustScreenshot/History", isDirectory: true)
        indexURL = directory.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        thumbnails.countLimit = 200
        thumbnails.totalCostLimit = 64 * 1024 * 1024 // 64 MB лимит для миниатюр
        loadIndex()
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
    
    /// Перепроверяет наличие файлов на диске (например, если видео было удалено из Finder)
    public func pruneMissingFiles() {
        let valid = entries.filter { FileManager.default.fileExists(atPath: fileURL(for: $0).path) }
        if valid.count != entries.count {
            entries = valid
            saveIndex()
        }
    }
    
    private func saveIndex() {
        let currentEntries = self.entries
        let url = self.indexURL
        saveIndexTask?.cancel()
        saveIndexTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            if let data = try? JSONEncoder().encode(currentEntries) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
    
    /// Добавление снимка в историю (новые — в начале) с фоновым кодированием PNG и записью на диск
    @discardableResult
    public func add(_ image: NSImage, id: UUID = UUID()) -> HistoryEntry? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let entry = HistoryEntry(
            id: id,
            date: Date(),
            width: Int(image.size.width),
            height: Int(image.size.height),
            kind: .image
        )
        let url = fileURL(for: entry)
        
        // Кэшируем легковесную миниатюру (<0.5 МБ вместо 40-60 МБ оригинала в RAM)
        let thumb = Self.makeThumbnail(from: cgImage)
        let cost = max(1, Int(thumb.size.width * thumb.size.height * 4))
        thumbnails.setObject(thumb, forKey: id as NSUUID, cost: cost)
        
        // Фоновое кодирование PNG и запись файла без блокировки MainActor UI
        Task.detached(priority: .utility) {
            if let png = ImageExporter.pngData(from: cgImage) {
                try? png.write(to: url, options: .atomic)
            }
        }
        
        insertAndTrim(entry)
        return entry
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
        // Если запись с таким путём уже есть — обновляем её
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
            let lastURL = fileURL(for: last)
            let isInternal = last.externalFilePath == nil
            thumbnails.removeObject(forKey: last.id as NSUUID)
            if isInternal {
                Task.detached(priority: .utility) {
                    try? FileManager.default.removeItem(at: lastURL)
                }
            }
        }
        saveIndex()
    }
    
    /// Полное изображение для редактирования (размер в пунктах сохранён)
    public func image(for entry: HistoryEntry) -> NSImage? {
        guard entry.kind == .image else { return nil }
        guard let img = NSImage(contentsOf: fileURL(for: entry)) else { return nil }
        img.size = NSSize(width: entry.width, height: entry.height)
        return img
    }
    
    /// Мгновенное получение уже закэшированной в памяти миниатюры без I/O и задержек
    public func cachedThumbnail(for entry: HistoryEntry) -> NSImage? {
        thumbnails.object(forKey: entry.id as NSUUID)
    }
    
    /// Синхронная миниатюра через ImageIO / AVAssetImageGenerator
    public func thumbnail(for entry: HistoryEntry) -> NSImage? {
        if let cached = thumbnails.object(forKey: entry.id as NSUUID) { return cached }
        let url = fileURL(for: entry)
        let cg = entry.kind == .video
            ? Self.decodeVideoThumbnailCGImage(at: url)
            : Self.decodeThumbnailCGImage(at: url)
        guard let cg else { return nil }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        let cost = max(1, Int(cg.width * cg.height * 4))
        thumbnails.setObject(img, forKey: entry.id as NSUUID, cost: cost)
        return img
    }
    
    /// Асинхронная загрузка миниатюры вне MainActor
    public func thumbnailAsync(for entry: HistoryEntry) async -> NSImage? {
        if let cached = thumbnails.object(forKey: entry.id as NSUUID) { return cached }
        let url = fileURL(for: entry)
        let kind = entry.kind
        guard let cg = await Task.detached(priority: .userInitiated, operation: {
            kind == .video
                ? Self.decodeVideoThumbnailCGImage(at: url)
                : Self.decodeThumbnailCGImage(at: url)
        }).value else {
            return nil
        }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        let cost = max(1, Int(cg.width * cg.height * 4))
        thumbnails.setObject(img, forKey: entry.id as NSUUID, cost: cost)
        return img
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
        let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
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
    
    nonisolated private static func decodeVideoThumbnailCGImage(at url: URL) -> CGImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 560, height: 560)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        let previewTime = CMTime(seconds: 0.15, preferredTimescale: 600)
        if let cg = try? generator.copyCGImage(at: previewTime, actualTime: nil) {
            return cg
        }
        return try? generator.copyCGImage(at: .zero, actualTime: nil)
    }
    
    /// Копирование элемента истории в буфер обмена (NSImage для фото, файловый URL для видео)
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
            panel.nameFieldStringValue = sourceURL.lastPathComponent
            NSApp.activate(ignoringOtherApps: true)
            guard panel.runModal() == .OK, let destURL = panel.url else { return false }
            if destURL.standardizedFileURL == sourceURL.standardizedFileURL { return true }
            try? FileManager.default.removeItem(at: destURL)
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                return true
            } catch {
                return false
            }
        }
    }
    
    public func delete(_ entry: HistoryEntry) {
        delete(id: entry.id)
    }
    
    public func delete(id: UUID) {
        let matching = entries.filter { $0.id == id }
        entries.removeAll { $0.id == id }
        thumbnails.removeObject(forKey: id as NSUUID)
        
        if matching.isEmpty {
            let fallbackPNG = directory.appendingPathComponent("\(id.uuidString).png")
            try? FileManager.default.removeItem(at: fallbackPNG)
        } else {
            for item in matching {
                removeFiles(for: item)
            }
        }
        saveIndex()
    }
    
    /// Удаление видео из истории и с диска по URL файла
    public func deleteVideo(at videoURL: URL) {
        let targetPath = videoURL.standardizedFileURL.path
        let matching = entries.filter { fileURL(for: $0).standardizedFileURL.path == targetPath }
        if matching.isEmpty {
            try? FileManager.default.removeItem(at: videoURL)
            let trackURL = videoURL.deletingPathExtension().appendingPathExtension("track.json")
            try? FileManager.default.removeItem(at: trackURL)
        } else {
            for item in matching {
                delete(id: item.id)
            }
        }
    }
    
    public func clear() {
        for e in entries {
            removeFiles(for: e)
        }
        entries.removeAll()
        thumbnails.removeAllObjects()
        saveIndex()
    }
    
    private func removeFiles(for entry: HistoryEntry) {
        let url = fileURL(for: entry)
        try? FileManager.default.removeItem(at: url)
        if entry.kind == .video {
            let trackURL = url.deletingPathExtension().appendingPathExtension("track.json")
            try? FileManager.default.removeItem(at: trackURL)
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
