import SwiftUI
import AppKit
import Observation

/// Реактивное состояние закреплённого окна для синхронизации UI при глобальной разблокировке
@Observable
@MainActor
public final class PinState {
    public var isClickThrough: Bool = false

    public init(isClickThrough: Bool = false) {
        self.isClickThrough = isClickThrough
    }
}

/// Запись о закреплённом окне
@MainActor
final class PinRecord {
    let managed: ManagedWindow
    let state: PinState
    let sourceItemID: UUID?

    init(managed: ManagedWindow, state: PinState, sourceItemID: UUID?) {
        self.managed = managed
        self.state = state
        self.sourceItemID = sourceItemID
    }
}

/// Реестр управляемых окон приложения (редакторы, пины, панели истории и настроек)
@MainActor
final class WindowRegistry {
    var editors: [UUID: ManagedWindow] = [:]
    var videoEditors: [UUID: ManagedWindow] = [:]
    var pins: [UUID: PinRecord] = [:]
    var historyWindow: ManagedWindow?
    var settingsWindow: ManagedWindow?
    var cascadePoint = NSPoint.zero
}

/// Состояние пула оверлеев выбора области/окна
@MainActor
final class OverlayPoolState {
    var overlayWindows: [AreaOverlayWindow] = []
    var overlayPool: [CGDirectDisplayID: AreaOverlayWindow] = [:]
    var overlayToken = UUID()
    var samplerInFlight: Set<CGDirectDisplayID> = []
    var failedSamplerDisplays: Set<CGDirectDisplayID> = []
    var isCapturePreparing: Bool = false
    let escMonitor = EscapeMonitor()
}

/// Состояние активного отложенного скриншота
@MainActor
final class TimedCaptureSession {
    let dimWindows: [RecordingDimOverlayWindow]
    let countdownWindow: CountdownOverlayWindow
    let escMonitor: EscapeMonitor
    var isCancelled = false

    init(
        dimWindows: [RecordingDimOverlayWindow],
        countdownWindow: CountdownOverlayWindow,
        escMonitor: EscapeMonitor
    ) {
        self.dimWindows = dimWindows
        self.countdownWindow = countdownWindow
        self.escMonitor = escMonitor
    }

    func cancelAndClose() {
        isCancelled = true
        escMonitor.stop()
        countdownWindow.cancel()
        countdownWindow.close()
        for win in dimWindows {
            win.orderOut(nil)
            win.contentView = nil
            win.close()
        }
    }
}

/// Фаза конечного автомата видеозаписи
public enum RecordingPhase: Equatable, Sendable {
    case idle
    case selectingArea
    case preparing
    case countdown
    case starting
    case recording
    case stopping
}

/// Состояние сессии и оверлейных окон видеозаписи
@MainActor
final class RecordingSessionState {
    var frameWindow: RecordingFrameWindow?
    var effectsWindow: RecordingEffectsOverlayWindow?
    var barWindow: RecordingControlBarWindow?
    var countdownWindow: CountdownOverlayWindow?
    var dimWindows: [RecordingDimOverlayWindow] = []
    let setupEscMonitor = EscapeMonitor()
    let countdownEscMonitor = EscapeMonitor()
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

    public var recordingPhase: RecordingPhase = .idle

    public var isRecordingPreparing: Bool {
        recordingPhase == .preparing || recordingPhase == .countdown || recordingPhase == .starting
    }

    public var isRecording: Bool {
        recordingPhase == .recording
    }

    public var isRecordingPaused: Bool = false
    public var recordingDuration: TimeInterval = 0
    public var recordingRect: CGRect = .zero
    public var hasLockedPins: Bool = false

    @ObservationIgnored var lockedPinIDs: Set<UUID> = []
    @ObservationIgnored var pinOptionLocalMonitor: Any?
    @ObservationIgnored var pinOptionGlobalMonitor: Any?
    @ObservationIgnored nonisolated(unsafe) var pinResignActiveObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) var screenChangeObserver: NSObjectProtocol?

    @ObservationIgnored let overlayState = OverlayPoolState()
    @ObservationIgnored let recordingState = RecordingSessionState()
    @ObservationIgnored var timedCaptureSession: TimedCaptureSession?
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
    var pins: [UUID: PinRecord] {
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

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pruneDisconnectedOverlayDisplays()
            }
        }
    }

    deinit {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
        if let pinResignActiveObserver {
            NotificationCenter.default.removeObserver(pinResignActiveObserver)
        }
    }

    // MARK: - Горячие клавиши

    public func reloadGlobalHotkeys() {
        hotKeyCoordinator.reload()
    }

    // MARK: - Общие диалоги

    @discardableResult
    func presentAlert(
        title: String,
        message: String,
        style: NSAlert.Style = .warning,
        buttonTitle: String? = nil
    ) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: buttonTitle ?? L("alert.ok"))
        NSApp.activate()
        return alert.runModal()
    }
}
