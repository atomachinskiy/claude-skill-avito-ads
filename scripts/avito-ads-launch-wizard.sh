#!/usr/bin/env bash
# avito-ads-launch-wizard.sh — открывает ОТДЕЛЬНОЕ окно терминала с интерактивным
# мастером настройки. AI вызывает этот скрипт через Bash tool — у пользователя
# открывается окно (Terminal на Mac / новое окно на Linux), где он вводит
# client_id, client_secret, accountID от Avito Реклама.
#
# AI client_secret не видит — он остаётся в отдельном окне.
#
# На Windows AI должен звать avito-ads-launch-wizard.ps1 через PowerShell.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WIZARD="$SCRIPT_DIR/avito-ads-oauth-setup.sh"
[ -f "$WIZARD" ] || { echo "❌ Не найден $WIZARD"; exit 1; }
chmod +x "$WIZARD"

OS="$(uname -s 2>/dev/null || echo unknown)"

case "$OS" in
  Darwin)
    ESCAPED_PATH="${WIZARD//\"/\\\"}"
    /usr/bin/osascript <<EOF
tell application "Terminal"
    activate
    do script "bash \"$ESCAPED_PATH\""
end tell
EOF
    echo "✅ Открыл Terminal.app с мастером Avito Реклама. Перейди в новое окно."
    ;;

  Linux|WSL*)
    if command -v gnome-terminal >/dev/null 2>&1; then
      gnome-terminal -- bash -c "bash \"$WIZARD\"; exec bash"
      echo "✅ Открыл gnome-terminal с мастером."
    elif command -v konsole >/dev/null 2>&1; then
      konsole -e bash -c "bash \"$WIZARD\"; exec bash" &
      echo "✅ Открыл konsole с мастером."
    elif command -v xterm >/dev/null 2>&1; then
      xterm -e "bash \"$WIZARD\"; bash" &
      echo "✅ Открыл xterm с мастером."
    else
      echo "⚠ Не нашёл графический эмулятор терминала. Запусти вручную:"
      echo "    bash \"$WIZARD\""
    fi
    ;;

  *)
    echo "⚠ OS=$OS — авто-запуск не поддержан. Запусти вручную:"
    echo "    bash \"$WIZARD\""
    ;;
esac
