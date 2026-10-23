#!/usr/bin/env bash
set -e

# Определение корня проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="Just Screenshot"
BUNDLE_DIR="$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

# Чтение версии из единого источника истины (VERSION)
if [ -f "VERSION" ]; then
    source "VERSION"
fi
APP_VERSION="${VERSION:-1.1.1}"
APP_BUILD="${BUILD:-1}"

RUN_AFTER_BUILD=false
for arg in "$@"; do
    case "$arg" in
        --run|-r) RUN_AFTER_BUILD=true ;;
    esac
done

echo "🔨 Сборка релизного бинарника v$APP_VERSION ($APP_BUILD)..."
swift build -c release

echo "📦 Создание macOS App Bundle ($BUNDLE_DIR)..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$FRAMEWORKS_DIR"

# Копируем бинарник и иконку
cp .build/release/JustScreenshotApp "$MACOS_DIR/$APP_NAME"
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

# Копируем Sparkle.framework
SPARKLE_FRAMEWORK=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    cp -R "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/"
fi

# Настраиваем rpath для поиска Frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME" 2>/dev/null || true

# Генерируем Info.plist внутри Bundle
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.justscreenshot.app</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_BUILD</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Just Screenshot requires screen recording access to capture screenshots and record video of your screen.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Just Screenshot requires microphone access to record audio along with screen recording.</string>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/banzaez/just-screenshot/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>mEYp2Cii00e97mSUiez/AWgmCK76WTVzfYJ83B5FR5k=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
EOF

echo "✍️ Подписание фреймворков и пакета..."
if security find-identity -p codesigning -v | grep -q "JustScreenshotDev"; then
    if [ -d "$FRAMEWORKS_DIR/Sparkle.framework" ]; then
        codesign --force --sign "JustScreenshotDev" "$FRAMEWORKS_DIR/Sparkle.framework"
    fi
    codesign --force --deep --sign "JustScreenshotDev" "$BUNDLE_DIR"
else
    echo "⚠️ Сертификат JustScreenshotDev не найден, используется ad-hoc подпись..."
    if [ -d "$FRAMEWORKS_DIR/Sparkle.framework" ]; then
        codesign --force --sign - "$FRAMEWORKS_DIR/Sparkle.framework"
    fi
    codesign --force --deep --sign - "$BUNDLE_DIR"
fi

echo "✅ $APP_NAME.app v$APP_VERSION (Build $APP_BUILD) успешно собран!"

if [ "$RUN_AFTER_BUILD" = true ]; then
    echo "🚀 Запуск $APP_NAME.app..."
    # Завершаем предыдущий запущенный экземпляр, если есть
    pkill -f "$BUNDLE_DIR/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    sleep 0.5
    open "$BUNDLE_DIR"
fi
