#!/usr/bin/env bash
set -e

# Определение корня проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Цветовая палитра для профессионального терминала
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

get_version_info() {
    if [ -f "VERSION" ]; then
        source "VERSION"
    fi
    CURRENT_VERSION="${VERSION:-1.1.1}"
    CURRENT_BUILD="${BUILD:-1}"
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    DIRTY_FILES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
}

show_header() {
    get_version_info
    echo -e "${CYAN}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}🚀 Just Screenshot — Developer Control Center${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${DIM}Архитектура macOS 2026 • Swift 6 • Sparkle 2${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC}  Версия:   ${GREEN}v$CURRENT_VERSION${NC} ${DIM}(Build $CURRENT_BUILD)${NC}                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  Ветка:    ${BLUE}$CURRENT_BRANCH${NC}                                        ${CYAN}│${NC}"
    if [ "$DIRTY_FILES" -eq "0" ]; then
        echo -e "${CYAN}│${NC}  Git:      ${GREEN}чистый (нет изменений)${NC}                            ${CYAN}│${NC}"
    else
        echo -e "${CYAN}│${NC}  Git:      ${YELLOW}изменено файлов: $DIRTY_FILES${NC}                                 ${CYAN}│${NC}"
    fi
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────╯${NC}"
}

cmd_build() {
    ./scripts/build.sh "$@"
}

cmd_run() {
    ./scripts/build.sh --run
}

cmd_test() {
    echo -e "\n${BLUE}🧪 Запуск unit-тестов Swift...${NC}"
    swift test
}

cmd_clean() {
    echo -e "\n${YELLOW}🧹 Очистка артефактов сборки...${NC}"
    rm -rf "Just Screenshot.app"
    rm -f *.zip
    swift package clean
    echo -e "${GREEN}✅ Проект очищен!${NC}"
}

cmd_status() {
    show_header
    echo -e "\n${BOLD}🔍 Проверка компонентов окружения:${NC}"
    
    # 1. Swift
    SWIFT_V=$(swift --version | head -n 1)
    echo -e "  • Swift:     ${GREEN}$SWIFT_V${NC}"
    
    # 2. GitHub CLI (gh)
    if command -v gh >/dev/null 2>&1; then
        GH_V=$(gh --version | head -n 1)
        echo -e "  • GitHub CLI:${GREEN} Установлен ($GH_V)${NC}"
    else
        echo -e "  • GitHub CLI:${YELLOW} Не найден (рекомендуется: brew install gh)${NC}"
    fi
    
    # 3. Сертификаты подписи
    if security find-identity -p codesigning -v | grep -q "JustScreenshotDev"; then
        echo -e "  • Codesign:  ${GREEN}Найден сертификат JustScreenshotDev${NC}"
    else
        echo -e "  • Codesign:  ${YELLOW}Ad-hoc подпись (сертификат JustScreenshotDev не создан)${NC}"
    fi
    
    # 4. Sparkle ключ Ed25519
    if [ -f "appcast.xml" ]; then
        echo -e "  • Sparkle:   ${GREEN}appcast.xml готов (Ed25519 настроен в Keychain)${NC}"
    fi
    echo ""
}

release_wizard() {
    get_version_info
    echo -e "\n${BOLD}${PURPLE}📦 Мастер публикации релиза${NC}"
    echo -e "Текущая версия: ${GREEN}v$CURRENT_VERSION${NC} (Build $CURRENT_BUILD)"
    
    # Расчёт следующих версий
    IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
    NEXT_PATCH="${major}.${minor}.$((patch + 1))"
    NEXT_MINOR="${major}.$((minor + 1)).0"
    NEXT_MAJOR="$((major + 1)).0.0"
    
    echo -e "\nВыберите тип релиза:"
    echo -e "  ${BOLD}1)${NC} 🩹 Patch  ${GREEN}$NEXT_PATCH${NC} ${DIM}(исправления ошибок и мелкие фиксы)${NC}"
    echo -e "  ${BOLD}2)${NC} 🌟 Minor  ${GREEN}$NEXT_MINOR${NC} ${DIM}(новые функции с сохранением совместимости)${NC}"
    echo -e "  ${BOLD}3)${NC} 💥 Major  ${GREEN}$NEXT_MAJOR${NC} ${DIM}(крупный релиз / смена архитектуры)${NC}"
    echo -e "  ${BOLD}4)${NC} ✍️  Ввести номер версии вручную"
    echo -e "  ${BOLD}0)${NC} ❌ Отмена"
    
    read -p "Ваш выбор [1-4]: " r_choice
    TARGET_VER=""
    case "$r_choice" in
        1) TARGET_VER="$NEXT_PATCH" ;;
        2) TARGET_VER="$NEXT_MINOR" ;;
        3) TARGET_VER="$NEXT_MAJOR" ;;
        4)
            read -p "Введите версию (например 1.2.3): " TARGET_VER
            if [ -z "$TARGET_VER" ]; then
                echo "Отмена."
                return
            fi
            ;;
        0|*)
            echo "Отмена."
            return
            ;;
    esac
    
    echo -e "\nОписание релиза (Release Notes):"
    echo -e "${DIM}(Оставьте пустым для автоматической генерации из git-коммитов через gh)${NC}"
    read -p "Описание: " r_notes
    
    echo -e "\n${YELLOW}Внимание! Будут выполнены шаги:${NC}"
    echo -e "  1. Обновление версии до ${GREEN}v$TARGET_VER (Build $((CURRENT_BUILD + 1)))${NC}"
    echo -e "  2. Сборка и подпись Just Screenshot.app"
    echo -e "  3. Создание архива и подпись Sparkle appcast.xml"
    echo -e "  4. Коммит, git push и создание тега v$TARGET_VER"
    echo -e "  5. Публикация GitHub Release с прикрепленным .zip и appcast"
    
    read -p "Запустить процесс публикации? (y/N): " confirm_rel
    if [[ "$confirm_rel" =~ ^[yY]$ ]]; then
        ./scripts/release.sh "$TARGET_VER" "$r_notes"
    else
        echo "Публикация отменена."
    fi
}

interactive_menu() {
    while true; do
        clear
        show_header
        echo -e "${BOLD}Выберите действие:${NC}"
        echo -e "  ${BOLD}1)${NC} 🔨 Собрать .app ${DIM}(Release build)${NC}"
        echo -e "  ${BOLD}2)${NC} 🚀 Собрать и Запустить ${DIM}(Build & Run)${NC}"
        echo -e "  ${BOLD}3)${NC} 📦 Опубликовать Релиз ${DIM}(Sparkle + GitHub Release Wizard)${NC}"
        echo -e "  ${BOLD}4)${NC} 🧪 Запустить тесты ${DIM}(swift test)${NC}"
        echo -e "  ${BOLD}5)${NC} 🧹 Очистить проект ${DIM}(Clean cache)${NC}"
        echo -e "  ${BOLD}6)${NC} 🔍 Статус и окружение ${DIM}(Diagnostics)${NC}"
        echo -e "  ${BOLD}0)${NC} 🚪 Выход"
        echo ""
        read -p "Введите номер [0-6]: " choice
        
        case "$choice" in
            1)
                cmd_build
                read -p "Нажмите Enter для возврата в меню..." _
                ;;
            2)
                cmd_run
                read -p "Нажмите Enter для возврата в меню..." _
                ;;
            3)
                release_wizard
                read -p "Нажмите Enter для возврата в меню..." _
                ;;
            4)
                cmd_test
                read -p "Нажмите Enter для возврата в меню..." _
                ;;
            5)
                cmd_clean
                read -p "Нажмите Enter для возврата в меню..." _
                ;;
            6)
                cmd_status
                read -p "Нажмите Enter для возврата в меню..." _
                ;;
            0|q|Q)
                echo -e "${GREEN}До встречи! 👋${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Неверный ввод!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Обработка аргументов командной строки
if [ $# -eq 0 ]; then
    interactive_menu
else
    COMMAND="$1"
    shift
    case "$COMMAND" in
        build)   cmd_build "$@" ;;
        run)     cmd_run "$@" ;;
        release) ./scripts/release.sh "$@" ;;
        test)    cmd_test "$@" ;;
        clean)   cmd_clean "$@" ;;
        status)  cmd_status "$@" ;;
        menu)    interactive_menu ;;
        help|-h|--help)
            echo "Использование: ./manage.sh [команда]"
            echo ""
            echo "Команды:"
            echo "  (без аргументов)    Запуск интерактивного меню (TUI)"
            echo "  build               Сборка Just Screenshot.app"
            echo "  run                 Сборка и запуск приложения"
            echo "  release <версия>    Публикация релиза на GitHub и Sparkle"
            echo "  test                Запуск тестов"
            echo "  clean               Очистка артефактов"
            echo "  status              Проверка окружения и сертификатов"
            ;;
        *)
            echo -e "${RED}Неизвестная команда:${NC} $COMMAND"
            echo "Запустите ./manage.sh --help для справки или ./manage.sh для интерактивного меню."
            exit 1
            ;;
    esac
fi
