#!/usr/bin/env bash
set -e

# Определение корня проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Цвета для терминала
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

if [ -f "VERSION" ]; then
    source "VERSION"
fi
CURRENT_VERSION="${VERSION:-1.1.1}"
CURRENT_BUILD="${BUILD:-1}"

INPUT_VERSION="$1"
RELEASE_NOTES="$2"

# Функция для вычисления следующей версии
bump_version() {
    local ver="$1"
    local type="$2"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$ver"
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}

    case "$type" in
        patch) patch=$((patch + 1)) ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        major) major=$((major + 1)); minor=0; patch=0 ;;
        *) echo "$type"; return ;;
    esac
    echo "${major}.${minor}.${patch}"
}

if [ -z "$INPUT_VERSION" ]; then
    echo -e "${RED}Ошибка:${NC} Укажите тип релиза (patch, minor, major) или номер версии (например, 1.2.0)."
    echo -e "Использование: ${YELLOW}./scripts/release.sh <patch|minor|major|версия> [описание]${NC}"
    exit 1
fi

case "$INPUT_VERSION" in
    patch|minor|major)
        NEW_VERSION=$(bump_version "$CURRENT_VERSION" "$INPUT_VERSION")
        ;;
    *)
        NEW_VERSION="$INPUT_VERSION"
        ;;
esac

NEW_BUILD=$((CURRENT_BUILD + 1))
TAG="v$NEW_VERSION"

echo -e "\n${BOLD}${CYAN}🚀 Подготовка релиза Just Screenshot${NC}"
echo -e "  Текущая версия: ${YELLOW}$CURRENT_VERSION${NC} (Build $CURRENT_BUILD)"
echo -e "  Новая версия:   ${GREEN}$NEW_VERSION${NC} (Build ${GREEN}$NEW_BUILD${NC})"
echo -e "  Тег в git:      ${GREEN}$TAG${NC}\n"

# Проверка, нет ли уже такого тега
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo -e "${RED}Ошибка:${NC} Тег $TAG уже существует в git!"
    exit 1
fi

# Проверка незакоммиченных изменений
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}Внимание:${NC} В рабочей директории есть незакоммиченные файлы:"
    git status --short
    read -p "Включить их в коммит релиза? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo "Релиз отменен."
        exit 1
    fi
fi

# 1. Обновление VERSION файла
echo -e "${BLUE}1. Обновление VERSION...${NC}"
cat <<EOF > "VERSION"
VERSION=$NEW_VERSION
BUILD=$NEW_BUILD
EOF
echo -e "  Записано в VERSION: ${GREEN}$NEW_VERSION (Build $NEW_BUILD)${NC}"

# 2. Сборка приложения
echo -e "${BLUE}2. Сборка приложения (.app)...${NC}"
./scripts/build.sh

APP_BUNDLE="Just Screenshot.app"
ZIP_NAME="JustScreenshot-$TAG.zip"

# 3. Упаковка в zip
echo -e "${BLUE}3. Упаковка в zip ($ZIP_NAME)...${NC}"
rm -f "$ZIP_NAME"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

# 4. Обновление и подпись appcast.xml (Sparkle)
echo -e "${BLUE}4. Генерация и Ed25519-подпись appcast.xml...${NC}"
GENERATE_APPCAST=".build/artifacts/sparkle/Sparkle/bin/generate_appcast"
if [ -f "$GENERATE_APPCAST" ]; then
    "$GENERATE_APPCAST" --download-url-prefix "https://github.com/banzaez/just-screenshot/releases/download/$TAG/" .
    echo -e "  ${GREEN}appcast.xml успешно подписан ключом Ed25519!${NC}"
else
    echo -e "  ${YELLOW}generate_appcast не найден, appcast.xml не обновлен.${NC}"
fi

# 5. Фиксация в git
echo -e "${BLUE}5. Фиксация изменений в git...${NC}"
git add -A
if [ -n "$(git status --porcelain)" ]; then
    git commit -m "chore(release): bump version to $TAG ($NEW_BUILD) and update appcast"
fi

# 6. Создание тега
echo -e "${BLUE}6. Создание тега $TAG...${NC}"
git tag -a "$TAG" -m "Release $TAG"

# 7. Отправка в remote
echo -e "${BLUE}7. Отправка ветки и тегов в git remote...${NC}"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push origin "$CURRENT_BRANCH" --tags

# 8. GitHub Release
echo -e "${BLUE}8. Публикация GitHub Release...${NC}"
if command -v gh >/dev/null 2>&1; then
    if [ -n "$RELEASE_NOTES" ]; then
        gh release create "$TAG" "$ZIP_NAME" appcast.xml --title "Just Screenshot $TAG" --notes "$RELEASE_NOTES"
    else
        gh release create "$TAG" "$ZIP_NAME" appcast.xml --title "Just Screenshot $TAG" --generate-notes
    fi
    echo -e "  ${GREEN}GitHub Release $TAG успешно опубликован!${NC}"
else
    echo -e "  ${YELLOW}gh CLI не найден. Тег отправлен в git, релиз на GitHub создайте вручную.${NC}"
fi

# Очистка архива
rm -f "$ZIP_NAME"

echo -e "\n${GREEN}${BOLD}🎉 Релиз $TAG успешно завершен!${NC}"
