#!/usr/bin/env bash
# Сохранено для обратной совместимости. Запускает единый скрипт сборки.
exec "$(dirname "$0")/scripts/build.sh" "$@"
