<p align="center">
  <img src="Sources/JustScreenshotApp/Resources/icon_1024.png" width="120" height="120" alt="Just Screenshot App Icon" />
</p>

<h1 align="center">Just Screenshot</h1>

<p align="center">
  <strong>The native, blazingly fast screen capture, recording, and annotation studio for macOS.</strong><br>
  Crafted with Swift 6, SwiftUI, and ScreenCaptureKit. 100% on-device, lightweight, and private.
</p>

<p align="center">
  <a href="https://github.com/banzaez/just-screenshot/releases"><img src="https://img.shields.io/github/v/release/banzaez/just-screenshot?color=34C759&label=Latest%20Release" alt="Release Version"></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%7C%2015.0%2B%20Sequoia-007AFF?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?logo=swift" alt="Swift 6">
  <img src="https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%2F%20Intel)-5856D6" alt="Universal Architecture">
  <img src="https://img.shields.io/badge/Privacy-100%25%20On--Device-34C759" alt="100% On-Device Privacy">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License">
</p>

---

## 🌟 Highlights

- **⚡ Native Performance**: Built pure Swift 6 with AppKit & SwiftUI — instantaneous launch, sub-10ms capture response, zero Electron bloat.
- **📸 High-Precision Capture**: Interactive pixel-level crosshair, real-time magnifying loupe with HEX color sampler, and smart window snapping.
- **🎥 Next-Gen Screen Recording**: 60 FPS hardware acceleration via Apple **ScreenCaptureKit**, simultaneous microphone/system audio, live keystroke display, and click animations.
- **🎬 Smart Zoom & Video Trimmer**: Dynamic cursor-following camera zoom, in-app video trimming, playback speed control (0.5x–2x), and annotation burn-in.
- **🎨 Social-Ready Presentation Backdrops**: Turn screenshots into polished graphics with designer gradient canvas presets, drop shadows, and Liquid Glass borders.
- **✏️ Pro Annotation Studio**: Arrows, bezier curves, auto-incrementing step markers (1-2-3), text callouts, redaction blur, loupe zoom, and spotlight focus.
- **🔍 Private On-Device OCR**: Instant text extraction from screen selections using Apple **Vision** framework without cloud latency or data transmission.
- **📌 Pin to Screen**: Float screenshots on top of all windows with adjustable opacity for seamless side-by-side reference.
- **🔒 Privacy First**: Zero tracking, zero telemetry, no accounts required. All processing stays strictly local on your Mac.

---

## 🚀 Key Features

### 1. Precision Screen Capture
- **Crosshair Selection**: Drag to capture arbitrary areas with real-time dimension badges ($W \times H$) and Retina pixel coordinates.
- **Integrated Pixel Loupe & HEX Sampler**: Live zoomed pixel grid with immediate `#RRGGBB` color sampling beneath your cursor.
- **Smart Window Snapping**: Hover over any open window to detect borders and capture cleanly rendered window frames with authentic macOS drop shadows.
- **Repeat Last Capture (`⌘ + ⌥ + 5`)**: Re-capture the exact same screen coordinates instantaneously without re-dragging.
- **Multi-Monitor Awareness**: Handles mixed-DPI multi-display setups seamlessly across Retina and external monitors.

### 2. High-Performance Screen Recording
- **ScreenCaptureKit Engine**: Low-CPU, low-latency 60 FPS recording directly from Apple's modern graphics pipeline.
- **Live Overlays & Visual Feedback**:
  - **Live Keystroke Visualizer**: Formats and displays pressed modifier combinations and hotkeys on-screen during recording.
  - **Cursor Click Effects**: Animated concentric ripples for left and right mouse clicks.
  - **Bounds & Frame Guide**: Pulsing boundary frame with darkened vignette dimming outside the active capture area.
  - **Floating Control Dock**: In-recording toolbar to pause, resume, discard, or finish recordings with an elapsed timer.
  - **Pre-Recording Countdown**: Optional 3s / 5s countdown overlay.
- **Multi-Source Audio**: Capture system audio and microphone input with synchronized AVFoundation muxing.
- **Versatile Export Options**:
  - **MP4 (H.264)**: Universal hardware-accelerated video for presentations and web uploads.
  - **Animated WebP**: High-compression modern animations powered by native `libwebp`.
  - **Animated GIF**: Highly optimized legacy animation exporter.

### 3. Video Studio & Smart Zoom
- **Smart Zoom (Camera Follow)**: Automatically tracks cursor movements and click events to create smooth, cinematic camera pans and zooms (inspired by professional screencast tools).
- **Timeline Trimmer**: Frame-accurate visual timeline with video preview thumbnails and adjustable In/Out trim markers.
- **Playback Controls**: Variable playback rates (0.5x, 1x, 1.5x, 2x) for rapid reviewing.
- **Annotation Burn-In**: Overlay shapes, text callouts, and blurs directly into exported video files.

### 4. Annotation Studio & Presentation Canvas
- **Drawing Tools**: Linear arrows, curved bezier arrows, rectangles, rounded cards, and ellipses.
- **Step Counters (1-2-3)**: Auto-incrementing numbered badge markers — ideal for bug repro steps and technical documentation.
- **Spotlight & Loupe**: Dim the background to illuminate focus regions or magnify details with a circular optical loupe.
- **Privacy Redaction**: Pixelate / blur sensitive credentials, passwords, tokens, and personal data.
- **Presentation Canvas Backdrops**: Wrap captures in gradient canvas backgrounds with rounded corners and soft drop shadows:
  - 🌌 *Aurora* • 🌊 *Ocean* • 🌅 *Sunset* • 🌲 *Forest* • 🪨 *Graphite* • ❄️ *Snow*
- **Undo / Redo History**: Full transactional history with standard keyboard shortcuts.

### 5. Floating Quick-Access HUD
Right after capture, an elegant floating card appears non-intrusively near your workspace:
- **Copy**: Copy directly to clipboard as PNG/TIFF.
- **Save**: Save directly to your default capture directory (`~/Movies` or custom folder).
- **Edit**: Open directly in the full-screen annotation canvas.
- **Pin**: Detach into an always-on-top reference widget.
- **OCR**: Extract text into your clipboard in under a second.
- **Stack Manager**: Handles burst captures with automatic card stacking.

### 6. On-Device OCR (Optical Character Recognition)
- Extract text from unselectable elements, diagrams, PDFs, and video streams in one keystroke (`⌘ + ⌥ + 6`).
- Powered entirely by Apple's on-device **Vision framework**. No network round-trips; complete data privacy.

### 7. Native macOS Polish
- **Menu Bar Utility**: Runs unobtrusively in the system status bar (`LSUIElement`) with zero Dock clutter.
- **Launch at Login**: Managed via modern Apple `SMAppService` API.
- **Seamless Auto-Updates**: Ed25519 cryptographically signed updates powered by **Sparkle 2**.
- **Liquid Glass Settings**: macOS Sonoma-inspired translucent UI with customizable keyboard recorder.
- **8 Built-In Languages**: 🇺🇸 English, 🇩🇪 German, 🇫🇷 French, 🇪🇸 Spanish, 🇯🇵 Japanese, 🇨🇳 Chinese, 🇺🇦 Ukrainian, 🇷🇺 Russian.

---

## ⌨️ Keyboard Shortcuts

All shortcuts are globally registered and fully configurable in **Settings → Hotkeys** (with support for secondary alternative bindings):

| Action | Default Shortcut | Alternative / Dual-Key | Description |
|:---|:---:|:---:|:---|
| **Area Capture** | <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>5</kbd> | Customizable | Rectangular selection with live pixel sampler |
| **Window Capture** | <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>4</kbd> | Customizable | Smart window detection with shadow preservation |
| **Screen Recording** | <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>3</kbd> | Customizable | Start/stop ScreenCaptureKit video recording |
| **Repeat Last Capture** | <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>5</kbd> | Customizable | Instantly capture previous region |
| **Text Capture (OCR)** | <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>6</kbd> | Customizable | Extract text from region directly to clipboard |
| **Capture History** | <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>H</kbd> | Customizable | Open searchable capture library |

---

## 🏗️ Architecture & Technology Stack

| Layer | Technologies | Role |
|:---|:---|:---|
| **Language & Concurrency** | Swift 6.0 | Modern language features, strict concurrency (`@MainActor`, Sendable) |
| **UI & Windows** | SwiftUI + AppKit | Modern reactive views combined with low-level window & overlay management |
| **Capture Pipeline** | `ScreenCaptureKit` + `CoreGraphics` | Hardware-accelerated 60 FPS display streaming and low-latency frame sampling |
| **Video & Encoding** | `AVFoundation` + `libwebp` (`webp.swift`) | High-performance MP4/H.264 muxing, GIF rendering, and animated WebP export |
| **Computer Vision** | `Vision.framework` | On-device machine-learning text recognition (OCR) |
| **System Integration** | `SMAppService`, `Carbon.HIToolbox` | Login item registration and low-level global hotkey event taps |
| **Delivery & Updates** | `Sparkle 2` | Ed25519-verified automated delta and binary app updates |

---

## 📋 System Requirements

- **macOS**: 14.0 (Sonoma) or newer (fully optimized for macOS 15 Sequoia)
- **Hardware**: Universal Binary supporting both **Apple Silicon** (M1/M2/M3/M4) and **Intel** architectures
- **Permissions**: Requires *Screen Recording* and optional *Microphone* / *Accessibility* permissions (guided by macOS system prompts)

---

## 🛠️ Building from Source

### Prerequisites
- Xcode 15.0+ or Command Line Tools for Xcode with Swift 6.0+

### Developer Control Center

Just Screenshot provides an interactive terminal dashboard and standard `Makefile` interface:

```bash
# Launch interactive developer menu
./manage.sh
# or
make menu
```

### Quick CLI Commands

```bash
# Build and run locally
make run
# (Compiles in release mode and launches "Just Screenshot.app")

# Build the standalone macOS App Bundle
make build

# Run Swift unit tests
make test

# Verify code signing certificates and Sparkle keys
make status

# Execute automated release pipeline (DMG, Sparkle Appcast, signing)
make release
```

---

## 📁 Repository Structure

```text
just-screenshot/
├── Sources/
│   └── JustScreenshotApp/
│       ├── Capture/          # ScreenCaptureKit frame acquisition & pixel samplers
│       ├── Core/             # Hotkey coordinator, OCR service, localization, settings
│       ├── Recording/        # MP4, GIF, WebP exporters, cursor tracking, camera follow
│       ├── UI/               # SwiftUI & AppKit presentation layers
│       │   ├── Editor/       # Annotation tools, canvas drawer, gradient presets
│       │   ├── History/      # Thumbnail gallery, search, and library management
│       │   ├── HUD/          # Floating quick-access action overlay
│       │   ├── Overlay/      # Crosshair selection, pixel loupe, countdown
│       │   ├── Pin/          # Floating always-on-top screenshot views
│       │   ├── Recording/    # Live recording frame, HUD, and video timeline trimmer
│       │   └── Settings/     # Translucent Liquid Glass preferences tabs
│       └── Resources/        # High-res AppIcon and graphical assets
├── Tests/                    # Unit test suite
├── scripts/                  # Build, packaging, certificate setup, and release scripts
├── manage.sh                 # Unified developer control center
├── Makefile                  # Make command shortcuts
└── Package.swift             # Swift Package Manager manifest
```

---

## 🔒 Privacy & Security

Just Screenshot was architected with a strict privacy guarantee:
- **Zero Network Activity**: The app makes zero external network requests, except when you explicitly check for software updates via Sparkle.
- **Zero Analytics**: No telemetry, crash reporters, or behavioral tracking libraries are bundled.
- **Local Storage**: Captures and history reside entirely in your local directories (`~/Movies` or user-defined folders).

---

## 🤝 Contributing

Contributions and ideas are warmly welcomed!
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is released under the [MIT License](LICENSE).
Feel free to use, modify, and distribute it in accordance with license terms.
