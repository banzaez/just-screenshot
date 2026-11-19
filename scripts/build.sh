#!/usr/bin/env bash
set -euo pipefail

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
    # shellcheck disable=SC1091
    source "VERSION"
fi
APP_VERSION="${VERSION:-1.4.4}"
APP_BUILD="${BUILD:-1}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"

RUN_AFTER_BUILD=false
for arg in "$@"; do
    case "$arg" in
        --run|-r) RUN_AFTER_BUILD=true ;;
        *)
            echo "❌ Неизвестный аргумент: $arg" >&2
            exit 1
            ;;
    esac
done

echo "🔨 Сборка релизного бинарника v$APP_VERSION ($APP_BUILD)..."
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/JustScreenshotApp"
if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "❌ Релизный бинарник не найден: $EXECUTABLE_PATH" >&2
    exit 1
fi

echo "📦 Создание macOS App Bundle ($BUNDLE_DIR)..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

# Копируем бинарник и иконку
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
APP_ICON="Sources/JustScreenshotApp/Resources/AppIcon.icns"
if [ -f "$APP_ICON" ]; then
    cp "$APP_ICON" "$RESOURCES_DIR/AppIcon.icns"
fi

# Копируем все SPM resource bundles (если сгенерированы)
while IFS= read -r resource_bundle; do
    cp -R "$resource_bundle" "$RESOURCES_DIR/"
done < <(find "$BIN_DIR" -maxdepth 1 -name "*.bundle" -type d)

# Копируем Sparkle.framework (обязательная зависимость автообновлений)
SPARKLE_FRAMEWORK=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ ! -d "$SPARKLE_FRAMEWORK" ]; then
    echo "❌ Ошибка: Sparkle.framework не найден по пути $SPARKLE_FRAMEWORK" >&2
    exit 1
fi
cp -R "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/"

# Настраиваем rpath для поиска Frameworks (без ошибки, если rpath уже прописан)
if ! otool -l "$MACOS_DIR/$APP_NAME" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME"
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
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_BUILD</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Just Screenshot requires screen recording access to capture screenshots and record video of your screen.</string>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/banzaez/just-screenshot/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>RFPVJFpi1khZw92PWqsHMNzPWzpG3xyggJd7ygFN2gk=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
EOF

sign_item() {
    local identity="$1"
    local target="$2"
    codesign --force --sign "$identity" "$target"
}

echo "✍️ Подписание фреймворков и пакета (inside-out)..."
if [ -n "$CODESIGN_IDENTITY" ]; then
    SIGN_IDENTITY="$CODESIGN_IDENTITY"
else
    SIGN_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null | grep -E "JustScreenshotDev" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
fi

if [ -n "$SIGN_IDENTITY" ]; then
    echo "🔐 Подписание стабильным сертификатом: $SIGN_IDENTITY"
    ACTIVE_IDENTITY="$SIGN_IDENTITY"
else
    echo "ℹ️ Локальный сертификат JustScreenshotDev не найден, используется ad-hoc подпись..."
    ACTIVE_IDENTITY="-"
fi

# Подписываем вложенные компоненты Sparkle изнутри наружу
SPARKLE_DEST="$FRAMEWORKS_DIR/Sparkle.framework"
if [ -d "$SPARKLE_DEST" ]; then
    while IFS= read -r xpc; do
        sign_item "$ACTIVE_IDENTITY" "$xpc"
    done < <(find "$SPARKLE_DEST" -name "*.xpc" -type d)

    if [ -e "$SPARKLE_DEST/Versions/B/Updater.app" ]; then
        sign_item "$ACTIVE_IDENTITY" "$SPARKLE_DEST/Versions/B/Updater.app"
    elif [ -e "$SPARKLE_DEST/Updater.app" ]; then
        sign_item "$ACTIVE_IDENTITY" "$SPARKLE_DEST/Updater.app"
    fi

    if [ -e "$SPARKLE_DEST/Versions/B/Autoupdate" ]; then
        sign_item "$ACTIVE_IDENTITY" "$SPARKLE_DEST/Versions/B/Autoupdate"
    elif [ -e "$SPARKLE_DEST/Autoupdate" ]; then
        sign_item "$ACTIVE_IDENTITY" "$SPARKLE_DEST/Autoupdate"
    fi

    sign_item "$ACTIVE_IDENTITY" "$SPARKLE_DEST"
fi

while IFS= read -r resource_bundle; do
    sign_item "$ACTIVE_IDENTITY" "$resource_bundle"
done < <(find "$RESOURCES_DIR" -maxdepth 1 -name "*.bundle" -type d)

sign_item "$ACTIVE_IDENTITY" "$BUNDLE_DIR"

echo "✅ $APP_NAME.app v$APP_VERSION (Build $APP_BUILD) успешно собран!"

if [ "$RUN_AFTER_BUILD" = true ]; then
    echo "🚀 Запуск $APP_NAME.app..."
    pkill -f "$BUNDLE_DIR/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    sleep 0.5
    open "$BUNDLE_DIR"
fi
