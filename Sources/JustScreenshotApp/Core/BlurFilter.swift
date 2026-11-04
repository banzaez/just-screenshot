import AppKit
import CoreImage

/// Предварительно размытая копия изображения для инструмента «Размытие»
public enum BlurFilter {
    nonisolated private static let context = CIContext(options: [.useSoftwareRenderer: false])
    // NSCache потокобезопасен; nonisolated(unsafe) — для Swift 6 Sendable-проверки
    nonisolated(unsafe) private static let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 6
        c.totalCostLimit = 128 * 1024 * 1024 // 128 MB лимит памяти
        return c
    }()
    
    /// Сильное гауссово размытие (можно вызывать вне MainActor)
    nonisolated public static func makeBlurred(_ image: NSImage, id: UUID? = nil) -> NSImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let key = cacheKey(for: cg, size: image.size, id: id)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let input = CIImage(cgImage: cg)
        let radius = max(10.0, Double(min(cg.width, cg.height)) / 70.0)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: input.extent),
              let result = context.createCGImage(output, from: input.extent) else { return nil }
        let blurred = NSImage(cgImage: result, size: image.size)
        let cost = max(1, result.width * result.height * 4)
        cache.setObject(blurred, forKey: key, cost: cost)
        return blurred
    }
    
    nonisolated public static func makeBlurredAsync(_ image: NSImage, id: UUID? = nil) async -> NSImage? {
        await Task.detached(priority: .userInitiated) {
            makeBlurred(image, id: id)
        }.value
    }
    
    nonisolated private static func cacheKey(for cgImage: CGImage, size: NSSize, id: UUID?) -> NSString {
        if let id {
            return "\(id.uuidString)-\(cgImage.width)x\(cgImage.height)" as NSString
        }
        let cgHash = CFHash(cgImage)
        return "cg-\(cgHash)-\(cgImage.width)x\(cgImage.height)-\(Int(size.width))x\(Int(size.height))" as NSString
    }
}
