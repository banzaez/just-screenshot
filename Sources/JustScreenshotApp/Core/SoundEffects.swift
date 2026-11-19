import AppKit

/// Воспроизведение системных звуковых эффектов с учётом пользовательской настройки `playSound`
@MainActor
enum SoundEffects {
    private static let shutterPaths = [
        "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif",
        "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Shutter.aif"
    ]

    private static var cachedShutterSound: NSSound? = {
        for path in shutterPaths {
            if FileManager.default.fileExists(atPath: path),
               let sound = NSSound(contentsOfFile: path, byReference: true) {
                return sound
            }
        }
        return NSSound(named: "Pop")
    }()

    private static var cachedRecordStartSound: NSSound? = NSSound(named: "Purr")
    private static var cachedTickSound: NSSound? = NSSound(named: "Tink")

    static func playShutter() {
        guard AppSettings.shared.playSound else { return }
        play(cachedShutterSound)
    }

    static func playRecordStart() {
        guard AppSettings.shared.playSound else { return }
        play(cachedRecordStartSound)
    }

    static func playTick() {
        guard AppSettings.shared.playSound else { return }
        play(cachedTickSound)
    }

    private static func play(_ sound: NSSound?) {
        guard let sound else { return }
        if sound.isPlaying {
            sound.stop()
        }
        sound.play()
    }
}
