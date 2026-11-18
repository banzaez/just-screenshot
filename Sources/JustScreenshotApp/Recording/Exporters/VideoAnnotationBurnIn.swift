import Foundation
import CoreGraphics
import AppKit
import QuartzCore
import AVFoundation

/// Плоский снимок аннотации для экспорта (без SwiftUI Color)
public struct BurnInAnnotation: Sendable {
    public enum Kind: Sendable {
        case blur
    }
    
    public var kind: Kind
    public var rect: CGRect // нормализованные [0...1]
    public var rotationAngle: Double
    
    @MainActor
    public static func from(_ items: [VideoAnnotationItem]) -> [BurnInAnnotation] {
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

/// Отрисовка аннотаций поверх кадра (GIF/WebP) и сборка CALayer для MP4
enum VideoAnnotationBurnIn {
    
    private static let blurFillColor = CGColor(gray: 0.55, alpha: 0.85)
    private static let blurStrokeColor = CGColor(gray: 1, alpha: 0.35)
    
    nonisolated private static func pixelRect(for item: BurnInAnnotation, in size: CGSize) -> CGRect {
        CGRect(
            x: item.rect.origin.x * size.width,
            y: item.rect.origin.y * size.height,
            width: max(1, item.rect.width * size.width),
            height: max(1, item.rect.height * size.height)
        )
    }
    
    /// Рисует аннотации в CGContext. origin — top-left видеокадра (как у CGImage).
    nonisolated static func draw(_ annotations: [BurnInAnnotation], in context: CGContext, videoSize: CGSize) {
        guard !annotations.isEmpty, videoSize.width > 0, videoSize.height > 0 else { return }
        
        for item in annotations {
            let pixelRect = pixelRect(for: item, in: videoSize)
            let center = CGPoint(x: pixelRect.midX, y: pixelRect.midY)
            
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: CGFloat(item.rotationAngle * .pi / 180))
            context.translateBy(x: -center.x, y: -center.y)
            
            switch item.kind {
            case .blur:
                let path = CGPath(roundedRect: pixelRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
                context.setFillColor(blurFillColor)
                context.addPath(path)
                context.fillPath()
                context.setStrokeColor(blurStrokeColor)
                context.setLineWidth(1)
                context.addPath(path)
                context.strokePath()
            }
            
            context.restoreGState()
        }
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
            let pixelRect = pixelRect(for: item, in: renderSize)
            
            let layer = CALayer()
            layer.frame = pixelRect
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.position = CGPoint(x: pixelRect.midX, y: pixelRect.midY)
            layer.transform = CATransform3DMakeRotation(CGFloat(item.rotationAngle * .pi / 180), 0, 0, 1)
            
            switch item.kind {
            case .blur:
                layer.backgroundColor = blurFillColor
                layer.cornerRadius = 6
                layer.borderWidth = 1
                layer.borderColor = blurStrokeColor
            }
            
            parent.addSublayer(layer)
        }
        
        return AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
    }
}
