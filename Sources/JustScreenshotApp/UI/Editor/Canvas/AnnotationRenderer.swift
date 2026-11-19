import Cocoa

/// Рендерер аннотаций поверх NSImage через CoreGraphics в оригинальном разрешении
@MainActor
public enum AnnotationRenderer {

    /// Итоговое изображение: аннотации + опциональный фон с тенью и рамка окна macOS
    public static func render(
        baseImage: NSImage,
        items: [AnnotationItem],
        backdrop: BackdropPreset?,
        padding: CGFloat,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 24,
        shadow: Bool,
        showWindowFrame: Bool = false,
        imageID: UUID? = nil,
        revision: Int = 0
    ) -> NSImage {
        let size = baseImage.size
        guard size.width > 0, size.height > 0 else { return baseImage }

        let titlebarH: CGFloat = showWindowFrame ? WindowTitlebarSpec.height : 0
        let contentSize = NSSize(width: size.width, height: size.height + titlebarH)
        let scale = backingScale(for: baseImage)
        let blurred = items.contains(where: { $0.tool == .blur })
            ? BlurFilter.makeBlurred(baseImage, id: imageID, revision: revision)
            : nil

        let spotlightItems = items.filter { $0.tool == .spotlight }

        if let backdrop {
            let pad = padding
            let outSize = NSSize(width: contentSize.width + pad * 2, height: contentSize.height + pad * 2)

            return renderInBitmapContext(baseImage: baseImage, pointSize: outSize, scale: scale) { context in
                let cols = backdrop.colors.map { NSColor($0) }
                let bgRect = NSRect(origin: .zero, size: outSize)
                let bgPath = NSBezierPath(rect: bgRect)
                NSGradient(colors: cols)?.draw(in: bgPath, angle: -45)

                let innerRect = NSRect(x: pad, y: pad, width: contentSize.width, height: contentSize.height)
                let clampedCorner = AnnotationGeometry.clampedCornerRadius(cornerRadius, in: innerRect)
                let clip = NSBezierPath(roundedRect: innerRect, xRadius: clampedCorner, yRadius: clampedCorner)

                context.saveGState()
                if shadow && shadowRadius > 0 {
                    context.setShadow(
                        offset: CGSize(width: 0, height: -shadowRadius * 0.4),
                        blur: shadowRadius,
                        color: CGColor(gray: 0, alpha: 0.4)
                    )
                }
                context.beginTransparencyLayer(auxiliaryInfo: nil)
                NSGraphicsContext.saveGraphicsState()
                clip.addClip()

                let imageRect = NSRect(x: pad, y: pad, width: size.width, height: size.height)
                baseImage.draw(in: imageRect)

                if showWindowFrame {
                    let titlebarRect = NSRect(x: pad, y: pad + size.height, width: size.width, height: titlebarH)
                    drawWindowFrameTitlebar(in: titlebarRect)
                }

                context.saveGState()
                context.translateBy(x: pad, y: pad)
                renderItems(
                    items,
                    spotlightItems: spotlightItems,
                    in: context,
                    imageSize: size,
                    baseImage: baseImage,
                    blurred: blurred
                )
                context.restoreGState()

                NSGraphicsContext.restoreGraphicsState()
                context.endTransparencyLayer()
                context.restoreGState()
            } ?? baseImage
        } else if showWindowFrame {
            return renderInBitmapContext(baseImage: baseImage, pointSize: contentSize, scale: scale) { context in
                let fullRect = NSRect(origin: .zero, size: contentSize)
                let clampedCorner = AnnotationGeometry.clampedCornerRadius(cornerRadius, in: fullRect)
                let clip = NSBezierPath(roundedRect: fullRect, xRadius: clampedCorner, yRadius: clampedCorner)

                NSGraphicsContext.saveGraphicsState()
                clip.addClip()

                let imageRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
                baseImage.draw(in: imageRect)

                let titlebarRect = NSRect(x: 0, y: size.height, width: size.width, height: titlebarH)
                drawWindowFrameTitlebar(in: titlebarRect)

                renderItems(
                    items,
                    spotlightItems: spotlightItems,
                    in: context,
                    imageSize: size,
                    baseImage: baseImage,
                    blurred: blurred
                )

                NSGraphicsContext.restoreGraphicsState()
            } ?? baseImage
        } else {
            return render(baseImage: baseImage, items: items, imageID: imageID, revision: revision)
        }
    }

    private static func drawWindowFrameTitlebar(in rect: NSRect) {
        NSColor(calibratedWhite: WindowTitlebarSpec.backgroundWhite, alpha: 1.0).setFill()
        NSBezierPath(rect: rect).fill()

        let diameter = WindowTitlebarSpec.buttonDiameter
        let y = rect.minY + (rect.height - diameter) / 2
        let startX = rect.minX + WindowTitlebarSpec.leadingInset
        let step = diameter + WindowTitlebarSpec.buttonSpacing

        for (i, rgb) in WindowTitlebarSpec.trafficLightRGB.enumerated() {
            let circleRect = NSRect(x: startX + CGFloat(i) * step, y: y, width: diameter, height: diameter)
            let path = NSBezierPath(ovalIn: circleRect)
            NSColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1.0).setFill()
            path.fill()
            NSColor.black.withAlphaComponent(WindowTitlebarSpec.borderWhiteAlpha).setStroke()
            path.lineWidth = 0.5
            path.stroke()
        }
    }

    /// Отрисовка исходного изображения со списком аннотаций 1:1
    public static func render(
        baseImage: NSImage,
        items: [AnnotationItem],
        imageID: UUID? = nil,
        revision: Int = 0
    ) -> NSImage {
        let size = baseImage.size
        guard size.width > 0, size.height > 0 else { return baseImage }
        let scale = backingScale(for: baseImage)
        let blurred = items.contains(where: { $0.tool == .blur })
            ? BlurFilter.makeBlurred(baseImage, id: imageID, revision: revision)
            : nil
        let spotlightItems = items.filter { $0.tool == .spotlight }

        return renderInBitmapContext(baseImage: baseImage, pointSize: size, scale: scale) { context in
            baseImage.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)
            renderItems(
                items,
                spotlightItems: spotlightItems,
                in: context,
                imageSize: size,
                baseImage: baseImage,
                blurred: blurred
            )
        } ?? baseImage
    }

    private static func backingScale(for image: NSImage) -> CGFloat {
        guard image.size.width > 0,
              let cg = ImageExporter.cgImage(from: image) else {
            return NSScreen.main?.backingScaleFactor ?? 2.0
        }
        return max(1.0, CGFloat(cg.width) / image.size.width)
    }

    private static func renderInBitmapContext(
        baseImage: NSImage,
        pointSize: NSSize,
        scale: CGFloat,
        drawBlock: (CGContext) -> Void
    ) -> NSImage? {
        let pixelWidth = max(1, Int((pointSize.width * scale).rounded()))
        let pixelHeight = max(1, Int((pointSize.height * scale).rounded()))

        let srgb = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        var preferredSpace = srgb
        if let cg = ImageExporter.cgImage(from: baseImage),
           let srcSpace = cg.colorSpace,
           srcSpace.model == .rgb,
           srcSpace.numberOfComponents == 3 {
            preferredSpace = srcSpace
        }

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let cgContext = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: preferredSpace,
            bitmapInfo: bitmapInfo
        ) ?? CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: srgb,
            bitmapInfo: bitmapInfo
        )

        guard let cgContext else { return nil }

        cgContext.scaleBy(x: scale, y: scale)
        let nsContext = NSGraphicsContext(cgContext: cgContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        drawBlock(cgContext)
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = cgContext.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = pointSize
        let result = NSImage(size: pointSize)
        result.addRepresentation(rep)
        return result
    }

    private static func renderItems(
        _ items: [AnnotationItem],
        spotlightItems: [AnnotationItem],
        in context: CGContext,
        imageSize: CGSize,
        baseImage: NSImage,
        blurred: NSImage?
    ) {
        var didDrawSpotlightScrim = false
        for item in items {
            if item.tool == .spotlight, !didDrawSpotlightScrim {
                drawCompositeSpotlightDim(spotlights: spotlightItems, imageSize: imageSize, in: context)
                didDrawSpotlightScrim = true
            }
            renderItem(item, in: context, imageSize: imageSize, baseImage: baseImage, blurred: blurred)
        }
    }

    private static func drawCompositeSpotlightDim(
        spotlights: [AnnotationItem],
        imageSize: CGSize,
        in context: CGContext
    ) {
        guard !spotlights.isEmpty, imageSize.width > 0, imageSize.height > 0 else { return }
        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setFillColor(CGColor(gray: 0.0, alpha: 0.55))
        context.fill(CGRect(origin: .zero, size: imageSize))
        context.setBlendMode(.clear)

        for spot in spotlights {
            let p1 = CGPoint(x: spot.startPoint.x, y: imageSize.height - spot.startPoint.y)
            let p2 = CGPoint(x: spot.endPoint.x, y: imageSize.height - spot.endPoint.y)
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
            let r = AnnotationGeometry.clampedCornerRadius(8, in: rect)

            context.saveGState()
            if spot.rotationAngle != 0 {
                let center = CGPoint(x: spot.center.x, y: imageSize.height - spot.center.y)
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: CGFloat(-spot.rotationAngle * .pi / 180.0))
                context.translateBy(x: -center.x, y: -center.y)
            }
            let holePath = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
            context.addPath(holePath)
            context.fillPath()
            context.restoreGState()
        }

        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func renderItem(_ item: AnnotationItem, in context: CGContext, imageSize: CGSize, baseImage: NSImage, blurred: NSImage?) {
        context.saveGState()

        let p1 = CGPoint(x: item.startPoint.x, y: imageSize.height - item.startPoint.y)
        let p2 = CGPoint(x: item.endPoint.x, y: imageSize.height - item.endPoint.y)
        let center = CGPoint(x: item.center.x, y: imageSize.height - item.center.y)

        if item.rotationAngle != 0 {
            context.translateBy(x: center.x, y: center.y)
            let rad = -item.rotationAngle * .pi / 180.0
            context.rotate(by: CGFloat(rad))
            context.translateBy(x: -center.x, y: -center.y)
        }

        let nsColor = NSColor(item.color)
        context.setStrokeColor(nsColor.cgColor)
        context.setFillColor(nsColor.cgColor)
        context.setLineWidth(item.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch item.tool {
        case .select, .crop:
            break

        case .arrow:
            drawArrow(p1: p1, p2: p2, in: context, headLength: max(14, item.lineWidth * 3.2))

        case .curvedArrow:
            drawCurvedArrow(p1: p1, p2: p2, curveOffset: item.curveOffset, in: context, headLength: max(14, item.lineWidth * 3.2))

        case .ellipse:
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
            context.strokeEllipse(in: rect)

        case .rectangle:
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
            context.stroke(rect)

        case .roundedRect:
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
            let r = AnnotationGeometry.clampedCornerRadius(10, in: rect)
            let path = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
            let dashLen = max(4.0, item.lineWidth * 2.0)
            context.saveGState()
            context.setLineDash(phase: 0, lengths: [dashLen, dashLen])
            context.addPath(path)
            context.strokePath()
            context.restoreGState()

        case .counter:
            let radius: CGFloat = 16
            let rect = CGRect(x: p1.x - radius, y: p1.y - radius, width: radius * 2, height: radius * 2)
            context.fillEllipse(in: rect)

            let numStr = "\(item.counterNumber)" as NSString
            let font = NSFont.boldSystemFont(ofSize: 15)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white
            ]
            let strSize = numStr.size(withAttributes: attrs)
            numStr.draw(at: NSPoint(x: p1.x - strSize.width / 2, y: p1.y - strSize.height / 2), withAttributes: attrs)

        case .blur:
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
            if let blurred {
                context.saveGState()
                context.clip(to: rect)
                blurred.draw(in: NSRect(origin: .zero, size: imageSize), from: .zero, operation: .sourceOver, fraction: 1.0)
                context.restoreGState()
            } else {
                context.setFillColor(CGColor(gray: 0.5, alpha: 0.7))
                context.fill(rect)
            }
            context.setStrokeColor(CGColor(gray: 1, alpha: 0.35))
            context.setLineWidth(1)
            context.stroke(rect)

        case .spotlight:
            // Затемнение рисуется единым composite-проходом; здесь обводим только контур фокуса
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
            let r = AnnotationGeometry.clampedCornerRadius(8.0, in: rect)
            let strokePath = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
            context.addPath(strokePath)
            context.setStrokeColor(CGColor(gray: 1.0, alpha: 0.85))
            context.setLineWidth(2.0)
            context.strokePath()

        case .highlighter:
            context.setStrokeColor(nsColor.withAlphaComponent(0.45).cgColor)
            context.setLineWidth(item.lineWidth * 4)
            context.move(to: p1)
            context.addLine(to: p2)
            context.strokePath()

        case .magnifier:
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
            let circleRect = AnnotationGeometry.magnifierCircleRect(for: rect)
            let lensCenter = CGPoint(x: circleRect.midX, y: circleRect.midY)

            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -4), blur: 10, color: CGColor(gray: 0, alpha: 0.45))
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fillEllipse(in: circleRect)
            context.restoreGState()

            context.saveGState()
            context.addEllipse(in: circleRect)
            context.clip()

            let zoomFactor = CGFloat(item.scaleFactor > 0 ? item.scaleFactor : 2.0)
            context.translateBy(x: lensCenter.x, y: lensCenter.y)
            context.scaleBy(x: zoomFactor, y: zoomFactor)
            context.translateBy(x: -lensCenter.x, y: -lensCenter.y)

            baseImage.draw(at: .zero, from: NSRect(origin: .zero, size: imageSize), operation: .copy, fraction: 1.0)
            context.restoreGState()

            context.setStrokeColor(CGColor(gray: 1, alpha: 0.95))
            context.setLineWidth(4)
            context.strokeEllipse(in: circleRect)

            context.setStrokeColor(CGColor(gray: 0, alpha: 0.35))
            context.setLineWidth(1.0)
            context.strokeEllipse(in: circleRect.insetBy(dx: -1.5, dy: -1.5))

            let labelStr = AnnotationFormatting.zoomLabel(Double(zoomFactor)) as NSString
            let pillRect = CGRect(x: lensCenter.x - 20, y: circleRect.minY + 6, width: 40, height: 16)
            let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
            context.setFillColor(CGColor(gray: 0, alpha: 0.55))
            context.addPath(pillPath)
            context.fillPath()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let labelSize = labelStr.size(withAttributes: attrs)
            labelStr.draw(
                at: NSPoint(x: lensCenter.x - labelSize.width / 2, y: pillRect.minY + (pillRect.height - labelSize.height) / 2),
                withAttributes: attrs
            )

        case .text:
            let text = item.effectiveText as NSString
            let font = NSFont.boldSystemFont(ofSize: item.fontSize)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: nsColor
            ]
            let strSize = text.size(withAttributes: attrs)
            let yInCG = imageSize.height - item.startPoint.y - strSize.height
            text.draw(at: NSPoint(x: item.startPoint.x, y: yInCG), withAttributes: attrs)
        }

        context.restoreGState()
    }

    private static func drawArrow(p1: CGPoint, p2: CGPoint, in context: CGContext, headLength: CGFloat) {
        context.move(to: p1)
        context.addLine(to: p2)
        context.strokePath()

        let (tip1, tip2) = AnnotationGeometry.arrowHeadEndpoints(tip: p2, from: p1, headLength: headLength)
        context.move(to: p2)
        context.addLine(to: tip1)
        context.move(to: p2)
        context.addLine(to: tip2)
        context.strokePath()
    }

    private static func drawCurvedArrow(p1: CGPoint, p2: CGPoint, curveOffset: CGFloat, in context: CGContext, headLength: CGFloat) {
        guard let control = AnnotationGeometry.curvedControlPoint(start: p1, end: p2, curveOffset: -curveOffset) else { return }
        context.move(to: p1)
        context.addQuadCurve(to: p2, control: control)
        context.strokePath()

        let (tip1, tip2) = AnnotationGeometry.arrowHeadEndpoints(tip: p2, from: control, headLength: headLength)
        context.move(to: p2)
        context.addLine(to: tip1)
        context.move(to: p2)
        context.addLine(to: tip2)
        context.strokePath()
    }
}
