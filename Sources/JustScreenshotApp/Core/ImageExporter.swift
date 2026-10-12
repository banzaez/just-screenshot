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
    
    /// PNG-данные изображения
    public static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
    
    /// Запись NSImage в PNG файл по URL
    public static func saveImage(_ image: NSImage, to url: URL) {
        guard let png = pngData(from: image) else { return }
        try? png.write(to: url)
    }
    
    /// Копирование NSImage в буфер обмена
    public static func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    /// Копирование текста в буфер обмена
    public static func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    /// Сохранение временного PNG файла для передачи в Drag & Drop
    public static func saveTemporaryPNG(_ image: NSImage, filename: String = "Screenshot") -> URL? {
        guard let data = pngData(from: image) else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename)-\(UUID().uuidString.prefix(8)).png")
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
}
