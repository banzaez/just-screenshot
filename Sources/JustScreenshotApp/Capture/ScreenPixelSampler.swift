import CoreGraphics
import Foundation

/// Быстрое чтение цвета пикселя (пипетка) из буфера CGImage захваченного экрана
public final class ScreenPixelSampler: @unchecked Sendable {
    private let pixelDataPtr: UnsafePointer<UInt8>?
    private let pixelBytesPerRow: Int
    private let pixelBytesPerPixel: Int
    private let pixelWidth: Int
    private let pixelHeight: Int
    private let rIndex: Int
    private let gIndex: Int
    private let bIndex: Int
    private let retainedPixelData: CFData?
    
    public init(image: CGImage?) {
        if let img = image,
           img.bitsPerComponent == 8,
           img.bitsPerPixel >= 24,
           let provider = img.dataProvider,
           let data = provider.data {
            self.retainedPixelData = data
            self.pixelDataPtr = CFDataGetBytePtr(data)
            self.pixelBytesPerRow = img.bytesPerRow
            self.pixelBytesPerPixel = max(3, img.bitsPerPixel / 8)
            self.pixelWidth = img.width
            self.pixelHeight = img.height
            
            let byteOrder = CGImageByteOrderInfo(rawValue: img.bitmapInfo.rawValue & CGImageByteOrderInfo.orderMask.rawValue) ?? .orderDefault
            let alphaInfo = CGImageAlphaInfo(rawValue: img.bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue) ?? .noneSkipFirst
            
            let isLittleEndian = (byteOrder == .order32Little || byteOrder == .order16Little)
            switch alphaInfo {
            case .premultipliedFirst, .first, .noneSkipFirst:
                // 32Little + First = BGRA в памяти; 32Big/Default + First = ARGB в памяти
                if isLittleEndian {
                    self.bIndex = 0; self.gIndex = 1; self.rIndex = 2
                } else {
                    self.rIndex = 1; self.gIndex = 2; self.bIndex = 3
                }
            case .premultipliedLast, .last, .noneSkipLast:
                // 32Little + Last = ABGR в памяти; 32Big/Default + Last = RGBA в памяти
                if isLittleEndian {
                    self.bIndex = 1; self.gIndex = 2; self.rIndex = 3
                } else {
                    self.rIndex = 0; self.gIndex = 1; self.bIndex = 2
                }
            default:
                if isLittleEndian {
                    self.bIndex = 0; self.gIndex = 1; self.rIndex = 2
                } else {
                    self.rIndex = 0; self.gIndex = 1; self.bIndex = 2
                }
            }
        } else {
            self.retainedPixelData = nil
            self.pixelDataPtr = nil
            self.pixelBytesPerRow = 0
            self.pixelBytesPerPixel = 4
            self.pixelWidth = 0
            self.pixelHeight = 0
            self.rIndex = 2
            self.gIndex = 1
            self.bIndex = 0
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
        
        let offset = py * pixelBytesPerRow + px * pixelBytesPerPixel
        let r = data[offset + rIndex]
        let g = data[offset + gIndex]
        let b = data[offset + bIndex]
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
