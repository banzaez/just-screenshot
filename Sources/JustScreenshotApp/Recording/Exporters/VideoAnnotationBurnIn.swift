import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation

/// Плоский снимок аннотации для экспорта (без SwiftUI Color)
public struct BurnInAnnotation: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case blur
    }

    public var kind: Kind
    public var rect: CGRect // нормализованные [0...1], top-left origin
    public var rotationAngle: Double

    nonisolated public static func from(_ items: [VideoAnnotationItem]) -> [BurnInAnnotation] {
        items.map { item in
            let kind: Kind
            switch item.type {
            case .blur: kind = .blur
            }
            return BurnInAnnotation(
                kind: kind,
                rect: item.rect,
                rotationAngle: item.rotationAngle
            )
        }
    }
}

public enum VideoExportError: LocalizedError, Sendable {
    case videoTrackNotFound
    case compositionTrackFailed
    case invalidTrimRange
    case exportSessionCreationFailed
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .videoTrackNotFound:
            return "Video track not found."
        case .compositionTrackFailed:
            return "Failed to create composition video track."
        case .invalidTrimRange:
            return "Trim range is empty or invalid."
        case .exportSessionCreationFailed:
            return "Failed to create export session."
        case .exportFailed(let message):
            return message
        }
    }
}

/// Безопасная запись экспорта во временный соседний файл с атомарной заменой целевого URL
enum VideoExportFileHelper {
    static func withTemporaryDestination(
        for destinationURL: URL,
        operation: (URL) async throws -> Void
    ) async throws {
        let fm = FileManager.default
        let parentDir = destinationURL.deletingLastPathComponent()
        try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let ext = destinationURL.pathExtension
        let tempName = ".justscreenshot-export-\(UUID().uuidString)\(ext.isEmpty ? "" : ".\(ext)")"
        let tempURL = parentDir.appendingPathComponent(tempName)
        defer {
            try? fm.removeItem(at: tempURL)
        }

        try await operation(tempURL)

        guard fm.fileExists(atPath: tempURL.path) else {
            throw VideoExportError.exportFailed("Export output file was not created.")
        }

        if fm.fileExists(atPath: destinationURL.path) {
            _ = try fm.replaceItemAt(
                destinationURL,
                withItemAt: tempURL,
                backupItemName: nil,
                options: .usingNewMetadataOnly
            )
        } else {
            try fm.moveItem(at: tempURL, to: destinationURL)
        }
    }
}

/// Единый CoreImage-конвейер обработки видеокадров (размытие аннотаций, Smart Zoom, кадрирование, даунскейл)
enum VideoAnnotationBurnIn {
    static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private static let srgbColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Размер видеокадра с учетом orientation/preferredTransform дорожки
    nonisolated static func displaySize(naturalSize: CGSize, preferredTransform: CGAffineTransform) -> CGSize {
        let transformed = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }

    /// Преобразует буфер в координаты CoreImage (bottom-left origin) с учетом `preferredTransform` дорожки
    nonisolated static func orientingTransform(naturalSize: CGSize, preferredTransform: CGAffineTransform) -> CGAffineTransform {
        let transformedBounds = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let topCentered = preferredTransform.concatenating(
            CGAffineTransform(translationX: -transformedBounds.origin.x, y: -transformedBounds.origin.y)
        )
        let toTopLeft = CGAffineTransform(scaleX: 1, y: -1)
            .concatenating(CGAffineTransform(translationX: 0, y: naturalSize.height))
        let backToBottomLeft = CGAffineTransform(scaleX: 1, y: -1)
            .concatenating(CGAffineTransform(translationX: 0, y: abs(transformedBounds.height)))
        return toTopLeft.concatenating(topCentered).concatenating(backToBottomLeft)
    }

    /// Предварительно строит статичную grayscale-маску для всех blur-аннотаций в координатах ориентированного кадра
    nonisolated static func makeBlurMask(annotations: [BurnInAnnotation], frameSize: CGSize) -> CIImage? {
        let blurItems = annotations.filter { $0.kind == .blur }
        guard !blurItems.isEmpty, frameSize.width > 0, frameSize.height > 0 else { return nil }

        let width = max(1, Int(frameSize.width.rounded()))
        let height = max(1, Int(frameSize.height.rounded()))
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        ctx.setFillColor(gray: 0.0, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Переводим CGContext в top-left origin, чтобы совпасть с normalized rect и SwiftUI rotationEffect
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.setFillColor(gray: 1.0, alpha: 1.0)

        for item in blurItems {
            let w = max(1, item.rect.width * CGFloat(width))
            let h = max(1, item.rect.height * CGFloat(height))
            let x = item.rect.origin.x * CGFloat(width)
            let y = item.rect.origin.y * CGFloat(height)
            let pixelRect = CGRect(x: x, y: y, width: w, height: h)
            let center = CGPoint(x: pixelRect.midX, y: pixelRect.midY)

            ctx.saveGState()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: CGFloat(item.rotationAngle * .pi / 180.0))
            ctx.translateBy(x: -center.x, y: -center.y)

            let radius = min(12.0, min(pixelRect.width, pixelRect.height) * 0.22)
            let path = CGPath(roundedRect: pixelRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            ctx.addPath(path)
            ctx.fillPath()
            ctx.restoreGState()
        }

        guard let cgMask = ctx.makeImage() else { return nil }
        let rawMask = CIImage(cgImage: cgMask)
        // Мягкое сглаживание краёв маски (вычисляется один раз за экспорт), чтобы блюр не выглядел резкой заплаткой
        let featherSigma = max(1.5, min(4.5, min(frameSize.width, frameSize.height) * 0.004))
        let maskExtent = CGRect(x: 0, y: 0, width: width, height: height)
        return rawMask
            .clampedToExtent()
            .applyingGaussianBlur(sigma: featherSigma)
            .cropped(to: maskExtent)
    }

    /// Единый конвейер обработки кадра для MP4, GIF и WebP:
    /// 1) Размытие аннотаций в пространстве исходного ориентированного кадра
    /// 2) Smart Zoom
    /// 3) Кроп в нормализованных координатах [0...1]
    /// 4) Опциональный даунскейл до maxDimension
    nonisolated static func processCIImage(
        _ image: CIImage,
        blurMask: CIImage?,
        sourceTime: Double,
        compositionTime: Double,
        compositionDuration: Double,
        options: VideoExportOptions,
        cropTargetSize: CGSize? = nil,
        maxDimension: CGFloat? = nil
    ) -> CIImage {
        var current = image.extent.origin == .zero
            ? image
            : image.transformed(by: CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y))
        let frameExtent = current.extent
        guard frameExtent.width > 0, frameExtent.height > 0 else { return current }

        // 1. Защитное размытие (CIGaussianBlur + маска)
        if let blurMask {
            current = applyBlurAnnotations(to: current, maskImage: blurMask, frameExtent: frameExtent)
        }

        // 2. Smart Zoom (координаты в CI с y=0 снизу: 1.0 - focus.y)
        if options.smartZoom {
            current = applySmartZoom(
                to: current,
                frameExtent: frameExtent,
                sourceTime: sourceTime,
                compositionTime: compositionTime,
                compositionDuration: compositionDuration,
                options: options
            )
        }

        // 3. Кадрирование (cropRect задан в top-left нормализованных координатах [0...1])
        if let crop = options.cropRect, crop.width > 0, crop.height > 0 {
            current = applyCrop(to: current, frameExtent: frameExtent, cropRect: crop, targetSize: cropTargetSize)
        }

        // 4. Опциональный даунскейл для GIF / WebP
        if let maxDimension, maxDimension > 0 {
            let maxSide = max(current.extent.width, current.extent.height)
            if maxSide > maxDimension {
                let scale = maxDimension / maxSide
                let lanczos = CIFilter.lanczosScaleTransform()
                lanczos.inputImage = current
                lanczos.scale = Float(scale)
                lanczos.aspectRatio = 1.0
                if let scaled = lanczos.outputImage {
                    let targetW = max(1, Int((current.extent.width * scale).rounded()))
                    let targetH = max(1, Int((current.extent.height * scale).rounded()))
                    current = scaled.cropped(to: CGRect(x: 0, y: 0, width: targetW, height: targetH))
                }
            }
        }

        return current
    }

    nonisolated static func renderCGImage(_ ciImage: CIImage) -> CGImage? {
        let rect = ciImage.extent
        guard rect.width > 0, rect.height > 0 else { return nil }
        return ciContext.createCGImage(
            ciImage,
            from: rect,
            format: .RGBA8,
            colorSpace: srgbColorSpace
        )
    }

    // MARK: - Private Pipeline Stages

    nonisolated private static func applyBlurAnnotations(
        to image: CIImage,
        maskImage: CIImage,
        frameExtent: CGRect
    ) -> CIImage {
        let sigma = max(14.0, min(32.0, max(frameExtent.width, frameExtent.height) * 0.017))
        var frosted = image
            .clampedToExtent()
            .applyingGaussianBlur(sigma: sigma)
            .cropped(to: frameExtent)

        // Лёгкий эффект матового стекла (frosted glass) поверх размытия
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = frosted
        colorControls.saturation = 0.85
        colorControls.brightness = 0.03
        if let adjusted = colorControls.outputImage?.cropped(to: frameExtent) {
            frosted = adjusted
        }

        let blend = CIFilter.blendWithMask()
        blend.inputImage = frosted
        blend.backgroundImage = image
        blend.maskImage = maskImage
        return blend.outputImage?.cropped(to: frameExtent) ?? image
    }

    nonisolated private static func applySmartZoom(
        to image: CIImage,
        frameExtent: CGRect,
        sourceTime: Double,
        compositionTime: Double,
        compositionDuration: Double,
        options: VideoExportOptions
    ) -> CIImage {
        let focus: CGPoint
        let zoom: CGFloat

        if let track = options.cursorTrack, !track.keyframes.isEmpty {
            let state = track.cameraState(
                at: max(0, sourceTime),
                scale: options.smartZoomScale,
                mode: options.smartZoomMode,
                autoZoomOutOnIdle: options.autoZoomOutOnIdle
            )
            focus = state.focus
            zoom = state.zoom
        } else {
            // Запасной плавный зум на центр первой аннотации или центр экрана (безопасен и для клипов < 0.5с)
            let fallbackFocus: CGPoint
            if let first = options.annotations.first {
                fallbackFocus = CGPoint(x: first.rect.midX, y: first.rect.midY)
            } else {
                fallbackFocus = CGPoint(x: 0.5, y: 0.5)
            }
            focus = fallbackFocus

            let safeDuration = max(0.05, compositionDuration)
            let ramp = min(0.5, safeDuration * 0.25)
            let maxZoom = CGFloat(options.smartZoomScale.rawValue)
            if compositionTime < ramp {
                let p = CGFloat(max(0, compositionTime) / ramp)
                let smooth = p * p * (3 - 2 * p)
                zoom = 1.0 + (maxZoom - 1.0) * smooth
            } else if compositionTime > safeDuration - ramp {
                let p = CGFloat(max(0, safeDuration - compositionTime) / ramp)
                let smooth = p * p * (3 - 2 * p)
                zoom = 1.0 + (maxZoom - 1.0) * smooth
            } else {
                zoom = maxZoom
            }
        }

        guard zoom > 1.001 else { return image }

        let fx = min(1.0, max(0.0, focus.x)) * frameExtent.width
        // В CI y=0 находится снизу, а CursorTrack хранит y=0 сверху
        let fy = (1.0 - min(1.0, max(0.0, focus.y))) * frameExtent.height

        let zoomTransform = CGAffineTransform.identity
            .translatedBy(x: fx, y: fy)
            .scaledBy(x: zoom, y: zoom)
            .translatedBy(x: -fx, y: -fy)

        return image
            .transformed(by: zoomTransform)
            .cropped(to: frameExtent)
    }

    nonisolated private static func applyCrop(
        to image: CIImage,
        frameExtent: CGRect,
        cropRect: CGRect,
        targetSize: CGSize?
    ) -> CIImage {
        let nx = min(max(0, cropRect.origin.x), 0.99)
        let ny = min(max(0, cropRect.origin.y), 0.99)
        let nw = min(1.0 - nx, max(0.01, cropRect.width))
        let nh = min(1.0 - ny, max(0.01, cropRect.height))

        let cropW = min(frameExtent.width, max(2, targetSize?.width ?? floor(frameExtent.width * nw / 2) * 2))
        let cropH = min(frameExtent.height, max(2, targetSize?.height ?? floor(frameExtent.height * nh / 2) * 2))

        let rawX = floor(nx * frameExtent.width)
        let rawY = floor((1.0 - ny - nh) * frameExtent.height)
        let cropX = min(max(0, rawX), max(0, frameExtent.width - cropW))
        let cropY = min(max(0, rawY), max(0, frameExtent.height - cropH))

        let cropBounds = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
        return image
            .cropped(to: cropBounds)
            .transformed(by: CGAffineTransform(translationX: -cropX, y: -cropY))
            .cropped(to: CGRect(origin: .zero, size: CGSize(width: cropW, height: cropH)))
    }
}
