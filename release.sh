#!/bin/bash
set -e

# Цвета для красивого вывода
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NEW_VERSION="$1"
RELEASE_NOTES="$2"

if [ -z "$NEW_VERSION" ]; then
    echo -e "${RED}Ошибка:${NC} Укажите версию для релиза."
    echo -e "Использование: ${YELLOW}./release.sh <версия> [описание]${NC}"
    echo -e "Пример:        ${BLUE}./release.sh 1.0.3 \"Краткое описание изменений\"${NC}"
    exit 1
fi

TAG="v$NEW_VERSION"

# Проверка, нет ли уже такого тега
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo -e "${RED}Ошибка:${NC} Тег $TAG уже существует в git!"
    exit 1
fi

# Проверка рабочей директории (не считая build_app.sh)
if [ -n "$(git status --porcelain | grep -v 'build_app.sh')" ]; then
    echo -e "${YELLOW}Внимание:${NC} В рабочей директории есть незакоммиченные файлы:"
    git status --short
    read -p "Продолжить и включить их в релиз? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo "Отмена."
        exit 1
    fi
fi

echo -e "${BLUE}1. Обновление версии в build_app.sh...${NC}"

# Извлекаем текущий CFBundleVersion и увеличиваем на 1
CURRENT_BUILD=$(sed -n -e '/<key>CFBundleVersion<\/key>/{n;p;}' build_app.sh | sed -e 's/.*<string>\(.*\)<\/string>.*/\1/' | tr -d '[:space:]')
if [ -z "$CURRENT_BUILD" ]; then
    NEW_BUILD=1
else
    NEW_BUILD=$((CURRENT_BUILD + 1))
fi

# Обновляем CFBundleShortVersionString и CFBundleVersion
python3 -c "
import re

with open('build_app.sh', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(
    r'(<key>CFBundleShortVersionString</key>\s*<string>)[^<]+(</string>)',
    rf'\g<1>$NEW_VERSION\g<2>',
    content
)
content = re.sub(
    r'(<key>CFBundleVersion</key>\s*<string>)[^<]+(</string>)',
    rf'\g<1>$NEW_BUILD\g<2>',
    content
)

with open('build_app.sh', 'w', encoding='utf-8') as f:
    f.write(content)
"

echo -e "  Версия: ${GREEN}$NEW_VERSION${NC} (Build: ${GREEN}$NEW_BUILD${NC})"

echo -e "${BLUE}2. Сборка приложения (build_app.sh)...${NC}"
./build_app.sh

APP_BUNDLE="Just Screenshot.app"
ZIP_NAME="JustScreenshot-$TAG.zip"

echo -e "${BLUE}3. Упаковка в zip ($ZIP_NAME)...${NC}"
rm -f "$ZIP_NAME"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

echo -e "${BLUE}4. Фиксация изменений в git...${NC}"
git add build_app.sh
if [ -n "$(git status --porcelain)" ]; then
    git commit -m "chore: bump version to $NEW_VERSION"
fi

echo -e "${BLUE}5. Создание тега $TAG...${NC}"
git tag -a "$TAG" -m "Release $TAG"

echo -e "${BLUE}6. Отправка ветки и тегов в git remote...${NC}"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push origin "$CURRENT_BRANCH" --tags

echo -e "${BLUE}7. Публикация GitHub Release...${NC}"
if command -v gh >/dev/null 2>&1; then
    if [ -n "$RELEASE_NOTES" ]; then
        gh release create "$TAG" "$ZIP_NAME" --title "Just Screenshot $TAG" --notes "$RELEASE_NOTES"
    else
        gh release create "$TAG" "$ZIP_NAME" --title "Just Screenshot $TAG" --generate-notes
    fi
    echo -e "${GREEN}GitHub Release успешно создан с прикрепленным архивом!${NC}"
else
    echo -e "${YELLOW}Утилита gh (GitHub CLI) не найдена. Тег отправлен в git, но релиз на GitHub не создан.${NC}"
fi

# Очистка временного zip файла
rm -f "$ZIP_NAME"

echo -e "\n${GREEN}🚀 Релиз $TAG успешно опубликован!${NC}"
