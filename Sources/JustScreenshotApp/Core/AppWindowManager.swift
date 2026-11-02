import SwiftUI
import AppKit
import Observation

/// Реестр управляемых окон приложения (редакторы, пины, панели истории и настроек)
@MainActor
final class WindowRegistry {
    var editors: [UUID: ManagedWindow] = [:]
    var videoEditors: [UUID: ManagedWindow] = [:]
    var pins: [UUID: ManagedWindow] = [:]
    var historyWindow: ManagedWindow?
    var settingsWindow: ManagedWindow?
    var cascadePoint = NSPoint.zero
}

/// Состояние пула оверлеев выбора области/окна
@MainActor
final class OverlayPoolState {
    var overlayWindows: [AreaOverlayWindow] = []
    /// Пул оверлеев по displayID — без повторного alloc на каждый хоткей.
    var overlayPool: [CGDirectDisplayID: AreaOverlayWindow] = [:]
    var overlayToken = UUID()
    var samplerInFlight: Set<CGDirectDisplayID> = []
    var overlayEscLocalMonitor: Any?
    var overlayEscGlobalMonitor: Any?
}

/// Состояние сессии и оверлейных окон видеозаписи
@MainActor
final class RecordingSessionState {
    var frameWindow: RecordingFrameWindow?
    var effectsWindow: RecordingEffectsOverlayWindow?
    var barWindow: RecordingControlBarWindow?
    var dimWindows: [RecordingDimOverlayWindow] = []
    var timer: Timer?
    var startedAt: Date?
    var pausedAt: Date?
    var accumulatedPause: TimeInterval = 0
}

/// Главный контроллер интерфейса: оверлеи выбора, стек HUD, редакторы, история, закрепы, запись
@Observable
@MainActor
public final class AppWindowManager {
    public static let shared = AppWindowManager()
    
    public var currentCapturedItem: CapturedItem?
    public var isRecordingPreparing: Bool = false
    public var isRecording: Bool = false
    public var isRecordingPaused: Bool = false
    public var recordingDuration: TimeInterval = 0
    public var recordingRect: CGRect = .zero
    
    @ObservationIgnored let overlayState = OverlayPoolState()
    @ObservationIgnored let recordingState = RecordingSessionState()
    @ObservationIgnored let windowRegistry = WindowRegistry()
    @ObservationIgnored let hudStack = HUDStackManager()
    @ObservationIgnored let history = HistoryStore.shared
    @ObservationIgnored private lazy var hotKeyCoordinator = AppHotKeyCoordinator(windowManager: self)
    
    // Прокси-свойства для модульных расширений WindowManager
    var overlayWindows: [AreaOverlayWindow] {
        get { overlayState.overlayWindows }
        set { overlayState.overlayWindows = newValue }
    }
    var overlayPool: [CGDirectDisplayID: AreaOverlayWindow] {
        get { overlayState.overlayPool }
        set { overlayState.overlayPool = newValue }
    }
    var overlayToken: UUID {
        get { overlayState.overlayToken }
        set { overlayState.overlayToken = newValue }
    }
    var samplerInFlight: Set<CGDirectDisplayID> {
        get { overlayState.samplerInFlight }
        set { overlayState.samplerInFlight = newValue }
    }
    var overlayEscLocalMonitor: Any? {
        get { overlayState.overlayEscLocalMonitor }
        set { overlayState.overlayEscLocalMonitor = newValue }
    }
    var overlayEscGlobalMonitor: Any? {
        get { overlayState.overlayEscGlobalMonitor }
        set { overlayState.overlayEscGlobalMonitor = newValue }
    }
    var recordingFrameWindow: RecordingFrameWindow? {
        get { recordingState.frameWindow }
        set { recordingState.frameWindow = newValue }
    }
    var recordingEffectsWindow: RecordingEffectsOverlayWindow? {
        get { recordingState.effectsWindow }
        set { recordingState.effectsWindow = newValue }
    }
    var recordingBarWindow: RecordingControlBarWindow? {
        get { recordingState.barWindow }
        set { recordingState.barWindow = newValue }
    }
    var recordingDimWindows: [RecordingDimOverlayWindow] {
        get { recordingState.dimWindows }
        set { recordingState.dimWindows = newValue }
    }
    var recordingTimer: Timer? {
        get { recordingState.timer }
        set { recordingState.timer = newValue }
    }
    var recordingStartedAt: Date? {
        get { recordingState.startedAt }
        set { recordingState.startedAt = newValue }
    }
    var recordingPausedAt: Date? {
        get { recordingState.pausedAt }
        set { recordingState.pausedAt = newValue }
    }
    var recordingAccumulatedPause: TimeInterval {
        get { recordingState.accumulatedPause }
        set { recordingState.accumulatedPause = newValue }
    }
    var editors: [UUID: ManagedWindow] {
        get { windowRegistry.editors }
        set { windowRegistry.editors = newValue }
    }
    var videoEditors: [UUID: ManagedWindow] {
        get { windowRegistry.videoEditors }
        set { windowRegistry.videoEditors = newValue }
    }
    var pins: [UUID: ManagedWindow] {
        get { windowRegistry.pins }
        set { windowRegistry.pins = newValue }
    }
    var historyWindow: ManagedWindow? {
        get { windowRegistry.historyWindow }
        set { windowRegistry.historyWindow = newValue }
    }
    var settingsWindow: ManagedWindow? {
        get { windowRegistry.settingsWindow }
        set { windowRegistry.settingsWindow = newValue }
    }
    var cascadePoint: NSPoint {
        get { windowRegistry.cascadePoint }
        set { windowRegistry.cascadePoint = newValue }
    }
    
    private init() {
        hotKeyCoordinator.setup()
    }
    
    // MARK: - Горячие клавиши
    
    public func reloadGlobalHotkeys() {
        hotKeyCoordinator.reload()
    }
}
