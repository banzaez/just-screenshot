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
        
        static let videoColor = "editor_pref_video_color"
        static let videoLineWidth = "editor_pref_video_lineWidth"
        static let videoFontSize = "editor_pref_video_fontSize"
        static let videoPlaybackRate = "editor_pref_video_playbackRate"
    }
    
    // MARK: - Image editor
    
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
    
    // MARK: - Video editor
    
    static var videoColor: Color {
        get { loadColor(key: Keys.videoColor) ?? .red }
        set { saveColor(newValue, key: Keys.videoColor) }
    }
    
    static var videoLineWidth: CGFloat {
        get {
            let v = UserDefaults.standard.object(forKey: Keys.videoLineWidth) as? Double
            return CGFloat(v ?? 3)
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: Keys.videoLineWidth) }
    }
    
    static var videoFontSize: CGFloat {
        get {
            let v = UserDefaults.standard.object(forKey: Keys.videoFontSize) as? Double
            return CGFloat(v ?? 20)
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: Keys.videoFontSize) }
    }
    
    static var videoPlaybackRate: Float {
        get {
            let v = UserDefaults.standard.object(forKey: Keys.videoPlaybackRate) as? Float
            return v ?? 1.0
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.videoPlaybackRate) }
    }
    
    // MARK: - Color encode
    
    private static func saveColor(_ color: Color, key: String) {
        let ns = NSColor(color)
        var r: CGFloat = 1, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        ns.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
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
