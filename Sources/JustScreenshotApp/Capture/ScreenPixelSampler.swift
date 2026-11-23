import CoreGraphics
import Foundation

/// Быстрое чтение цвета пикселя (пипетка) из буфера CGImage захваченного экрана
public final class ScreenPixelSampler: @unchecked Sendable {
    private let pixelDataPtr: UnsafePointer<UInt8>?
    private let pixelDataLength: Int
    private let pixelBytesPerRow: Int
    private let pixelBytesPerPixel: Int
    private let pixelWidth: Int
    private let pixelHeight: Int
    private let rIndex: Int
    private let gIndex: Int
    private let bIndex: Int
    private let retainedPixelData: CFData?

    public init(image: CGImage?) {
        guard let img = image,
              img.bitsPerComponent == 8,
              img.bitsPerPixel >= 24,
              img.width > 0,
              img.height > 0,
              let provider = img.dataProvider,
              let data = provider.data else {
            self.retainedPixelData = nil
            self.pixelDataPtr = nil
            self.pixelDataLength = 0
            self.pixelBytesPerRow = 0
            self.pixelBytesPerPixel = 4
            self.pixelWidth = 0
            self.pixelHeight = 0
            self.rIndex = 2
            self.gIndex = 1
            self.bIndex = 0
            return
        }

        let bytesPerPixel = max(3, img.bitsPerPixel / 8)
        let bytesPerRow = img.bytesPerRow
        let dataLength = CFDataGetLength(data)

        let byteOrder = CGImageByteOrderInfo(rawValue: img.bitmapInfo.rawValue & CGImageByteOrderInfo.orderMask.rawValue) ?? .orderDefault
        let alphaInfo = CGImageAlphaInfo(rawValue: img.bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue) ?? .noneSkipFirst
        let isLittleEndian = (byteOrder == .order32Little)

        let rIdx: Int
        let gIdx: Int
        let bIdx: Int

        if bytesPerPixel == 3 {
            if isLittleEndian {
                bIdx = 0; gIdx = 1; rIdx = 2
            } else {
                rIdx = 0; gIdx = 1; bIdx = 2
            }
        } else {
            switch alphaInfo {
            case .premultipliedFirst, .first, .noneSkipFirst:
                // 32Little + First = BGRA в памяти; 32Big/Default + First = ARGB в памяти
                if isLittleEndian {
                    bIdx = 0; gIdx = 1; rIdx = 2
                } else {
                    rIdx = 1; gIdx = 2; bIdx = 3
                }
            case .premultipliedLast, .last, .noneSkipLast:
                // 32Little + Last = ABGR в памяти; 32Big/Default + Last = RGBA в памяти
                if isLittleEndian {
                    bIdx = 1; gIdx = 2; rIdx = 3
                } else {
                    rIdx = 0; gIdx = 1; bIdx = 2
                }
            default:
                if isLittleEndian {
                    bIdx = 0; gIdx = 1; rIdx = 2
                } else {
                    rIdx = 0; gIdx = 1; bIdx = 2
                }
            }
        }

        let maxChannelIdx = max(rIdx, max(gIdx, bIdx))
        let requiredRowBytes = img.width * bytesPerPixel
        let minRequiredLength = (img.height - 1) * bytesPerRow + requiredRowBytes

        guard bytesPerRow >= requiredRowBytes,
              maxChannelIdx < bytesPerPixel,
              dataLength >= minRequiredLength,
              let ptr = CFDataGetBytePtr(data) else {
            self.retainedPixelData = nil
            self.pixelDataPtr = nil
            self.pixelDataLength = 0
            self.pixelBytesPerRow = 0
            self.pixelBytesPerPixel = 4
            self.pixelWidth = 0
            self.pixelHeight = 0
            self.rIndex = 2
            self.gIndex = 1
            self.bIndex = 0
            return
        }

        self.retainedPixelData = data
        self.pixelDataPtr = ptr
        self.pixelDataLength = dataLength
        self.pixelBytesPerRow = bytesPerRow
        self.pixelBytesPerPixel = bytesPerPixel
        self.pixelWidth = img.width
        self.pixelHeight = img.height
        self.rIndex = rIdx
        self.gIndex = gIdx
        self.bIndex = bIdx
    }

    public struct PixelSample: Sendable {
        public let hex: String
        public let r: UInt8
        public let g: UInt8
        public let b: UInt8

        public var cgColor: CGColor {
            CGColor(
                srgbRed: CGFloat(r) / 255.0,
                green: CGFloat(g) / 255.0,
                blue: CGFloat(b) / 255.0,
                alpha: 1.0
            )
        }
    }

    private func pixelCoordinates(at screenPoint: CGPoint, viewBounds: CGRect) -> (x: Int, y: Int)? {
        guard pixelDataPtr != nil,
              pixelWidth > 0,
              pixelHeight > 0,
              viewBounds.width > 0,
              viewBounds.height > 0 else {
            return nil
        }

        let relX = screenPoint.x - viewBounds.origin.x
        let relY = screenPoint.y - viewBounds.origin.y
        guard relX >= 0, relX <= viewBounds.width, relY >= 0, relY <= viewBounds.height else {
            return nil
        }

        let scaleX = CGFloat(pixelWidth) / viewBounds.width
        let scaleY = CGFloat(pixelHeight) / viewBounds.height

        let px = min(pixelWidth - 1, max(0, Int(relX * scaleX)))
        let py = min(pixelHeight - 1, max(0, Int(relY * scaleY)))
        return (px, py)
    }

    private func rgbComponents(atX px: Int, y py: Int) -> (r: UInt8, g: UInt8, b: UInt8)? {
        guard let data = pixelDataPtr,
              px >= 0, px < pixelWidth,
              py >= 0, py < pixelHeight else {
            return nil
        }
        let offset = py * pixelBytesPerRow + px * pixelBytesPerPixel
        let maxIdx = max(rIndex, max(gIndex, bIndex))
        guard offset >= 0, offset + maxIdx < pixelDataLength else { return nil }
        return (data[offset + rIndex], data[offset + gIndex], data[offset + bIndex])
    }

    /// Возвращает HEX строку и компоненты цвета пикселя в координатах viewBounds
    public func getPixelSample(at screenPoint: CGPoint, viewBounds: CGRect) -> PixelSample? {
        guard let coords = pixelCoordinates(at: screenPoint, viewBounds: viewBounds),
              let rgb = rgbComponents(atX: coords.x, y: coords.y) else {
            return nil
        }
        let hex = String(format: "#%02X%02X%02X", rgb.r, rgb.g, rgb.b)
        return PixelSample(hex: hex, r: rgb.r, g: rgb.g, b: rgb.b)
    }

    /// Возвращает HEX строку цвета пикселя (#RRGGBB) в координатах viewBounds
    public func getPixelHex(at screenPoint: CGPoint, viewBounds: CGRect) -> String? {
        getPixelSample(at: screenPoint, viewBounds: viewBounds)?.hex
    }

    /// Формирует квадратное изображение (2*gridRadius + 1)x(2*gridRadius + 1) вокруг пикселя для лупы
    public func makeLoupeImage(at screenPoint: CGPoint, viewBounds: CGRect, gridRadius: Int = 7) -> CGImage? {
        guard gridRadius >= 1,
              let center = pixelCoordinates(at: screenPoint, viewBounds: viewBounds) else {
            return nil
        }

        let side = gridRadius * 2 + 1
        let bytesPerRow = side * 4
        var rgba = [UInt8](repeating: 255, count: side * bytesPerRow)

        for dy in -gridRadius...gridRadius {
            let py = center.y + dy
            let rowOffset = (dy + gridRadius) * bytesPerRow
            for dx in -gridRadius...gridRadius {
                let px = center.x + dx
                let dstIdx = rowOffset + (dx + gridRadius) * 4
                if let rgb = rgbComponents(atX: px, y: py) {
                    rgba[dstIdx] = rgb.r
                    rgba[dstIdx + 1] = rgb.g
                    rgba[dstIdx + 2] = rgb.b
                } else {
                    rgba[dstIdx] = 24
                    rgba[dstIdx + 1] = 24
                    rgba[dstIdx + 2] = 24
                }
            }
        }

        let cfData = Data(rgba) as CFData
        guard let provider = CGDataProvider(data: cfData) else { return nil }
        return CGImage(
            width: side,
            height: side,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
