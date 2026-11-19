import SwiftUI
import AppKit

/// Отрисовка элементов аннотаций, рамки выделения и маркеров внутри SwiftUI GraphicsContext
@MainActor
enum AnnotationCanvasDrawer {
    static func applyRotation(of item: AnnotationItem, to ctx: inout GraphicsContext) {
        guard item.rotationAngle != 0, !item.isLineLike else { return }
        let c = item.center
        ctx.translateBy(x: c.x, y: c.y)
        ctx.rotate(by: Angle(degrees: item.rotationAngle))
        ctx.translateBy(x: -c.x, y: -c.y)
    }

    static func drawCompositeSpotlightDim(
        spotlights: [AnnotationItem],
        canvasSize: CGSize,
        in context: GraphicsContext
    ) {
        guard !spotlights.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else { return }
        context.drawLayer { layerCtx in
            layerCtx.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(Color.black.opacity(0.55)))
            layerCtx.blendMode = .clear
            for spot in spotlights {
                var holeCtx = layerCtx
                applyRotation(of: spot, to: &holeCtx)
                let rect = AnnotationGeometry.itemRect(spot)
                let r = AnnotationGeometry.clampedCornerRadius(8, in: rect)
                holeCtx.fill(Path(roundedRect: rect, cornerRadius: r), with: .color(.black))
            }
        }
    }

    static func drawSelection(
        _ item: AnnotationItem,
        in base: GraphicsContext,
        zoomScale: CGFloat,
        interactions: AnnotationCanvasInteractions
    ) {
        let z = max(zoomScale, 0.05)
        let px = 1 / z
        let dash: [CGFloat] = [3 * px, 3 * px]
        let accent = Color.accentColor
        var ctx = base

        if item.isLineLike {
            let chordMid = CGPoint(
                x: (item.startPoint.x + item.endPoint.x) / 2.0,
                y: (item.startPoint.y + item.endPoint.y) / 2.0
            )
            let angle = atan2(item.endPoint.y - item.startPoint.y, item.endPoint.x - item.startPoint.x)
            let len = hypot(item.endPoint.x - item.startPoint.x, item.endPoint.y - item.startPoint.y)
            let pad = item.lineHalfThickness + 5 * px
            ctx.translateBy(x: chordMid.x, y: chordMid.y)
            ctx.rotate(by: .radians(angle))

            let sag = item.tool == .curvedArrow ? item.curveOffset * 0.5 : 0
            let minY = min(0, sag) - pad
            let maxY = max(0, sag) + pad
            let rect = CGRect(x: -len / 2.0 - pad, y: minY, width: len + pad * 2.0, height: maxY - minY)
            let r = AnnotationGeometry.clampedCornerRadius(pad, in: rect)
            ctx.stroke(
                Path(roundedRect: rect, cornerRadius: r),
                with: .color(accent.opacity(0.9)),
                style: StrokeStyle(lineWidth: px, dash: dash)
            )
        } else {
            applyRotation(of: item, to: &ctx)
            let box = item.boundingBox
            let r = AnnotationGeometry.clampedCornerRadius(2 * px, in: box)
            ctx.stroke(
                Path(roundedRect: box, cornerRadius: r),
                with: .color(accent.opacity(0.9)),
                style: StrokeStyle(lineWidth: px, dash: dash)
            )
            if item.supportsRotation {
                let rotateOffset: CGFloat = 26 / z
                let top = CGPoint(x: box.midX, y: box.minY)
                let knob = CGPoint(x: box.midX, y: box.minY - rotateOffset)
                var line = Path()
                line.move(to: top)
                line.addLine(to: knob)
                ctx.stroke(line, with: .color(accent.opacity(0.9)), lineWidth: px)
            }
        }

        var handleCtx = base
        if !item.isLineLike { applyRotation(of: item, to: &handleCtx) }
        let r = 5 * px
        for (h, pos) in interactions.handlePositions(of: item) {
            let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
            let path = Path(ellipseIn: rect)
            if h == .rotate {
                handleCtx.fill(path, with: .color(accent))
                let ring = Path(ellipseIn: rect.insetBy(dx: -2 * px, dy: -2 * px))
                handleCtx.stroke(ring, with: .color(.white), lineWidth: px * 1.5)
            } else if h == .curveControl {
                handleCtx.fill(path, with: .color(Color.orange))
                let ring = Path(ellipseIn: rect.insetBy(dx: -1.5 * px, dy: -1.5 * px))
                handleCtx.stroke(ring, with: .color(.white), lineWidth: px * 1.5)
            } else {
                handleCtx.fill(path, with: .color(.white))
                handleCtx.stroke(path, with: .color(accent), lineWidth: 1.5 * px)
            }
        }
    }

    static func drawItem(
        _ item: AnnotationItem,
        in context: inout GraphicsContext,
        baseImage: NSImage?,
        blurredImage: NSImage?
    ) {
        let rect = AnnotationGeometry.itemRect(item)
        let style = StrokeStyle(lineWidth: item.lineWidth, lineCap: .round, lineJoin: .round)

        switch item.tool {
        case .select, .crop:
            break
        case .arrow:
            var p = Path()
            drawArrow(from: item.startPoint, to: item.endPoint, path: &p, headLength: max(14, item.lineWidth * 3.2))
            context.stroke(p, with: .color(item.color), style: style)
        case .curvedArrow:
            var p = Path()
            drawCurvedArrow(from: item.startPoint, to: item.endPoint, curveOffset: item.curveOffset, path: &p, headLength: max(14, item.lineWidth * 3.2))
            context.stroke(p, with: .color(item.color), style: style)
        case .rectangle:
            context.stroke(Path(rect), with: .color(item.color), style: style)
        case .roundedRect:
            let dashLen = max(4.0, item.lineWidth * 2.0)
            let dashedStyle = StrokeStyle(lineWidth: item.lineWidth, lineCap: .round, lineJoin: .round, dash: [dashLen, dashLen])
            let r = AnnotationGeometry.clampedCornerRadius(10, in: rect)
            context.stroke(Path(roundedRect: rect, cornerSize: CGSize(width: r, height: r)), with: .color(item.color), style: dashedStyle)
        case .ellipse:
            context.stroke(Path(ellipseIn: rect), with: .color(item.color), style: style)
        case .counter:
            let c = item.startPoint
            let path = Path(ellipseIn: CGRect(x: c.x - 16, y: c.y - 16, width: 32, height: 32))
            context.fill(path, with: .color(item.color))
            context.draw(Text("\(item.counterNumber)").font(.system(size: 15, weight: .bold)).foregroundColor(.white), at: c)
        case .blur:
            if let blurred = blurredImage {
                var clipped = context
                clipped.clip(to: Path(rect))
                clipped.draw(Image(nsImage: blurred), in: CGRect(origin: .zero, size: blurred.size))
            } else {
                context.fill(Path(rect), with: .color(Color.gray.opacity(0.7)))
            }
            context.stroke(Path(rect), with: .color(.white.opacity(0.35)), lineWidth: 1)
        case .spotlight:
            // Затемнение рисуется общим composite-проходом, здесь только белая рамка контура фокуса
            let r = AnnotationGeometry.clampedCornerRadius(8, in: rect)
            context.stroke(Path(roundedRect: rect, cornerSize: CGSize(width: r, height: r)), with: .color(.white.opacity(0.85)), lineWidth: 2)
        case .highlighter:
            var p = Path()
            p.move(to: item.startPoint)
            p.addLine(to: item.endPoint)
            context.stroke(
                p,
                with: .color(item.color.opacity(0.45)),
                style: StrokeStyle(lineWidth: item.lineWidth * 4, lineCap: .round, lineJoin: .round)
            )
        case .magnifier:
            drawMagnifier(item: item, rect: rect, in: &context, baseImage: baseImage)
        case .text:
            let t = Text(item.effectiveText)
                .font(.system(size: item.fontSize, weight: .bold))
                .foregroundColor(item.color)
            context.draw(t, at: item.startPoint, anchor: .topLeading)
        }
    }

    private static func drawMagnifier(
        item: AnnotationItem,
        rect: CGRect,
        in context: inout GraphicsContext,
        baseImage: NSImage?
    ) {
        let circleRect = AnnotationGeometry.magnifierCircleRect(for: rect)
        let circlePath = Path(ellipseIn: circleRect)
        let zoomFactor = CGFloat(item.scaleFactor > 0 ? item.scaleFactor : 2.0)
        let center = CGPoint(x: circleRect.midX, y: circleRect.midY)

        context.drawLayer { shadowCtx in
            shadowCtx.addFilter(.shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 4))
            shadowCtx.fill(circlePath, with: .color(.white))
        }

        if let baseImage {
            var clipped = context
            clipped.clip(to: circlePath)
            clipped.translateBy(x: center.x, y: center.y)
            clipped.scaleBy(x: zoomFactor, y: zoomFactor)
            clipped.translateBy(x: -center.x, y: -center.y)
            clipped.draw(Image(nsImage: baseImage), in: CGRect(origin: .zero, size: baseImage.size))
        } else {
            context.fill(circlePath, with: .color(.white.opacity(0.18)))
        }

        context.stroke(circlePath, with: .color(.white.opacity(0.95)), lineWidth: 4.0)
        context.stroke(Path(ellipseIn: circleRect.insetBy(dx: -1.5, dy: -1.5)), with: .color(.black.opacity(0.35)), lineWidth: 1.0)

        let labelText = AnnotationFormatting.zoomLabel(Double(zoomFactor))
        let label = Text(labelText)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
        let pillRect = CGRect(x: center.x - 20, y: circleRect.maxY - 22, width: 40, height: 16)
        context.fill(Path(roundedRect: pillRect, cornerRadius: 8), with: .color(Color.black.opacity(0.55)))
        context.draw(label, at: CGPoint(x: center.x, y: circleRect.maxY - 14))
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, path: inout Path, headLength: CGFloat) {
        path.move(to: start)
        path.addLine(to: end)
        let (tip1, tip2) = AnnotationGeometry.arrowHeadEndpoints(tip: end, from: start, headLength: headLength)
        path.move(to: end)
        path.addLine(to: tip1)
        path.move(to: end)
        path.addLine(to: tip2)
    }

    private static func drawCurvedArrow(from start: CGPoint, to end: CGPoint, curveOffset: CGFloat, path: inout Path, headLength: CGFloat) {
        guard let control = AnnotationGeometry.curvedControlPoint(start: start, end: end, curveOffset: curveOffset) else { return }
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        let (tip1, tip2) = AnnotationGeometry.arrowHeadEndpoints(tip: end, from: control, headLength: headLength)
        path.move(to: end)
        path.addLine(to: tip1)
        path.move(to: end)
        path.addLine(to: tip2)
    }
}
