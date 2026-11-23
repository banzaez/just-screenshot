#!/usr/bin/env bash
set -euo pipefail

# Определение корня проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="Just Screenshot"
BUNDLE_DIR="$PROJECT_ROOT/$APP_NAME.app"
APP_ICON="$PROJECT_ROOT/Sources/JustScreenshotApp/Resources/AppIcon.icns"
BG_IMAGE="$SCRIPT_DIR/dmg/background.tiff"

if [ -f "VERSION" ]; then
    # shellcheck disable=SC1091
    source "VERSION"
fi
APP_VERSION="${VERSION:-1.4.4}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"

SKIP_BUILD=false
OUTPUT_DMG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --version)
            APP_VERSION="${2:-}"
            if [ -z "$APP_VERSION" ]; then
                echo "❌ Ошибка: укажите значение после --version" >&2
                exit 1
            fi
            shift 2
            ;;
        --output|-o)
            OUTPUT_DMG="${2:-}"
            if [ -z "$OUTPUT_DMG" ]; then
                echo "❌ Ошибка: укажите путь после --output" >&2
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            echo "Использование: $0 [--skip-build] [--version X.Y.Z] [--output path.dmg]"
            exit 0
            ;;
        *)
            echo "❌ Неизвестный аргумент: $1" >&2
            exit 1
            ;;
    esac
done

APP_VERSION="${APP_VERSION#v}"
if [ -z "$OUTPUT_DMG" ]; then
    OUTPUT_DMG="$PROJECT_ROOT/JustScreenshot-v$APP_VERSION.dmg"
fi

if [ "$SKIP_BUILD" = false ] || [ ! -d "$BUNDLE_DIR" ]; then
    echo "🔨 Сборка $APP_NAME.app перед упаковкой в DMG..."
    "$SCRIPT_DIR/build.sh"
fi

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "❌ Ошибка: $BUNDLE_DIR не найден." >&2
    exit 1
fi

STAGING_DIR="$(mktemp -d)"
RW_DMG="$(mktemp -u /tmp/justscreenshot_rw.XXXXXX).dmg"
MOUNT_DIR=""

cleanup() {
    if [ -n "$MOUNT_DIR" ] && [ -d "$MOUNT_DIR" ]; then
        hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR" -force -quiet || true
    fi
    rm -rf "$STAGING_DIR" "$RW_DMG"
}
trap cleanup EXIT

echo "💿 Подготовка содержимого DMG ($OUTPUT_DMG)..."
ditto "$BUNDLE_DIR" "$STAGING_DIR/$APP_NAME.app"
rm -f "$OUTPUT_DMG"

if command -v create-dmg >/dev/null 2>&1; then
    echo "🎨 Создание оформленного DMG с помощью create-dmg..."
    CREATE_DMG_ARGS=(
        --volname "$APP_NAME"
        --window-pos 200 120
        --window-size 600 400
        --icon-size 104
        --text-size 13
        --icon "$APP_NAME.app" 165 184
        --hide-extension "$APP_NAME.app"
        --app-drop-link 435 184
        --no-internet-enable
    )
    if [ -f "$APP_ICON" ]; then
        CREATE_DMG_ARGS+=(--volicon "$APP_ICON")
    fi
    if [ -f "$BG_IMAGE" ]; then
        CREATE_DMG_ARGS+=(--background "$BG_IMAGE")
    fi
    create-dmg "${CREATE_DMG_ARGS[@]}" "$OUTPUT_DMG" "$STAGING_DIR"
else
    echo "🎨 Создание оформленного DMG с помощью hdiutil и Finder..."
    ln -s /Applications "$STAGING_DIR/Applications"

    if [ -f "$BG_IMAGE" ]; then
        mkdir -p "$STAGING_DIR/.background"
        cp "$BG_IMAGE" "$STAGING_DIR/.background/background.tiff"
    fi

    if [ -f "$APP_ICON" ]; then
        cp "$APP_ICON" "$STAGING_DIR/.VolumeIcon.icns"
    fi

    # Создаём временный read-write образ для записи .DS_Store (раскладка окна Finder)
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDRW \
        -fs HFS+ \
        "$RW_DMG" >/dev/null

    ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
    MOUNT_DIR="$(echo "$ATTACH_OUTPUT" | grep -E '/Volumes/' | head -n 1 | sed -E 's/.*(\/Volumes\/.*)/\1/')"

    if [ -n "$MOUNT_DIR" ] && [ -d "$MOUNT_DIR" ]; then
        if [ -f "$MOUNT_DIR/.VolumeIcon.icns" ] && command -v SetFile >/dev/null 2>&1; then
            SetFile -a C "$MOUNT_DIR" || true
        fi

        VOL_NAME="$(basename "$MOUNT_DIR")"
        if ! osascript <<EOF
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        try
            set pathbar visible of container window to false
        end try
        try
            set sidebar width of container window to 0
        end try
        set the bounds of container window to {200, 120, 800, 548}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 104
        set text size of viewOptions to 13
        if exists file ".background:background.tiff" then
            set background picture of viewOptions to file ".background:background.tiff"
        end if
        set position of item "$APP_NAME.app" of container window to {165, 184}
        set position of item "Applications" of container window to {435, 184}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
        then
            echo "⚠️  Не удалось применить оформление Finder через AppleScript (будет использована стандартная раскладка)."
        fi

        sync
        hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR" -force -quiet
        MOUNT_DIR=""
    fi

    hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$OUTPUT_DMG" >/dev/null
fi

# Подпись DMG, если задан сертификат или найден локальный JustScreenshotDev
if [ -n "$CODESIGN_IDENTITY" ]; then
    SIGN_IDENTITY="$CODESIGN_IDENTITY"
else
    SIGN_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null | grep -E "JustScreenshotDev" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
fi

if [ -n "$SIGN_IDENTITY" ]; then
    echo "🔐 Подписание DMG сертификатом: $SIGN_IDENTITY"
    codesign --force --sign "$SIGN_IDENTITY" "$OUTPUT_DMG"
fi

DMG_SIZE="$(du -h "$OUTPUT_DMG" | awk '{print $1}')"
echo "✅ DMG-установщик создан: $OUTPUT_DMG ($DMG_SIZE)"
