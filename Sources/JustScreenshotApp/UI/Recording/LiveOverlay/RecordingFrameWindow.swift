import Cocoa

/// Прозрачное окно-рамка поверх выбранной области экрана, показывающее границы записи
public final class RecordingFrameWindow: NSWindow {
    public init(screenRect: CGRect) {
        // screenRect здесь в экранных координатах AppKit (origin внизу экрана)
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true // Клики проходят сквозь рамку в приложения под ней
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let borderView = RecordingBorderNSView(frame: NSRect(origin: .zero, size: screenRect.size))
        self.contentView = borderView
    }
}

private final class RecordingBorderNSView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Красная пульсирующая/яркая рамка вокруг записываемой области
        let insetRect = bounds.insetBy(dx: 1.5, dy: 1.5)
        context.setStrokeColor(CGColor(red: 1.0, green: 0.22, blue: 0.22, alpha: 0.9))
        context.setLineWidth(3.0)
        
        let path = CGPath(roundedRect: insetRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        context.addPath(path)
        context.strokePath()
        
        // Маленькие маркеры по 4 углам для визуального акцента
        let cornerLen: CGFloat = 16.0
        context.setLineWidth(4.0)
        context.setStrokeColor(CGColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0))
        
        // Нижний левый угол
        context.move(to: CGPoint(x: bounds.minX + 1.5, y: bounds.minY + cornerLen))
        context.addLine(to: CGPoint(x: bounds.minX + 1.5, y: bounds.minY + 1.5))
        context.addLine(to: CGPoint(x: bounds.minX + cornerLen, y: bounds.minY + 1.5))
        
        // Нижний правый угол
        context.move(to: CGPoint(x: bounds.maxX - cornerLen, y: bounds.minY + 1.5))
        context.addLine(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.minY + 1.5))
        context.addLine(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.minY + cornerLen))
        
        // Верхний правый угол
        context.move(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.maxY - cornerLen))
        context.addLine(to: CGPoint(x: bounds.maxX - 1.5, y: bounds.maxY - 1.5))
        context.addLine(to: CGPoint(x: bounds.maxX - cornerLen, y: bounds.maxY - 1.5))
        
        // Верхний левый угол
        context.move(to: CGPoint(x: bounds.minX + cornerLen, y: bounds.maxY - 1.5))
        context.addLine(to: CGPoint(x: bounds.minX + 1.5, y: bounds.maxY - 1.5))
        context.addLine(to: CGPoint(x: bounds.minX + 1.5, y: bounds.maxY - cornerLen))
        
        context.strokePath()
    }
}
