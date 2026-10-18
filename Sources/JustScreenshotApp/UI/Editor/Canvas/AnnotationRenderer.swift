import Cocoa

/// Рендерер аннотаций поверх NSImage через CoreGraphics в оригинальном разрешении 1:1
@MainActor
public enum AnnotationRenderer {
    
    /// Итоговое изображение: аннотации + (опционально) красивый градиентный фон с тенью
    public static func render(
        baseImage: NSImage,
        items: [AnnotationItem],
        backdrop: BackdropPreset?,
        padding: CGFloat,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 24,
        shadow: Bool
    ) -> NSImage {
        let inner = render(baseImage: baseImage, items: items)
        guard let backdrop else { return inner }
        
        let pad = padding
        let outSize = NSSize(width: inner.size.width + pad * 2, height: inner.size.height + pad * 2)
        let out = NSImage(size: outSize)
        out.lockFocus()
        
        let cols = backdrop.colors.map { NSColor($0) }
        let bgRect = NSRect(origin: .zero, size: outSize)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 0, yRadius: 0)
        NSGradient(colors: cols)?.draw(in: bgPath, angle: -45)
        
        let innerRect = NSRect(x: pad, y: pad, width: inner.size.width, height: inner.size.height)
        let clip = NSBezierPath(roundedRect: innerRect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        if shadow && shadowRadius > 0 {
            NSGraphicsContext.saveGraphicsState()
            let sh = NSShadow()
            sh.shadowColor = NSColor.black.withAlphaComponent(0.4)
            sh.shadowBlurRadius = shadowRadius
            sh.shadowOffset = NSSize(width: 0, height: -shadowRadius * 0.4)
            sh.set()
            NSColor.black.setFill()
            clip.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        
        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        inner.draw(in: innerRect)
        NSGraphicsContext.restoreGraphicsState()
        
        out.unlockFocus()
        return out
    }
    
    /// Отрисовка исходного изображения со списком аннотаций
    public static func render(
        baseImage: NSImage,
        items: [AnnotationItem],
        zoomScale: CGFloat = 1.0
    ) -> NSImage {
        let size = baseImage.size
        let targetImage = NSImage(size: size)
        
        targetImage.lockFocus()
        baseImage.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)
        
        if let context = NSGraphicsContext.current?.cgContext {
            let blurred = items.contains(where: { $0.tool == .blur }) ? BlurFilter.makeBlurred(baseImage) : nil
            for item in items {
                renderItem(item, in: context, imageSize: size, baseImage: baseImage, blurred: blurred)
            }
        }
        
        targetImage.unlockFocus()
        return targetImage
    }
    
    private static func renderItem(_ item: AnnotationItem, in context: CGContext, imageSize: CGSize, baseImage: NSImage, blurred: NSImage?) {
        context.saveGState()
        
        // Перевод координат из SwiftUI (y сверху вниз) в CoreGraphics (y снизу вверх)
        let p1 = CGPoint(
            x: item.startPoint.x,
            y: imageSize.height - item.startPoint.y
        )
        let p2 = CGPoint(
            x: item.endPoint.x,
            y: imageSize.height - item.endPoint.y
        )
        
        // Точный центр вращения
        let center = CGPoint(
            x: item.center.x,
            y: imageSize.height - item.center.y
        )
        
        // Поворот вокруг центра элемента
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
        case .select:
            break
            
        case .arrow:
            drawArrow(p1: p1, p2: p2, in: context, headLength: max(14, item.lineWidth * 3.2))
            
        case .ellipse:
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
            context.strokeEllipse(in: rect)
            
        case .rectangle:
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
            context.stroke(rect)
            
        case .roundedRect:
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
            let path = CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)
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
                // Рисуем только нужный фрагмент, а не весь кадр
                let nsRect = NSRect(origin: rect.origin, size: rect.size)
                blurred.draw(in: nsRect, from: nsRect, operation: .copy, fraction: 1.0)
            } else {
                context.setFillColor(CGColor(gray: 0.5, alpha: 0.7))
                context.fill(rect)
            }
            context.setStrokeColor(CGColor(gray: 1, alpha: 0.35))
            context.setLineWidth(1)
            context.stroke(rect)
            
        case .highlighter:
            context.setStrokeColor(nsColor.withAlphaComponent(0.45).cgColor)
            context.setLineWidth(item.lineWidth * 4)
            context.move(to: p1)
            context.addLine(to: p2)
            context.strokePath()
            
        case .magnifier:
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = max(min(rect.width, rect.height) / 2, 16)
            let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            
            // Тень вокруг линзы
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -4), blur: 12, color: CGColor(gray: 0, alpha: 0.45))
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fillEllipse(in: circleRect)
            context.restoreGState()
            
            // Клиппинг кругом и отрисовка масштабированного фрагмента
            context.saveGState()
            context.addEllipse(in: circleRect)
            context.clip()
            
            let zoomFactor = CGFloat(item.scaleFactor > 0 ? item.scaleFactor : 2.0)
            context.translateBy(x: center.x, y: center.y)
            context.scaleBy(x: zoomFactor, y: zoomFactor)
            context.translateBy(x: -center.x, y: -center.y)
            
            baseImage.draw(at: .zero, from: NSRect(origin: .zero, size: imageSize), operation: .copy, fraction: 1.0)
            context.restoreGState()
            
            // Ободок линзы
            context.setStrokeColor(CGColor(gray: 1, alpha: 0.95))
            context.setLineWidth(4)
            context.strokeEllipse(in: circleRect)
            
            let label = String(format: "%.1g×", Double(zoomFactor)) as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let labelSize = label.size(withAttributes: attrs)
            label.draw(
                at: NSPoint(x: center.x - labelSize.width / 2, y: circleRect.minY + 4),
                withAttributes: attrs
            )
            
        case .text:
            let text = (item.text.isEmpty ? L("editor.default_text") : item.text) as NSString
            let font = NSFont.boldSystemFont(ofSize: item.fontSize)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: nsColor
            ]
            let strSize = text.size(withAttributes: attrs)
            // Координата верхнего левого угла в CG
            let yInCG = imageSize.height - item.startPoint.y - strSize.height
            text.draw(at: NSPoint(x: item.startPoint.x, y: yInCG), withAttributes: attrs)
        }
        
        context.restoreGState()
    }
    
    private static func drawArrow(p1: CGPoint, p2: CGPoint, in context: CGContext, headLength: CGFloat) {
        context.move(to: p1)
        context.addLine(to: p2)
        context.strokePath()
        
        let angle = atan2(p2.y - p1.y, p2.x - p1.x)
        let arrowLength: CGFloat = headLength
        let arrowAngle: CGFloat = .pi / 6
        let tip1 = CGPoint(x: p2.x - arrowLength * cos(angle - arrowAngle), y: p2.y - arrowLength * sin(angle - arrowAngle))
        let tip2 = CGPoint(x: p2.x - arrowLength * cos(angle + arrowAngle), y: p2.y - arrowLength * sin(angle + arrowAngle))
        context.move(to: p2)
        context.addLine(to: tip1)
        context.move(to: p2)
        context.addLine(to: tip2)
        context.strokePath()
    }
}
