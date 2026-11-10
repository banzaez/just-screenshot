import Cocoa

/// Утилиты для работы с изображениями и буфером обмена
public enum ImageExporter {
    
    /// Сохранение изображения через нативный NSSavePanel. Возвращает true, если файл записан
    @MainActor
    @discardableResult
    public static func saveImageWithDialog(_ image: NSImage, defaultName: String = "Screenshot") -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(defaultName)-\(Int(Date().timeIntervalSince1970)).png"
        
        if panel.runModal() == .OK, let url = panel.url {
            saveImage(image, to: url)
            return true
        }
        return false
    }
    
    /// Извлечение максимального по разрешению CGImage из NSImage
    public static func cgImage(from image: NSImage) -> CGImage? {
        for rep in image.representations {
            if let bitmapRep = rep as? NSBitmapImageRep, let cg = bitmapRep.cgImage {
                return cg
            }
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    /// PNG-данные изображения (напрямую через ImageIO / CGImageDestination без промежуточного TIFF-буфера)
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
    
    /// Запись NSImage в PNG файл по URL
    public static func saveImage(_ image: NSImage, to url: URL) {
        guard let png = pngData(from: image) else { return }
        try? png.write(to: url)
    }
    
    /// Копирование NSImage в буфер обмена с сохранением максимального Retina-разрешения (PNG + TIFF)
    public static func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        let item = NSPasteboardItem()
        var hasData = false
        if let png = pngData(from: image) {
            item.setData(png, forType: .png)
            item.setData(png, forType: NSPasteboard.PasteboardType("public.png"))
            hasData = true
        }
        if let tiff = image.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
            hasData = true
        }
        
        if hasData {
            pasteboard.writeObjects([item])
        } else {
            pasteboard.writeObjects([image])
        }
    }
    
    /// Копирование текста в буфер обмена
    public static func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    /// Сохранение временного PNG файла для передачи в Drag & Drop с очисткой устаревших файлов
    public static func saveTemporaryPNG(_ image: NSImage, filename: String = "Screenshot") -> URL? {
        guard let data = pngData(from: image) else { return nil }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("JustScreenshotDrag", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Очистка старых временных файлов снимков (> 1 часа) в изолированной директории
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
        
        let fileURL = tempDir.appendingPathComponent("\(filename)-\(UUID().uuidString.prefix(8)).png")
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
}
