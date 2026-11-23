import Foundation
import SwiftUI
import AppKit

/// Персистентные настройки редакторов скриншотов и видео (UserDefaults)
@MainActor
enum EditorPreferences {
    private enum Keys {
        static let tool = "editor_pref_tool"
        static let color = "editor_pref_color"
        static let lineWidth = "editor_pref_lineWidth"
        static let fontSize = "editor_pref_fontSize"
        static let showBackdrop = "editor_pref_showBackdrop"
        static let backdropPreset = "editor_pref_backdropPreset"
        static let backdropPadding = "editor_pref_backdropPadding"
        static let backdropCornerRadius = "editor_pref_backdropCornerRadius"
        static let backdropShadowRadius = "editor_pref_backdropShadowRadius"
        static let addShadow = "editor_pref_addShadow"
        static let showWindowFrame = "editor_pref_showWindowFrame"

        static let videoPlaybackRate = "editor_pref_video_playbackRate"
        static let videoSmartZoomEnabled = "editor_pref_video_smartZoomEnabled"
        static let videoSmartZoomScale = "editor_pref_video_smartZoomScale"
        static let videoSmartZoomMode = "editor_pref_video_smartZoomMode"
        static let videoAutoZoomOutOnIdle = "editor_pref_video_autoZoomOutOnIdle"
        static let videoBlurStyle = "editor_pref_video_blurStyle"
        static let videoBlurIntensity = "editor_pref_video_blurIntensity"
        static let videoKeystrokesEnabled = "editor_pref_video_keystrokesEnabled"
        static let videoKeystrokeFilter = "editor_pref_video_keystrokeFilter"
        static let videoKeystrokePosition = "editor_pref_video_keystrokePosition"
        static let videoKeystrokeSize = "editor_pref_video_keystrokeSize"
        static let videoTypingHighlightEnabled = "editor_pref_video_typingHighlightEnabled"
        static let videoClickHighlightsEnabled = "editor_pref_video_clickHighlightsEnabled"
    }

    static var tool: AnnotationTool {
        get {
            let key = UserDefaults.standard.string(forKey: Keys.tool) ?? ""
            return AnnotationTool.from(storageKey: key) ?? .arrow
        }
        set { UserDefaults.standard.set(newValue.storageKey, forKey: Keys.tool) }
    }

    static var color: Color {
        get { loadColor(key: Keys.color) ?? .red }
        set { saveColor(newValue, key: Keys.color) }
    }

    static var lineWidth: CGFloat {
        get {
            let v = UserDefaults.standard.object(forKey: Keys.lineWidth) as? Double
            return CGFloat(v ?? 4)
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: Keys.lineWidth) }
    }

    static var fontSize: CGFloat {
        get {
            let v = UserDefaults.standard.object(forKey: Keys.fontSize) as? Double
            return CGFloat(v ?? 22)
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: Keys.fontSize) }
    }

    static var showBackdrop: Bool {
        get { UserDefaults.standard.object(forKey: Keys.showBackdrop) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.showBackdrop) }
    }

    static var backdropPreset: BackdropPreset {
        get {
            let key = UserDefaults.standard.string(forKey: Keys.backdropPreset) ?? ""
            return BackdropPreset.from(storageKey: key) ?? .aurora
        }
        set { UserDefaults.standard.set(newValue.storageKey, forKey: Keys.backdropPreset) }
    }

    static var backdropPadding: CGFloat {
        get {
            let v = UserDefaults.standard.object(forKey: Keys.backdropPadding) as? Double
            return CGFloat(v ?? 48)
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: Keys.backdropPadding) }
    }

    static var backdropCornerRadius: CGFloat {
        get {
            let v = UserDefaults.standard.object(forKey: Keys.backdropCornerRadius) as? Double
            return CGFloat(v ?? 12)
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: Keys.backdropCornerRadius) }
    }

    static var backdropShadowRadius: CGFloat {
        get {
            let v = UserDefaults.standard.object(forKey: Keys.backdropShadowRadius) as? Double
            return CGFloat(v ?? 24)
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: Keys.backdropShadowRadius) }
    }

    static var addShadow: Bool {
        get { UserDefaults.standard.object(forKey: Keys.addShadow) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.addShadow) }
    }

    static var showWindowFrame: Bool {
        get { UserDefaults.standard.object(forKey: Keys.showWindowFrame) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Keys.showWindowFrame) }
    }

    static var videoPlaybackRate: Float {
        get {
            let v = UserDefaults.standard.object(forKey: Keys.videoPlaybackRate) as? Float
            return v ?? 1.0
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.videoPlaybackRate) }
    }

    static var videoSmartZoomEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.videoSmartZoomEnabled) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Keys.videoSmartZoomEnabled) }
    }

    static var videoSmartZoomScale: SmartZoomScale {
        get {
            let raw = UserDefaults.standard.double(forKey: Keys.videoSmartZoomScale)
            return SmartZoomScale(rawValue: raw) ?? .balanced
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.videoSmartZoomScale) }
    }

    static var videoSmartZoomMode: SmartZoomMode {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.videoSmartZoomMode) ?? ""
            return SmartZoomMode(rawValue: raw) ?? .onClicks
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.videoSmartZoomMode) }
    }

    static var videoAutoZoomOutOnIdle: Bool {
        get { UserDefaults.standard.object(forKey: Keys.videoAutoZoomOutOnIdle) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.videoAutoZoomOutOnIdle) }
    }

    static var videoBlurStyle: VideoBlurStyle {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.videoBlurStyle) ?? ""
            return VideoBlurStyle(rawValue: raw) ?? .frostedGlass
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.videoBlurStyle) }
    }

    static var videoBlurIntensity: VideoBlurIntensity {
        get {
            let raw = UserDefaults.standard.double(forKey: Keys.videoBlurIntensity)
            return VideoBlurIntensity(rawValue: raw) ?? .medium
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.videoBlurIntensity) }
    }

    static var videoKeystrokesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.videoKeystrokesEnabled) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Keys.videoKeystrokesEnabled) }
    }

    static var videoKeystrokeFilter: KeystrokeDisplayFilter {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.videoKeystrokeFilter) ?? ""
            return KeystrokeDisplayFilter(rawValue: raw) ?? .all
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.videoKeystrokeFilter) }
    }

    static var videoKeystrokePosition: KeystrokePosition {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.videoKeystrokePosition) ?? ""
            return KeystrokePosition(rawValue: raw) ?? .bottomCenter
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.videoKeystrokePosition) }
    }

    static var videoKeystrokeSize: KeystrokeSize {
        get {
            let raw = UserDefaults.standard.double(forKey: Keys.videoKeystrokeSize)
            return KeystrokeSize(rawValue: raw) ?? .standard
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.videoKeystrokeSize) }
    }

    static var videoTypingHighlightEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.videoTypingHighlightEnabled) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Keys.videoTypingHighlightEnabled) }
    }

    static var videoClickHighlightsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.videoClickHighlightsEnabled) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Keys.videoClickHighlightsEnabled) }
    }

    private static func saveColor(_ color: Color, key: String) {
        let ns = NSColor(color)
        guard let converted = ns.usingColorSpace(.sRGB) ?? ns.usingColorSpace(.deviceRGB) else {
            return
        }
        var r: CGFloat = 1, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)
        UserDefaults.standard.set([Double(r), Double(g), Double(b), Double(a)], forKey: key)
    }

    private static func loadColor(key: String) -> Color? {
        guard let comps = UserDefaults.standard.array(forKey: key) as? [Double], comps.count == 4 else {
            return nil
        }
        return Color(
            .sRGB,
            red: comps[0],
            green: comps[1],
            blue: comps[2],
            opacity: comps[3]
        )
    }
}
