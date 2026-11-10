#!/usr/bin/env bash
set -e

# ==============================================================================
# Создание и сохранение локального сертификата разработки JustScreenshotDev
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CERT_NAME="JustScreenshotDev"
CERT_PASS="justscreenshot"
LOCAL_DIR="$PROJECT_ROOT/certificates"
USER_BACKUP_DIR="$HOME/.justscreenshot/certs"
KEYCHAIN_PATH="$(security default-keychain | tr -d ' "\n')"
if [ -z "$KEYCHAIN_PATH" ] || [ ! -f "$KEYCHAIN_PATH" ]; then
    KEYCHAIN_PATH="$HOME/Library/Keychains/login.keychain-db"
fi

mkdir -p "$LOCAL_DIR"
mkdir -p "$USER_BACKUP_DIR"

P12_FILE="$LOCAL_DIR/$CERT_NAME.p12"
USER_P12_FILE="$USER_BACKUP_DIR/$CERT_NAME.p12"
CRT_FILE="$LOCAL_DIR/$CERT_NAME.crt"
KEY_FILE="$LOCAL_DIR/$CERT_NAME.key"

echo "🔐 Настройка локального сертификата разработчика: $CERT_NAME"

# 1. Если файл .p12 уже сохранен в бэкапе или в проекте — используем его
if [ ! -f "$P12_FILE" ] && [ -f "$USER_P12_FILE" ]; then
    echo "📦 Найден сохраненный сертификат в $USER_BACKUP_DIR, восстанавливаем..."
    cp "$USER_P12_FILE" "$P12_FILE"
fi

if [ ! -f "$P12_FILE" ]; then
    echo "⚙️ Генерация нового сертификата (срок действия: 10 лет)..."
    openssl req -x509 -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CRT_FILE" \
        -days 3650 -nodes \
        -subj "/CN=$CERT_NAME/O=Just Screenshot Local Dev" \
        -addext "keyUsage = critical, digitalSignature" \
        -addext "extendedKeyUsage = critical, codeSigning" \
        -addext "basicConstraints = critical, CA:FALSE" 2>/dev/null

    echo "📦 Экспорт в PKCS#12 ($CERT_NAME.p12)..."
    LEGACY_FLAG=""
    if openssl pkcs12 -help 2>&1 | grep -q -- "-legacy"; then
        LEGACY_FLAG="-legacy"
    fi
    openssl pkcs12 -export $LEGACY_FLAG \
        -inkey "$KEY_FILE" \
        -in "$CRT_FILE" \
        -out "$P12_FILE" \
        -passout "pass:$CERT_PASS" 2>/dev/null

    # Копируем в бэкап домашней папки
    cp "$P12_FILE" "$USER_P12_FILE"
    if [ -f "$CRT_FILE" ]; then cp "$CRT_FILE" "$USER_BACKUP_DIR/"; fi
    if [ -f "$KEY_FILE" ]; then cp "$KEY_FILE" "$USER_BACKUP_DIR/"; fi
    
    # Создаем текстовую памятку в папке сертификатов
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
EXISTING_ID=$(security find-identity -p codesigning -v 2>/dev/null | grep "$CERT_NAME" || true)

if [ -z "$EXISTING_ID" ]; then
    echo "📥 Импорт сертификата в Связку ключей ($KEYCHAIN_PATH)..."
    security import "$P12_FILE" \
        -k "$KEYCHAIN_PATH" \
        -P "$CERT_PASS" \
        -T /usr/bin/codesign

    if [ -f "$CRT_FILE" ]; then
        echo "🛡 Настройка доверия для подписи кода..."
        security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN_PATH" "$CRT_FILE" 2>/dev/null || true
    fi
else
    echo "ℹ️ Сертификат '$CERT_NAME' уже активен в Связке ключей."
fi

# 3. Проверка
echo -e "\n📋 Доступные сертификаты для подписи:"
security find-identity -p codesigning -v | grep -E "JustScreenshotDev" || true

echo -e "\n✅ Сертификат '$CERT_NAME' готов к использованию!"
echo "📁 Ваши файлы сертификата надежно сохранены в:"
echo "   • $P12_FILE"
echo "   • $USER_P12_FILE"
echo "   (Пароль к архиву .p12: $CERT_PASS)"
