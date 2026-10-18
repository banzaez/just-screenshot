import CoreGraphics

/// Общая геометрия диагональной стрелки (превью видео / burn-in GIF / CALayer MP4)
enum AnnotationArrowGeometry {
    struct Points {
        let start: CGPoint
        let end: CGPoint
        let headLeft: CGPoint
        let headRight: CGPoint
        let headLength: CGFloat
    }
    
    /// Стрелка из левого нижнего угла в правый верхний с отступами 4pt
    static func diagonal(in size: CGSize, lineWidth: CGFloat, inset: CGFloat = 4) -> Points {
        let start = CGPoint(x: inset, y: size.height - inset)
        let end = CGPoint(x: size.width - inset, y: inset)
        return from(start: start, end: end, lineWidth: lineWidth)
    }
    
    static func from(start: CGPoint, end: CGPoint, lineWidth: CGFloat) -> Points {
        let head = max(12, lineWidth * 3)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLeft = CGPoint(
            x: end.x - head * cos(angle - .pi / 6),
            y: end.y - head * sin(angle - .pi / 6)
        )
        let headRight = CGPoint(
            x: end.x - head * cos(angle + .pi / 6),
            y: end.y - head * sin(angle + .pi / 6)
        )
        return Points(start: start, end: end, headLeft: headLeft, headRight: headRight, headLength: head)
    }
    
    static func addToPath(_ path: CGMutablePath, points: Points) {
        path.move(to: points.start)
        path.addLine(to: points.end)
        path.move(to: points.end)
        path.addLine(to: points.headLeft)
        path.move(to: points.end)
        path.addLine(to: points.headRight)
    }
}
