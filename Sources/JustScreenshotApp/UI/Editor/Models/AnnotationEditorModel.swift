import SwiftUI
import AppKit

/// Наблюдаемая модель состояния редактора для поддержки подтверждения при закрытии (NSAlert)
@MainActor
public final class AnnotationEditorModel: ObservableObject {
    public let capturedItem: CapturedItem
    
    @Published public var items: [AnnotationItem] = []
    @Published public var showBackdrop: Bool = true
    @Published public var backdropPreset: BackdropPreset = .aurora
    @Published public var backdropPadding: CGFloat = 48
    @Published public var backdropCornerRadius: CGFloat = 12
    @Published public var backdropShadowRadius: CGFloat = 24
    @Published public var addShadow: Bool = true
    
    public private(set) var hasUnsavedChanges: Bool = false
    private var initialLoaded = false
    
    public init(capturedItem: CapturedItem) {
        self.capturedItem = capturedItem
    }
    
    public func markSaved() {
        hasUnsavedChanges = false
    }
    
    public func markModified() {
        if initialLoaded {
            hasUnsavedChanges = true
        }
    }
    
    public func finishInitialLoading() {
        initialLoaded = true
        hasUnsavedChanges = false
    }
    
    public func renderFinalImage() -> NSImage {
        AnnotationRenderer.render(
            baseImage: capturedItem.image,
            items: items,
            backdrop: showBackdrop ? backdropPreset : nil,
            padding: backdropPadding,
            cornerRadius: backdropCornerRadius,
            shadowRadius: backdropShadowRadius,
            shadow: addShadow
        )
    }
}
