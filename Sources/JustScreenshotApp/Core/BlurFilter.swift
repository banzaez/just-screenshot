import AppKit
import CoreImage

/// Предварительно размытая копия изображения для инструмента «Размытие»
public enum BlurFilter {
    nonisolated private static let context = CIContext(options: [.useSoftwareRenderer: false])
    // NSCache потокобезопасен; nonisolated(unsafe) — для Swift 6 Sendable-проверки
    nonisolated(unsafe) private static let cache = NSCache<NSString, NSImage>()
    
    /// Сильное гауссово размытие (можно вызывать вне MainActor)
    nonisolated public static func makeBlurred(_ image: NSImage) -> NSImage? {
        let cacheKey = cacheKey(for: image)
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let input = CIImage(cgImage: cg)
        let radius = max(10.0, Double(min(cg.width, cg.height)) / 70.0)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: input.extent),
              let result = context.createCGImage(output, from: input.extent) else { return nil }
        let blurred = NSImage(cgImage: result, size: image.size)
        cache.setObject(blurred, forKey: cacheKey)
        return blurred
    }
    
    nonisolated public static func makeBlurredAsync(_ image: NSImage) async -> NSImage? {
        await Task.detached(priority: .userInitiated) {
            makeBlurred(image)
        }.value
    }
    
    nonisolated private static func cacheKey(for image: NSImage) -> NSString {
        let size = image.size
        let ptr = Unmanaged.passUnretained(image).toOpaque()
        return "\(ptr)-\(Int(size.width))x\(Int(size.height))" as NSString
    }
}
