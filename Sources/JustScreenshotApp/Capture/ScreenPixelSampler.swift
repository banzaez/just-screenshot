import CoreGraphics
import Foundation

/// Быстрое чтение цвета пикселя (пипетка) из буфера CGImage захваченного экрана
public final class ScreenPixelSampler: @unchecked Sendable {
    private let pixelDataPtr: UnsafePointer<UInt8>?
    private let pixelBytesPerRow: Int
    private let pixelWidth: Int
    private let pixelHeight: Int
    private let retainedPixelData: CFData?
    
    public init(image: CGImage?) {
        if let img = image,
           let provider = img.dataProvider,
           let data = provider.data {
            self.retainedPixelData = data
            self.pixelDataPtr = CFDataGetBytePtr(data)
            self.pixelBytesPerRow = img.bytesPerRow
            self.pixelWidth = img.width
            self.pixelHeight = img.height
        } else {
            self.retainedPixelData = nil
            self.pixelDataPtr = nil
            self.pixelBytesPerRow = 0
            self.pixelWidth = 0
            self.pixelHeight = 0
        }
    }
    
    /// Возвращает HEX строку цвета пикселя (#RRGGBB) в координатах экрана
    public func getPixelHex(at screenPoint: CGPoint, viewBounds: CGRect) -> String? {
        guard let data = pixelDataPtr, pixelWidth > 0, pixelHeight > 0, viewBounds.width > 0, viewBounds.height > 0 else {
            return nil
        }
        
        let scaleX = CGFloat(pixelWidth) / viewBounds.width
        let scaleY = CGFloat(pixelHeight) / viewBounds.height
        
        let px = Int(screenPoint.x * scaleX)
        let py = Int(screenPoint.y * scaleY)
        
        guard px >= 0, px < pixelWidth, py >= 0, py < pixelHeight else { return nil }
        
        let offset = py * pixelBytesPerRow + px * 4
        let b = data[offset]
        let g = data[offset + 1]
        let r = data[offset + 2]
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
