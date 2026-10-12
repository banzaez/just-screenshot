import SwiftUI
import AppKit

/// Главный контроллер интерфейса: оверлеи выбора, стек HUD, редакторы, история, закрепы, запись
@MainActor
public final class AppWindowManager: ObservableObject {
    public static let shared = AppWindowManager()
    
    @Published public var currentCapturedItem: CapturedItem?
    @Published public var isRecording: Bool = false
    @Published public var isRecordingPaused: Bool = false
    @Published public var recordingDuration: TimeInterval = 0
    
    var overlayWindow: AreaOverlayWindow?
    var overlayToken = UUID()
    var recordingFrameWindow: RecordingFrameWindow?
    var recordingBarWindow: RecordingControlBarWindow?
    let hudStack = HUDStackManager()
    var editors: [UUID: ManagedWindow] = [:]
    var videoEditors: [UUID: ManagedWindow] = [:]
    var pins: [UUID: ManagedWindow] = [:]
    var historyWindow: ManagedWindow?
    var settingsWindow: ManagedWindow?
    var cascadePoint = NSPoint.zero
    var recordingTimer: Timer?
    
    let history = HistoryStore.shared
    private lazy var hotKeyCoordinator = AppHotKeyCoordinator(windowManager: self)
    
    private init() {
        hotKeyCoordinator.setup()
    }
    
    // MARK: - Горячие клавиши
    
    public func reloadGlobalHotkeys() {
        hotKeyCoordinator.reload()
    }
}
