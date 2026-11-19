import Cocoa
import UniformTypeIdentifiers

/// Утилиты для работы с изображениями и буфером обмена
public enum ImageExporter {
    @MainActor private static var lastDragCleanupDate: Date = .distantPast

    /// Возвращает настроенную папку сохранения по умолчанию, если она существует на диске
    @MainActor
    public static func defaultSaveDirectoryURL() -> URL? {
        let customPath = AppSettings.shared.defaultSaveDirectoryPath
        var isDir: ObjCBool = false
        if !customPath.isEmpty,
           FileManager.default.fileExists(atPath: customPath, isDirectory: &isDir),
           isDir.boolValue {
            return URL(fileURLWithPath: customPath, isDirectory: true)
        }
        return nil
    }

    /// Сохранение изображения через нативный NSSavePanel. Возвращает true, если файл успешно записан
    @MainActor
    @discardableResult
    public static func saveImageWithDialog(_ image: NSImage, defaultName: String = "Screenshot") -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.directoryURL = defaultSaveDirectoryURL()
        panel.nameFieldStringValue = "\(defaultName)-\(Int(Date().timeIntervalSince1970)).png"

        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }
        guard saveImage(image, to: url) else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L("video_editor.export_error")
            alert.informativeText = url.lastPathComponent
            alert.addButton(withTitle: L("alert.ok"))
            alert.runModal()
            return false
        }
        return true
    }

    /// Извлечение максимального по разрешению CGImage из NSImage
    @MainActor
    public static func cgImage(from image: NSImage) -> CGImage? {
        var bestCG: CGImage?
        var bestPixels = 0
        for rep in image.representations {
            if let bitmapRep = rep as? NSBitmapImageRep, let cg = bitmapRep.cgImage {
                let area = cg.width * cg.height
                if area > bestPixels {
                    bestPixels = area
                    bestCG = cg
                }
            }
        }
        if let bestCG {
            return bestCG
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    /// PNG-данные изображения (напрямую через ImageIO / CGImageDestination)
    @MainActor
    public static func pngData(from image: NSImage) -> Data? {
        guard let cgImage = cgImage(from: image) else {
            return nil
        }
        return pngData(from: cgImage)
    }

    /// Потокобезопасное кодирование CGImage в PNG (можно вызывать вне MainActor)
    nonisolated public static func pngData(from cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }

    /// Атомарная запись NSImage в PNG файл по URL
    @MainActor
    @discardableResult
    public static func saveImage(_ image: NSImage, to url: URL) -> Bool {
        guard let png = pngData(from: image) else {
            AppLogger.export.error("Failed to encode PNG for \(url.path, privacy: .public)")
            return false
        }
        do {
            try png.write(to: url, options: .atomic)
            return true
        } catch {
            AppLogger.export.error("Failed to save PNG to \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Копирование NSImage в буфер обмена в формате PNG
    @MainActor
    public static func copyToClipboard(_ image: NSImage) {
        if let png = pngData(from: image) {
            copyToClipboard(pngData: png)
        } else {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        }
    }

    /// Копирование уже готовых PNG-данных в буфер обмена без повторного кодирования
    @MainActor
    public static func copyToClipboard(pngData: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setData(pngData, forType: .png)
        pasteboard.writeObjects([item])
    }

    /// Копирование текста в буфер обмена
    @MainActor
    public static func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Асинхронный NSItemProvider для Drag & Drop без блокировки главного потока
    @MainActor
    public static func makeDragItemProvider(for image: NSImage, filename: String = "Screenshot") -> NSItemProvider {
        guard let cgImage = cgImage(from: image) else {
            return NSItemProvider(object: image)
        }
        scheduleDragTempCleanupIfNeeded()
        let provider = NSItemProvider()
        provider.suggestedName = filename
        provider.registerFileRepresentation(
            forTypeIdentifier: UTType.png.identifier,
            fileOptions: [],
            visibility: .all
        ) { completion in
            Task.detached(priority: .userInitiated) {
                guard let png = Self.pngData(from: cgImage) else {
                    completion(nil, false, CocoaError(.fileWriteUnknown))
                    return
                }
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("JustScreenshotDrag", isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    let fileURL = tempDir.appendingPathComponent("\(filename)-\(UUID().uuidString.prefix(8)).png")
                    try png.write(to: fileURL, options: .atomic)
                    completion(fileURL, false, nil)
                } catch {
                    completion(nil, false, error)
                }
            }
            return nil
        }
        return provider
    }

    /// Сохранение временного PNG файла (синхронный фолбэк при необходимости)
    @MainActor
    public static func saveTemporaryPNG(_ image: NSImage, filename: String = "Screenshot") -> URL? {
        guard let data = pngData(from: image) else { return nil }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("JustScreenshotDrag", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        scheduleDragTempCleanupIfNeeded()

        let fileURL = tempDir.appendingPathComponent("\(filename)-\(UUID().uuidString.prefix(8)).png")
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            AppLogger.export.error("Failed to write temporary PNG: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    @MainActor
    private static func scheduleDragTempCleanupIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastDragCleanupDate) >= 600 else { return }
        lastDragCleanupDate = now
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("JustScreenshotDrag", isDirectory: true)
        Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            if let urls = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey]) {
                let hourAgo = Date().addingTimeInterval(-3600)
                for url in urls {
                    if let values = try? url.resourceValues(forKeys: [.creationDateKey]),
                       let date = values.creationDate, date < hourAgo {
                        try? fileManager.removeItem(at: url)
                    }
                }
            }
        }
    }
}
