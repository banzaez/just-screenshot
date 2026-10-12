import AppKit
import ImageIO

/// Запись истории снимков
public struct HistoryEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let width: Int
    public let height: Int
}

/// Хранилище истории: PNG-файлы + index.json в Application Support/JustScreenshot/History
@MainActor
public final class HistoryStore: ObservableObject {
    public static let shared = HistoryStore()
    
    @Published public private(set) var entries: [HistoryEntry] = []
    
    private let directory: URL
    private let indexURL: URL
    private let maxEntries = 300
    private let thumbnails = NSCache<NSUUID, NSImage>()
    
    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("JustScreenshot/History", isDirectory: true)
        indexURL = directory.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        thumbnails.countLimit = 200
        loadIndex()
    }
    
    public func fileURL(for entry: HistoryEntry) -> URL {
        directory.appendingPathComponent("\(entry.id.uuidString).png")
    }
    
    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded.filter { FileManager.default.fileExists(atPath: fileURL(for: $0).path) }
    }
    
    private func saveIndex() {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }
    
    /// Добавление снимка в историю (новые — в начале)
    @discardableResult
    public func add(_ image: NSImage, id: UUID = UUID()) -> HistoryEntry? {
        guard let png = ImageExporter.pngData(from: image) else { return nil }
        let entry = HistoryEntry(id: id, date: Date(), width: Int(image.size.width), height: Int(image.size.height))
        let url = fileURL(for: entry)
        do { try png.write(to: url) } catch { return nil }
        
        entries.removeAll { $0.id == id }
        entries.insert(entry, at: 0)
        
        while entries.count > maxEntries, let last = entries.popLast() {
            try? FileManager.default.removeItem(at: fileURL(for: last))
            thumbnails.removeObject(forKey: last.id as NSUUID)
        }
        saveIndex()
        return entry
    }
    
    /// Полное изображение для редактирования (размер в пунктах сохранён)
    public func image(for entry: HistoryEntry) -> NSImage? {
        guard let img = NSImage(contentsOf: fileURL(for: entry)) else { return nil }
        img.size = NSSize(width: entry.width, height: entry.height)
        return img
    }
    
    /// Быстрая миниатюра через ImageIO
    public func thumbnail(for entry: HistoryEntry) -> NSImage? {
        if let cached = thumbnails.object(forKey: entry.id as NSUUID) { return cached }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 560,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let src = CGImageSourceCreateWithURL(fileURL(for: entry) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        thumbnails.setObject(img, forKey: entry.id as NSUUID)
        return img
    }
    
    public func delete(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        thumbnails.removeObject(forKey: entry.id as NSUUID)
        try? FileManager.default.removeItem(at: fileURL(for: entry))
        saveIndex()
    }
    
    public func clear() {
        for e in entries { try? FileManager.default.removeItem(at: fileURL(for: e)) }
        entries.removeAll()
        thumbnails.removeAllObjects()
        saveIndex()
    }
    
    public func revealInFinder(_ entry: HistoryEntry) {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL(for: entry)])
    }
}
