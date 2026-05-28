#!/usr/bin/env bash
# avito-ads-oauth-setup.sh — интерактивный мастер первичной настройки.
# Запускается в ОТДЕЛЬНОМ окне терминала через avito-ads-launch-wizard.sh,
# чтобы client_secret не попал в transcript AI.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SECRETS_DIR="$HOME/.claude/secrets"
ENV_FILE="$SKILL_DIR/config/.env"
TOKENS_FILE="$SECRETS_DIR/avito-ads-tokens"

C_RESET="\033[0m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"

die() { echo -e "${C_RED}[!] $*${C_RESET}" >&2; exit 1; }

echo -e "${C_CYAN}═══════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_CYAN}  Avito Реклама API — настройка${C_RESET}"
echo -e "${C_CYAN}═══════════════════════════════════════════════════════════════${C_RESET}"
echo ""
echo "Где взять ключи:"
echo "  1. Зайди в https://ads.avito.ru/cabinet"
echo "  2. Аккаунт → API → «Создать ключ» (нужна роль Администратор)"
echo "  3. Скопируй client_id и client_secret"
echo "  4. Запомни accountID (виден в URL кабинета и в API)"
echo ""

command -v jq   >/dev/null 2>&1 || die "Не найден jq.   macOS: brew install jq | Linux: sudo apt install jq"
command -v curl >/dev/null 2>&1 || die "Не найден curl"

mkdir -p "$SECRETS_DIR" "$SKILL_DIR/config"
chmod 700 "$SECRETS_DIR" 2>/dev/null || true

# Если .env существует — спросить переиспользовать или нет
USE_EXISTING=0
if [ -f "$ENV_FILE" ] \
   && grep -q '^AVITO_ADS_CLIENT_ID=.\+$' "$ENV_FILE" 2>/dev/null \
   && grep -q '^AVITO_ADS_CLIENT_SECRET=.\+$' "$ENV_FILE" 2>/dev/null; then
  echo -e "${C_GREEN}[✓]${C_RESET} Найден заполненный $ENV_FILE"
  read -r -p "Использовать существующие ключи? [Y/n] " ans
  case "$ans" in
    n|N|no|No) USE_EXISTING=0 ;;
    *) USE_EXISTING=1 ;;
  esac
fi

MODE="${AVITO_ADS_MODE:-sandbox}"

if [ "$USE_EXISTING" = "0" ]; then
  echo ""
  echo -e "${C_YELLOW}Введи реквизиты из кабинета Авито Реклама${C_RESET}"
  echo ""

  read -r -p "client_id: " AVITO_ADS_CLIENT_ID
  [ -n "$AVITO_ADS_CLIENT_ID" ] || die "client_id пустой"

  read -r -s -p "client_secret (не отображается): " AVITO_ADS_CLIENT_SECRET; echo
  [ -n "$AVITO_ADS_CLIENT_SECRET" ] || die "client_secret пустой"

  read -r -p "accountID: " AVITO_ADS_ACCOUNT_ID
  [ -n "$AVITO_ADS_ACCOUNT_ID" ] || die "accountID пустой"

  echo ""
  echo "Режим работы:"
  echo "  [s] sandbox (https://api.avito.ru/ads-sandbox/) — рекомендую для первых тестов"
  echo "  [p] prod    (https://api.avito.ru/ads/)        — боевые запросы, тратят API-баллы"
  read -r -p "Режим [s/p] (default s): " mode_ans
  case "$mode_ans" in
    p|P|prod) MODE="prod" ;;
    *) MODE="sandbox" ;;
  esac

  cat > "$ENV_FILE" <<EOF
# Avito Реклама API credentials
# Сгенерировано $(date +'%Y-%m-%d %H:%M:%S')
AVITO_ADS_CLIENT_ID=$AVITO_ADS_CLIENT_ID
AVITO_ADS_CLIENT_SECRET=$AVITO_ADS_CLIENT_SECRET
AVITO_ADS_ACCOUNT_ID=$AVITO_ADS_ACCOUNT_ID
AVITO_ADS_MODE=$MODE
EOF
  chmod 600 "$ENV_FILE"
  echo -e "${C_GREEN}[✓]${C_RESET} Сохранил в $ENV_FILE (chmod 600)"
else
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  MODE="${AVITO_ADS_MODE:-sandbox}"
fi

if [ "$MODE" = "prod" ]; then
  API_BASE="https://api.avito.ru/ads"
else
  API_BASE="https://api.avito.ru/ads-sandbox"
fi

echo ""
echo -e "${C_YELLOW}Получаю access_token...${C_RESET}"
RESP="$(curl -sS -w '\n__HTTP_CODE__%{http_code}' -X POST "https://api.avito.ru/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=$AVITO_ADS_CLIENT_ID" \
  --data-urlencode "client_secret=$AVITO_ADS_CLIENT_SECRET")"
HTTP_CODE="$(printf '%s' "$RESP" | tail -n1 | sed 's/^.*__HTTP_CODE__//')"
BODY="$(printf '%s' "$RESP" | sed '$d')"

if [ "$HTTP_CODE" != "200" ]; then
  echo -e "${C_RED}[!] HTTP $HTTP_CODE${C_RESET}"
  echo "$BODY" | head -c 300
  echo ""
  die "Не удалось получить токен. Проверь client_id/client_secret в $ENV_FILE и перезапусти мастер."
fi

ACCESS="$(printf '%s' "$BODY" | jq -r '.access_token // empty')"
EXPIRES="$(printf '%s' "$BODY" | jq -r '.expires_in // 86400')"
[ -n "$ACCESS" ] || die "Не получили access_token: $BODY"

NOW="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
EXPIRES_AT="$(python3 -c "import datetime,sys;print((datetime.datetime.utcnow()+datetime.timedelta(seconds=int(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$EXPIRES")"

cat > "$TOKENS_FILE" <<EOF
# Avito Реклама access token (issued $NOW)
# expires in $EXPIRES seconds (≈ 24h)
AVITO_ADS_ACCESS_TOKEN=$ACCESS
AVITO_ADS_TOKEN_EXPIRES_AT=$EXPIRES_AT
AVITO_ADS_TOKEN_MODE=$MODE
EOF
chmod 600 "$TOKENS_FILE"
echo -e "${C_GREEN}[✓]${C_RESET} Токен получен (ttl=${EXPIRES}s)"
echo -e "${C_GREEN}[✓]${C_RESET} Сохранён в $TOKENS_FILE"

echo ""
echo -e "${C_YELLOW}Проверяю аккаунт...${C_RESET}"
ACC_INFO="$(curl -sS -H "Authorization: Bearer $ACCESS" -H 'Accept: application/json' \
  "$API_BASE/v1/account/$AVITO_ADS_ACCOUNT_ID")"
BAL_INFO="$(curl -sS -H "Authorization: Bearer $ACCESS" -H 'Accept: application/json' \
  "$API_BASE/v1/account/$AVITO_ADS_ACCOUNT_ID/balance")"

SHORT_NAME="$(printf '%s' "$ACC_INFO" | jq -r '.account.shortName // empty')"
INN="$(printf '%s' "$ACC_INFO" | jq -r '.account.inn // empty')"
BAL="$(printf '%s' "$BAL_INFO" | jq -r '.balance // 0')"
BAL_BONUS="$(printf '%s' "$BAL_INFO" | jq -r '.bonusBalance // 0')"

echo ""
echo -e "${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_GREEN}  ✅ Avito Реклама API настроен и работает${C_RESET}"
echo -e "${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
echo ""
if [ -n "$SHORT_NAME" ]; then
  echo "  Аккаунт:        $SHORT_NAME (ИНН $INN)"
fi
echo "  accountID:      $AVITO_ADS_ACCOUNT_ID"
echo "  Режим:          $MODE  ($API_BASE)"
echo "  Баланс:         $BAL ₽"
echo "  Бонусный:       $BAL_BONUS ₽"
echo ""
echo "  Конфиг:    $ENV_FILE"
echo "  Токены:    $TOKENS_FILE"
echo ""
echo "Дальше в чате с Клодом можно спрашивать:"
echo "  • «Покажи активные кампании в Avito Реклама»"
echo "  • «Сделай отчёт по тратам за месяц»"
echo "  • «Сравни CPM/CTR кампаний за неделю»"
echo "  • «Подними бюджет группы 12345 до 5000»"
echo ""
read -r -p "Готово. Нажми Enter чтобы закрыть это окно… "
