import AppKit

/// Generates crisp, Retina-ready macOS menu bar icons matching the Just Screenshot brand.
enum StatusBarIcon {
    enum State {
        case idle
        case preparing
        case recording(paused: Bool)
    }

    private static let iconSize = NSSize(width: 18, height: 18)

    static func image(for state: State) -> NSImage {
        switch state {
        case .idle:
            return idleTemplateImage
        case .preparing:
            return preparingTemplateImage
        case .recording(let paused):
            return recordingImage(paused: paused)
        }
    }

    private static let idleTemplateImage: NSImage = {
        let image = NSImage(size: iconSize, flipped: false) { _ in
            drawViewfinderBrackets(color: .black, lineWidth: 1.6)

            // Center optical aperture ring
            let ringPath = NSBezierPath(ovalIn: NSRect(x: 5.75, y: 5.75, width: 6.5, height: 6.5))
            ringPath.lineWidth = 1.5
            NSColor.black.setStroke()
            ringPath.stroke()

            // Precision center dot
            let dotPath = NSBezierPath(ovalIn: NSRect(x: 7.75, y: 7.75, width: 2.5, height: 2.5))
            NSColor.black.setFill()
            dotPath.fill()

            return true
        }
        image.isTemplate = true
        return image
    }()

    private static let preparingTemplateImage: NSImage = {
        let image = NSImage(size: iconSize, flipped: false) { _ in
            drawViewfinderBrackets(color: .black, lineWidth: 1.6)

            // Crosshair lines inside viewfinder
            let cross = NSBezierPath()
            cross.lineWidth = 1.35
            cross.lineCapStyle = .round
            cross.move(to: NSPoint(x: 9, y: 5.5))
            cross.line(to: NSPoint(x: 9, y: 12.5))
            cross.move(to: NSPoint(x: 5.5, y: 9))
            cross.line(to: NSPoint(x: 12.5, y: 9))
            NSColor.black.setStroke()
            cross.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }()

    private static func recordingImage(paused: Bool) -> NSImage {
        let image = NSImage(size: iconSize, flipped: false) { _ in
            drawViewfinderBrackets(color: .labelColor, lineWidth: 1.6)

            let dotColor: NSColor = paused ? .systemOrange : .systemRed
            let dotPath = NSBezierPath(ovalIn: NSRect(x: 5.5, y: 5.5, width: 7.0, height: 7.0))
            dotColor.setFill()
            dotPath.fill()

            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawViewfinderBrackets(color: NSColor, lineWidth: CGFloat) {
        let minC: CGFloat = 2.25
        let maxC: CGFloat = 15.75
        let arm: CGFloat = 3.6
        let r: CGFloat = 1.8

        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        // Top-left
        path.move(to: NSPoint(x: minC, y: maxC - arm))
        path.line(to: NSPoint(x: minC, y: maxC - r))
        path.curve(
            to: NSPoint(x: minC + r, y: maxC),
            controlPoint1: NSPoint(x: minC, y: maxC),
            controlPoint2: NSPoint(x: minC, y: maxC)
        )
        path.line(to: NSPoint(x: minC + arm, y: maxC))

        // Top-right
        path.move(to: NSPoint(x: maxC - arm, y: maxC))
        path.line(to: NSPoint(x: maxC - r, y: maxC))
        path.curve(
            to: NSPoint(x: maxC, y: maxC - r),
            controlPoint1: NSPoint(x: maxC, y: maxC),
            controlPoint2: NSPoint(x: maxC, y: maxC)
        )
        path.line(to: NSPoint(x: maxC, y: maxC - arm))

        // Bottom-right
        path.move(to: NSPoint(x: maxC, y: minC + arm))
        path.line(to: NSPoint(x: maxC, y: minC + r))
        path.curve(
            to: NSPoint(x: maxC - r, y: minC),
            controlPoint1: NSPoint(x: maxC, y: minC),
            controlPoint2: NSPoint(x: maxC, y: minC)
        )
        path.line(to: NSPoint(x: maxC - arm, y: minC))

        // Bottom-left
        path.move(to: NSPoint(x: minC + arm, y: minC))
        path.line(to: NSPoint(x: minC + r, y: minC))
        path.curve(
            to: NSPoint(x: minC, y: minC + r),
            controlPoint1: NSPoint(x: minC, y: minC),
            controlPoint2: NSPoint(x: minC, y: minC)
        )
        path.line(to: NSPoint(x: minC, y: minC + arm))

        color.setStroke()
        path.stroke()
    }
}
