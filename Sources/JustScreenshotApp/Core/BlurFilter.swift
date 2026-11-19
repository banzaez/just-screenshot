import AppKit
import CoreImage

/// Предварительно размытая копия изображения для инструмента «Размытие»
public enum BlurFilter {
    nonisolated private static let context = CIContext(options: [.useSoftwareRenderer: false])
    // NSCache потокобезопасен; кэшируем только thread-safe CGImage (не NSImage)
    nonisolated(unsafe) private static let cache: NSCache<NSString, CGImage> = {
        let c = NSCache<NSString, CGImage>()
        c.countLimit = 8
        c.totalCostLimit = 128 * 1024 * 1024 // 128 MB лимит памяти
        return c
    }()

    /// Формирует детерминированный ключ кэша без pointer hash
    nonisolated public static func cacheKey(id: UUID, revision: Int, pixelWidth: Int, pixelHeight: Int) -> String {
        "\(id.uuidString)-rev\(revision)-\(pixelWidth)x\(pixelHeight)"
    }

    /// Потокобезопасное гауссово размытие CGImage
    nonisolated public static func makeBlurredCGImage(
        from cgImage: CGImage,
        radius: Double? = nil,
        cacheKey: String? = nil
    ) -> CGImage? {
        if let cacheKey, let cached = cache.object(forKey: cacheKey as NSString) {
            return cached
        }
        let input = CIImage(cgImage: cgImage)
        let blurRadius = radius ?? max(10.0, Double(min(cgImage.width, cgImage.height)) / 70.0)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(blurRadius, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: input.extent),
              let result = context.createCGImage(output, from: input.extent) else {
            return nil
        }
        if let cacheKey {
            let cost = max(1, result.width * result.height * 4)
            cache.setObject(result, forKey: cacheKey as NSString, cost: cost)
        }
        return result
    }

    /// Синхронное получение размытого NSImage (вызывать с MainActor)
    @MainActor
    public static func makeBlurred(_ image: NSImage, id: UUID? = nil, revision: Int = 0) -> NSImage? {
        guard let cg = ImageExporter.cgImage(from: image) else { return nil }
        let key = id.map { cacheKey(id: $0, revision: revision, pixelWidth: cg.width, pixelHeight: cg.height) }
        guard let result = makeBlurredCGImage(from: cg, cacheKey: key) else { return nil }
        return NSImage(cgImage: result, size: image.size)
    }

    /// Асинхронное получение размытого NSImage (CGImage извлекается на MainActor до ухода в фон)
    @MainActor
    public static func makeBlurredAsync(_ image: NSImage, id: UUID? = nil, revision: Int = 0) async -> NSImage? {
        guard let cg = ImageExporter.cgImage(from: image) else { return nil }
        let pointSize = image.size
        let key = id.map { cacheKey(id: $0, revision: revision, pixelWidth: cg.width, pixelHeight: cg.height) }
        let blurredCG = await Task.detached(priority: .userInitiated) {
            makeBlurredCGImage(from: cg, cacheKey: key)
        }.value
        guard !Task.isCancelled, let blurredCG else { return nil }
        return NSImage(cgImage: blurredCG, size: pointSize)
    }
}
