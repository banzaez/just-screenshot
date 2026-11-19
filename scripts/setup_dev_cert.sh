#!/usr/bin/env bash
set -euo pipefail
umask 077

# ==============================================================================
# Создание и сохранение локального сертификата разработки JustScreenshotDev
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CERT_NAME="JustScreenshotDev"
CERT_PASS="${CERT_PASS:-justscreenshot}"
LOCAL_DIR="$PROJECT_ROOT/certificates"
USER_BACKUP_DIR="$HOME/.justscreenshot/certs"

RAW_KEYCHAIN="$(security default-keychain | head -n 1 || true)"
KEYCHAIN_PATH="$(printf '%s' "$RAW_KEYCHAIN" | sed -E 's/^[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
if [ -z "$KEYCHAIN_PATH" ] || [ ! -f "$KEYCHAIN_PATH" ]; then
    KEYCHAIN_PATH="$HOME/Library/Keychains/login.keychain-db"
fi

mkdir -p "$LOCAL_DIR" "$USER_BACKUP_DIR"
chmod 700 "$LOCAL_DIR" "$USER_BACKUP_DIR"

P12_FILE="$LOCAL_DIR/$CERT_NAME.p12"
USER_P12_FILE="$USER_BACKUP_DIR/$CERT_NAME.p12"
CRT_FILE="$LOCAL_DIR/$CERT_NAME.crt"
USER_CRT_FILE="$USER_BACKUP_DIR/$CERT_NAME.crt"
KEY_FILE="$LOCAL_DIR/$CERT_NAME.key"
USER_KEY_FILE="$USER_BACKUP_DIR/$CERT_NAME.key"

TMP_CERT_DIR="$(mktemp -d)"
chmod 700 "$TMP_CERT_DIR"
cleanup() {
    rm -rf "$TMP_CERT_DIR"
}
trap cleanup EXIT

echo "🔐 Настройка локального сертификата разработчика: $CERT_NAME"

# 1. Восстановление существующего сертификата из резервной копии при отсутствии локальной копии
if [ ! -f "$P12_FILE" ] && [ -f "$USER_P12_FILE" ]; then
    echo "📦 Найден сохраненный .p12 в $USER_BACKUP_DIR, восстанавливаем..."
    cp "$USER_P12_FILE" "$P12_FILE"
    chmod 600 "$P12_FILE"
fi
if [ ! -f "$CRT_FILE" ] && [ -f "$USER_CRT_FILE" ]; then
    cp "$USER_CRT_FILE" "$CRT_FILE"
    chmod 600 "$CRT_FILE"
fi
if [ ! -f "$KEY_FILE" ] && [ -f "$USER_KEY_FILE" ]; then
    cp "$USER_KEY_FILE" "$KEY_FILE"
    chmod 600 "$KEY_FILE"
fi

if [ ! -f "$P12_FILE" ]; then
    echo "⚙️ Генерация нового сертификата (срок действия: 10 лет)..."
    TMP_KEY="$TMP_CERT_DIR/$CERT_NAME.key"
    TMP_CRT="$TMP_CERT_DIR/$CERT_NAME.crt"
    TMP_P12="$TMP_CERT_DIR/$CERT_NAME.p12"

    openssl req -x509 -newkey rsa:2048 \
        -keyout "$TMP_KEY" \
        -out "$TMP_CRT" \
        -days 3650 -nodes \
        -subj "/CN=$CERT_NAME/O=Just Screenshot Local Dev" \
        -addext "keyUsage = critical, digitalSignature" \
        -addext "extendedKeyUsage = critical, codeSigning" \
        -addext "basicConstraints = critical, CA:FALSE"

    echo "📦 Экспорт в PKCS#12 ($CERT_NAME.p12)..."
    LEGACY_FLAG=()
    if openssl pkcs12 -help 2>&1 | grep -q -- "-legacy"; then
        LEGACY_FLAG=(-legacy)
    fi
    openssl pkcs12 -export "${LEGACY_FLAG[@]}" \
        -inkey "$TMP_KEY" \
        -in "$TMP_CRT" \
        -out "$TMP_P12" \
        -passout "pass:$CERT_PASS"

    cp "$TMP_P12" "$P12_FILE"
    cp "$TMP_P12" "$USER_P12_FILE"
    cp "$TMP_CRT" "$CRT_FILE"
    cp "$TMP_CRT" "$USER_CRT_FILE"
    cp "$TMP_KEY" "$KEY_FILE"
    cp "$TMP_KEY" "$USER_KEY_FILE"
    chmod 600 "$P12_FILE" "$USER_P12_FILE" "$CRT_FILE" "$USER_CRT_FILE" "$KEY_FILE" "$USER_KEY_FILE"

    cat <<EOF > "$LOCAL_DIR/README.txt"
Сертификат локальной разработки Just Screenshot
==============================================
Имя: $CERT_NAME
Пароль к архиву .p12: $CERT_PASS
Срок действия: 10 лет

Файлы сохранены в двух местах:
1. $LOCAL_DIR/ (внутри проекта, исключено из git через .gitignore)
2. $USER_BACKUP_DIR/ (в вашей домашней директории для надежности)

Как восстановить сертификат на новом Маке или после переустановки macOS:
Достаточно запустить:
    ./scripts/setup_dev_cert.sh

Этот сертификат гарантирует, что выданные в macOS системные разрешения
(Screen Recording, Accessibility) сохраняются при каждой пересборке.
EOF
    cp "$LOCAL_DIR/README.txt" "$USER_BACKUP_DIR/README.txt"
fi

# 2. Проверяем наличие в Связке ключей
EXISTING_ID="$(security find-identity -p codesigning -v 2>/dev/null | grep "$CERT_NAME" || true)"

if [ -z "$EXISTING_ID" ]; then
    echo "📥 Импорт сертификата в Связку ключей ($KEYCHAIN_PATH)..."
    security import "$P12_FILE" \
        -k "$KEYCHAIN_PATH" \
        -P "$CERT_PASS" \
        -T /usr/bin/codesign

    if [ -f "$CRT_FILE" ]; then
        echo "🛡 Настройка доверия для подписи кода..."
        security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN_PATH" "$CRT_FILE"
    fi
else
    echo "ℹ️ Сертификат '$CERT_NAME' уже активен в Связке ключей."
fi

# 3. Проверка
echo -e "\n📋 Доступные сертификаты для подписи:"
security find-identity -p codesigning -v | grep -E "JustScreenshotDev" || {
    echo "❌ Ошибка: сертификат '$CERT_NAME' не обнаружен в списке identities для подписи кода." >&2
    exit 1
}

echo -e "\n✅ Сертификат '$CERT_NAME' готов к использованию!"
echo "📁 Ваши файлы сертификата надежно сохранены в:"
echo "   • $P12_FILE"
echo "   • $USER_P12_FILE"
