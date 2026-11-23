import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreText
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

        // 1. Защитное размытие (CIGaussianBlur / CIPixellate + маска)
        if let blurMask {
            current = applyBlurAnnotations(
                to: current,
                maskImage: blurMask,
                frameExtent: frameExtent,
                style: options.blurStyle,
                intensity: options.blurIntensity
            )
        }

        // 1.5. Подсветка кликов мыши (Click Ripples) в исходных координатах кадра до Smart Zoom
        if options.showClicks, let cursorTrack = options.cursorTrack {
            let ripples = cursorTrack.activeClickRipples(at: max(0, sourceTime))
            if !ripples.isEmpty {
                current = applyClickRipples(to: current, ripples: ripples)
            }
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

        // 4. Постпроцессинг нажатых клавиш (Keystrokes HUD) с учётом Smart Zoom
        if options.showKeystrokes,
           let track = options.keystrokeTrack,
           let active = track.activeKeystroke(at: max(0, sourceTime), filter: options.keystrokeFilter) {
            let cameraState: (focus: CGPoint, zoom: CGFloat)
            if options.smartZoom, let cursorTrack = options.cursorTrack, !cursorTrack.keyframes.isEmpty {
                cameraState = cursorTrack.cameraState(
                    at: max(0, sourceTime),
                    scale: options.smartZoomScale,
                    mode: options.smartZoomMode,
                    autoZoomOutOnIdle: options.autoZoomOutOnIdle
                )
            } else {
                cameraState = (CGPoint(x: 0.5, y: 0.5), options.smartZoom ? CGFloat(options.smartZoomScale.rawValue) : 1.0)
            }
            let resolvedPos = options.keystrokePosition.resolved(
                cameraFocus: cameraState.focus,
                cameraZoom: cameraState.zoom
            )
            current = applyKeystrokeOverlay(
                to: current,
                text: active.text,
                alpha: active.alpha,
                position: resolvedPos,
                size: options.keystrokeSize
            )
        }

        // 5. Опциональный даунскейл для GIF / WebP
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
        frameExtent: CGRect,
        style: VideoBlurStyle,
        intensity: VideoBlurIntensity
    ) -> CIImage {
        let baseSigma = max(14.0, min(32.0, max(frameExtent.width, frameExtent.height) * 0.017))
        let sigma = baseSigma * CGFloat(intensity.rawValue)

        let stylized: CIImage
        switch style {
        case .frostedGlass:
            let blurred = image
                .clampedToExtent()
                .applyingGaussianBlur(sigma: sigma)
                .cropped(to: frameExtent)
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = blurred
            colorControls.saturation = 0.85
            colorControls.brightness = 0.03
            stylized = colorControls.outputImage?.cropped(to: frameExtent) ?? blurred

        case .darkGlass:
            let blurred = image
                .clampedToExtent()
                .applyingGaussianBlur(sigma: sigma)
                .cropped(to: frameExtent)
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = blurred
            colorControls.saturation = 0.75
            colorControls.brightness = -0.08
            stylized = colorControls.outputImage?.cropped(to: frameExtent) ?? blurred

        case .gaussian:
            stylized = image
                .clampedToExtent()
                .applyingGaussianBlur(sigma: sigma)
                .cropped(to: frameExtent)

        case .pixelate:
            let baseBlock = max(8.0, min(42.0, max(frameExtent.width, frameExtent.height) * 0.015))
            let pixellate = CIFilter.pixellate()
            pixellate.inputImage = image.clampedToExtent()
            pixellate.scale = Float(baseBlock * CGFloat(intensity.rawValue))
            pixellate.center = CGPoint(x: frameExtent.midX, y: frameExtent.midY)
            stylized = pixellate.outputImage?.cropped(to: frameExtent) ?? image
        }

        let blend = CIFilter.blendWithMask()
        blend.inputImage = stylized
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

    nonisolated private static func applyKeystrokeOverlay(
        to image: CIImage,
        text: String,
        alpha: CGFloat,
        position: KeystrokePosition,
        size: KeystrokeSize
    ) -> CIImage {
        let extent = image.extent
        let width = extent.width
        let height = extent.height
        guard width > 24, height > 24 else { return image }

        let clampedAlpha = min(1.0, max(0.0, alpha))
        guard clampedAlpha > 0.001 else { return image }

        let uiScale = max(0.75, min(2.5, height / 720.0)) * CGFloat(size.rawValue)
        let fontSize = 18.0 * uiScale
        let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
        let textColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: clampedAlpha)
        let attrs: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: textColor
        ]
        guard let attrString = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary) else {
            return image
        }
        let line = CTLineCreateWithAttributedString(attrString)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let textWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        let textHeight = ascent + descent

        let hPad = 20.0 * uiScale
        let vPad = 12.0 * uiScale
        let edgeMargin = max(12.0, 24.0 * max(0.75, min(2.5, height / 720.0)))
        let badgeWidth = min(max(24.0, width - 16.0), textWidth + hPad * 2)
        let badgeHeight = min(max(20.0, height - 16.0), textHeight + vPad * 2)

        let badgeX: CGFloat
        let badgeY: CGFloat
        switch position {
        case .bottomCenter:
            badgeX = max(8.0, (width - badgeWidth) / 2.0)
            badgeY = min(height - badgeHeight - 8.0, edgeMargin + 12.0)
        case .bottomLeft:
            badgeX = min(max(8.0, edgeMargin), max(8.0, width - badgeWidth - 8.0))
            badgeY = min(height - badgeHeight - 8.0, edgeMargin + 12.0)
        case .bottomRight:
            badgeX = max(8.0, width - badgeWidth - edgeMargin)
            badgeY = min(height - badgeHeight - 8.0, edgeMargin + 12.0)
        case .topCenter:
            badgeX = max(8.0, (width - badgeWidth) / 2.0)
            badgeY = max(8.0, height - badgeHeight - edgeMargin - 12.0)
        }

        // Выделяем CGContext только под сам бейдж + тень вместо полного кадра
        let shadowPad = ceil(18.0 * uiScale)
        let overlayW = max(1, Int((badgeWidth + shadowPad * 2).rounded(.up)))
        let overlayH = max(1, Int((badgeHeight + shadowPad * 2).rounded(.up)))
        guard let ctx = CGContext(
            data: nil,
            width: overlayW,
            height: overlayH,
            bitsPerComponent: 8,
            bytesPerRow: overlayW * 4,
            space: srgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        let localBadgeRect = CGRect(x: shadowPad, y: shadowPad, width: badgeWidth, height: badgeHeight)
        let cornerRadius = min(10.0 * uiScale, min(badgeWidth, badgeHeight) / 2.0)
        let path = CGPath(roundedRect: localBadgeRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -3 * uiScale), blur: 12 * uiScale, color: CGColor(gray: 0, alpha: 0.65 * clampedAlpha))
        ctx.setFillColor(CGColor(srgbRed: 0.07, green: 0.07, blue: 0.09, alpha: 0.94 * clampedAlpha))
        ctx.addPath(path)
        ctx.fillPath()

        ctx.setStrokeColor(CGColor(gray: 1.0, alpha: 0.35 * clampedAlpha))
        ctx.setLineWidth(1.5 * uiScale)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        let textX = localBadgeRect.origin.x + max(4.0, (badgeWidth - textWidth) / 2.0)
        let textY = localBadgeRect.origin.y + (badgeHeight - textHeight) / 2.0 + descent
        ctx.textPosition = CGPoint(x: textX, y: textY)
        CTLineDraw(line, ctx)

        guard let cgOverlay = ctx.makeImage() else { return image }
        let overlayCI = CIImage(cgImage: cgOverlay)
            .transformed(by: CGAffineTransform(translationX: badgeX - shadowPad, y: badgeY - shadowPad))
        return overlayCI.composited(over: image).cropped(to: extent)
    }

    nonisolated private static func applyClickRipples(
        to image: CIImage,
        ripples: [ActiveClickRipple]
    ) -> CIImage {
        let extent = image.extent
        let width = extent.width
        let height = extent.height
        guard width > 16, height > 16 else { return image }

        let uiScale = max(0.75, min(2.5, height / 720.0))
        let strokeWidth = 2.2 * uiScale
        var unionRect = CGRect.null
        var drawItems: [(rect: CGRect, alpha: CGFloat, isRightClick: Bool)] = []
        drawItems.reserveCapacity(ripples.count)

        for ripple in ripples {
            let alpha = max(0.0, 1.0 - ripple.progress)
            guard alpha > 0.001 else { continue }
            let radius = (8.0 + ripple.progress * 24.0) * uiScale
            let cx = min(1.0, max(0.0, ripple.point.x)) * width
            // В CoreGraphics y=0 снизу, а CursorTrack хранит y=0 сверху
            let cy = (1.0 - min(1.0, max(0.0, ripple.point.y))) * height
            let rect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
            let padded = rect.insetBy(dx: -strokeWidth, dy: -strokeWidth)
            unionRect = unionRect.union(padded)
            drawItems.append((rect, alpha, ripple.isRightClick))
        }

        guard !drawItems.isEmpty, !unionRect.isNull else { return image }
        let clippedBox = unionRect.intersection(extent).integral
        let boxW = Int(clippedBox.width)
        let boxH = Int(clippedBox.height)
        guard boxW > 0, boxH > 0 else { return image }

        guard let ctx = CGContext(
            data: nil,
            width: boxW,
            height: boxH,
            bitsPerComponent: 8,
            bytesPerRow: boxW * 4,
            space: srgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        ctx.translateBy(x: -clippedBox.origin.x, y: -clippedBox.origin.y)
        for item in drawItems {
            if item.isRightClick {
                ctx.setFillColor(CGColor(srgbRed: 1.0, green: 0.6, blue: 0.2, alpha: 0.26 * item.alpha))
                ctx.setStrokeColor(CGColor(srgbRed: 1.0, green: 0.65, blue: 0.25, alpha: 0.85 * item.alpha))
            } else {
                ctx.setFillColor(CGColor(srgbRed: 0.2, green: 0.6, blue: 1.0, alpha: 0.24 * item.alpha))
                ctx.setStrokeColor(CGColor(srgbRed: 0.35, green: 0.72, blue: 1.0, alpha: 0.85 * item.alpha))
            }
            ctx.setLineWidth(strokeWidth)
            ctx.fillEllipse(in: item.rect)
            ctx.strokeEllipse(in: item.rect)
        }

        guard let cgOverlay = ctx.makeImage() else { return image }
        let overlayCI = CIImage(cgImage: cgOverlay)
            .transformed(by: CGAffineTransform(translationX: clippedBox.origin.x, y: clippedBox.origin.y))
        return overlayCI.composited(over: image).cropped(to: extent)
    }
}
