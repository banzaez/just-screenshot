#!/bin/bash
set -e

APP_NAME="Just Screenshot"
BUNDLE_DIR="$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Сборка релизного бинарника..."
swift build -c release

echo "📦 Создание macOS App Bundle ($BUNDLE_DIR)..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Копируем бинарник и иконку
cp .build/release/JustScreenshotApp "$MACOS_DIR/$APP_NAME"
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

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
    <string>1.0.4</string>
    <key>CFBundleVersion</key>
    <string>4</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Just Screenshot requires screen recording access to capture screenshots and record video of your screen.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Just Screenshot requires microphone access to record audio along with screen recording.</string>
</dict>
</plist>
EOF

echo "✍️ Подписание пакета постоянным сертификатом JustScreenshotDev..."
if security find-identity -p codesigning -v | grep -q "JustScreenshotDev"; then
    codesign --force --deep --sign "JustScreenshotDev" "$BUNDLE_DIR"
else
    echo "⚠️ Сертификат JustScreenshotDev не найден, используется ad-hoc подпись..."
    codesign --force --deep --sign - "$BUNDLE_DIR"
fi

echo "✅ $APP_NAME.app успешно собран и готов к запуску!"
