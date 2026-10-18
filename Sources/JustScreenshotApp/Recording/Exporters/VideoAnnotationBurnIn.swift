import Foundation
import CoreGraphics
import AppKit
import QuartzCore
import AVFoundation

/// Плоский снимок аннотации для экспорта (без SwiftUI Color)
public struct BurnInAnnotation: Sendable {
    public enum Kind: Sendable {
        case text, rect, arrow, blur
    }
    
    public var kind: Kind
    public var rect: CGRect // нормализованные [0...1]
    public var text: String
    public var r: CGFloat
    public var g: CGFloat
    public var b: CGFloat
    public var a: CGFloat
    public var lineWidth: CGFloat
    public var fontSize: CGFloat
    public var rotationAngle: Double
    
    @MainActor
    public static func from(_ items: [VideoAnnotationItem]) -> [BurnInAnnotation] {
        items.map { item in
            let ns = NSColor(item.color)
            var r: CGFloat = 1, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
            ns.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
            let kind: Kind
            switch item.type {
            case .text: kind = .text
            case .rect: kind = .rect
            case .arrow: kind = .arrow
            case .blur: kind = .blur
            }
            return BurnInAnnotation(
                kind: kind,
                rect: item.rect,
                text: item.text,
                r: r, g: g, b: b, a: a,
                lineWidth: item.lineWidth,
                fontSize: item.fontSize,
                rotationAngle: item.rotationAngle
            )
        }
    }
}

/// Отрисовка аннотаций поверх кадра (GIF) и сборка CALayer для MP4
enum VideoAnnotationBurnIn {
    
    /// Рисует аннотации в CGContext. origin — top-left видеокадра (как у CGImage).
    nonisolated static func draw(_ annotations: [BurnInAnnotation], in context: CGContext, videoSize: CGSize) {
        guard !annotations.isEmpty, videoSize.width > 0, videoSize.height > 0 else { return }
        
        for item in annotations {
            let pixelRect = CGRect(
                x: item.rect.origin.x * videoSize.width,
                y: item.rect.origin.y * videoSize.height,
                width: max(1, item.rect.width * videoSize.width),
                height: max(1, item.rect.height * videoSize.height)
            )
            let center = CGPoint(x: pixelRect.midX, y: pixelRect.midY)
            
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: CGFloat(item.rotationAngle * .pi / 180))
            context.translateBy(x: -center.x, y: -center.y)
            
            let color = CGColor(red: item.r, green: item.g, blue: item.b, alpha: item.a)
            
            switch item.kind {
            case .blur:
                context.setFillColor(CGColor(gray: 0.55, alpha: 0.85))
                context.fill(pixelRect)
                context.setStrokeColor(CGColor(gray: 1, alpha: 0.35))
                context.setLineWidth(1)
                context.stroke(pixelRect)
                
            case .rect:
                context.setStrokeColor(color)
                context.setLineWidth(item.lineWidth)
                context.stroke(pixelRect.insetBy(dx: item.lineWidth / 2, dy: item.lineWidth / 2))
                
            case .arrow:
                context.setStrokeColor(color)
                context.setLineWidth(item.lineWidth)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                let start = CGPoint(x: pixelRect.minX + 4, y: pixelRect.maxY - 4)
                let end = CGPoint(x: pixelRect.maxX - 4, y: pixelRect.minY + 4)
                context.move(to: start)
                context.addLine(to: end)
                let head = max(12, item.lineWidth * 3)
                let angle = atan2(end.y - start.y, end.x - start.x)
                context.move(to: end)
                context.addLine(to: CGPoint(
                    x: end.x - head * cos(angle - .pi / 6),
                    y: end.y - head * sin(angle - .pi / 6)
                ))
                context.move(to: end)
                context.addLine(to: CGPoint(
                    x: end.x - head * cos(angle + .pi / 6),
                    y: end.y - head * sin(angle + .pi / 6)
                ))
                context.strokePath()
                
            case .text:
                let text = (item.text.isEmpty ? "Text" : item.text) as NSString
                let font = NSFont.boldSystemFont(ofSize: item.fontSize)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor(cgColor: color) ?? .red
                ]
                let size = text.size(withAttributes: attrs)
                let bg = CGRect(
                    x: pixelRect.midX - size.width / 2 - 8,
                    y: pixelRect.midY - size.height / 2 - 4,
                    width: size.width + 16,
                    height: size.height + 8
                )
                context.setFillColor(CGColor(gray: 0, alpha: 0.65))
                context.addPath(CGPath(roundedRect: bg, cornerWidth: 6, cornerHeight: 6, transform: nil))
                context.fillPath()
                text.draw(
                    at: CGPoint(x: bg.minX + 8, y: bg.minY + 4),
                    withAttributes: attrs
                )
            }
            
            context.restoreGState()
        }
    }
    
    /// Накладывает аннотации на CGImage (для GIF)
    nonisolated static func composite(_ image: CGImage, annotations: [BurnInAnnotation]) -> CGImage {
        guard !annotations.isEmpty else { return image }
        let width = image.width
        let height = image.height
        let size = CGSize(width: width, height: height)
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        
        ctx.draw(image, in: CGRect(origin: .zero, size: size))
        // CGContext имеет origin снизу; переворачиваем для top-left логики аннотаций
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        draw(annotations, in: ctx, videoSize: size)
        return ctx.makeImage() ?? image
    }
    
    /// CALayer-композиция для AVVideoCompositionCoreAnimationTool (MP4)
    @MainActor
    static func makeAnimationTool(
        annotations: [BurnInAnnotation],
        renderSize: CGSize
    ) -> AVVideoCompositionCoreAnimationTool? {
        guard !annotations.isEmpty else { return nil }
        
        let parent = CALayer()
        let videoLayer = CALayer()
        parent.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parent.bounds
        parent.addSublayer(videoLayer)
        parent.isGeometryFlipped = true
        
        for item in annotations {
            let pixelRect = CGRect(
                x: item.rect.origin.x * renderSize.width,
                y: item.rect.origin.y * renderSize.height,
                width: max(1, item.rect.width * renderSize.width),
                height: max(1, item.rect.height * renderSize.height)
            )
            
            let layer = CALayer()
            layer.frame = pixelRect
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.position = CGPoint(x: pixelRect.midX, y: pixelRect.midY)
            layer.transform = CATransform3DMakeRotation(CGFloat(item.rotationAngle * .pi / 180), 0, 0, 1)
            
            let color = CGColor(red: item.r, green: item.g, blue: item.b, alpha: item.a)
            
            switch item.kind {
            case .blur:
                layer.backgroundColor = CGColor(gray: 0.55, alpha: 0.85)
                layer.cornerRadius = 6
                layer.borderWidth = 1
                layer.borderColor = CGColor(gray: 1, alpha: 0.35)
                
            case .rect:
                layer.borderWidth = item.lineWidth
                layer.borderColor = color
                layer.cornerRadius = 6
                layer.backgroundColor = NSColor.clear.cgColor
                
            case .arrow:
                let shape = CAShapeLayer()
                shape.frame = layer.bounds
                let path = CGMutablePath()
                let start = CGPoint(x: 4, y: layer.bounds.height - 4)
                let end = CGPoint(x: layer.bounds.width - 4, y: 4)
                path.move(to: start)
                path.addLine(to: end)
                let head = max(12, item.lineWidth * 3)
                let angle = atan2(end.y - start.y, end.x - start.x)
                path.move(to: end)
                path.addLine(to: CGPoint(x: end.x - head * cos(angle - .pi / 6), y: end.y - head * sin(angle - .pi / 6)))
                path.move(to: end)
                path.addLine(to: CGPoint(x: end.x - head * cos(angle + .pi / 6), y: end.y - head * sin(angle + .pi / 6)))
                shape.path = path
                shape.strokeColor = color
                shape.fillColor = nil
                shape.lineWidth = item.lineWidth
                shape.lineCap = .round
                shape.lineJoin = .round
                layer.addSublayer(shape)
                
            case .text:
                let text = CATextLayer()
                text.string = item.text.isEmpty ? "Text" : item.text
                text.font = NSFont.boldSystemFont(ofSize: item.fontSize)
                text.fontSize = item.fontSize
                text.foregroundColor = color
                text.alignmentMode = .center
                text.contentsScale = 2
                text.frame = layer.bounds
                layer.backgroundColor = CGColor(gray: 0, alpha: 0.65)
                layer.cornerRadius = 6
                layer.addSublayer(text)
            }
            
            parent.addSublayer(layer)
        }
        
        return AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
    }
}
