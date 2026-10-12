import AppKit
import CoreImage

/// Предварительно размытая копия изображения для инструмента «Размытие»
public enum BlurFilter {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])
    
    /// Сильное гауссово размытие всего изображения (размер в пунктах сохраняется)
    public static func makeBlurred(_ image: NSImage) -> NSImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let input = CIImage(cgImage: cg)
        // Радиус зависит от размера снимка, чтобы текст точно нечитаем
        let radius = max(10.0, Double(min(cg.width, cg.height)) / 70.0)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: input.extent),
              let result = context.createCGImage(output, from: input.extent) else { return nil }
        return NSImage(cgImage: result, size: image.size)
    }
}
