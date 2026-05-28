#!/usr/bin/env bash
# Avito Реклама skill — общие хелперы.
#
# Файлы:
#   ~/.claude/skills/avito-ads/config/.env   — креды пользователя (client_id, client_secret, accountID, mode)
#   ~/.claude/secrets/avito-ads-tokens       — issued access_token (24h TTL)
#
# Принципы:
# - Секреты всегда chmod 600.
# - Auth flow: client_credentials → access_token. Авто-перевыпуск через client_credentials при 401.
# - НИКОГДА не печатает client_secret или token в stdout (только короткий префикс).
# - По умолчанию работаем в песочнице (api.avito.ru/ads-sandbox/), prod включается через AVITO_ADS_MODE=prod.

set -e

SECRETS_DIR="$HOME/.claude/secrets"
TOKENS_FILE="$SECRETS_DIR/avito-ads-tokens"
SKILL_DIR="${AVITO_ADS_SKILL_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
ENV_FILE="$SKILL_DIR/config/.env"

mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR" 2>/dev/null || true

CYAN=$'\033[0;36m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; RST=$'\033[0m'
ok()    { echo "${GREEN}✓ $*${RST}"; }
warn()  { echo "${YELLOW}⚠ $*${RST}"; }
die()   { echo "${RED}✗ $*${RST}" >&2; exit 1; }

# load_env: читает .env пользователя (client_id, client_secret, accountID, mode)
load_env() {
  [ -f "$ENV_FILE" ] || return 1
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
  return 0
}

# api_base: возвращает базовый URL в зависимости от AVITO_ADS_MODE
api_base() {
  local mode="${AVITO_ADS_MODE:-sandbox}"
  if [ -n "${AVITO_ADS_BASE:-}" ]; then
    if [ "$mode" = "prod" ]; then
      echo "$AVITO_ADS_BASE/ads"
    else
      echo "$AVITO_ADS_BASE/ads-sandbox"
    fi
    return
  fi
  if [ "$mode" = "prod" ]; then
    echo "https://api.avito.ru/ads"
  else
    echo "https://api.avito.ru/ads-sandbox"
  fi
}

token_url() {
  echo "${AVITO_ADS_TOKEN_URL:-https://api.avito.ru/token}"
}

# load_tokens: читает access_token из ~/.claude/secrets/avito-ads-tokens
load_tokens() {
  [ -f "$TOKENS_FILE" ] || return 1
  set -a
  # shellcheck disable=SC1090
  . "$TOKENS_FILE"
  set +a
  [ -n "${AVITO_ADS_ACCESS_TOKEN:-}" ] || return 1
  return 0
}

# save_tokens: записывает access (+ expires_at) в файл
save_tokens() {
  local access="$1" expires_in="$2"
  local now expires_at
  now="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  # Calculate absolute expiry (now + expires_in seconds) for robust comparison later.
  if command -v python3 >/dev/null 2>&1; then
    expires_at="$(python3 -c "import datetime,sys;print((datetime.datetime.utcnow()+datetime.timedelta(seconds=int(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$expires_in")"
  else
    expires_at="$(date -u -d "+$expires_in seconds" +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "$now")"
  fi
  cat > "$TOKENS_FILE" <<EOF
# Avito Реклама access token (issued $now)
# expires in $expires_in seconds (≈ 24h)
AVITO_ADS_ACCESS_TOKEN=$access
AVITO_ADS_TOKEN_EXPIRES_AT=$expires_at
AVITO_ADS_TOKEN_MODE=${AVITO_ADS_MODE:-sandbox}
EOF
  chmod 600 "$TOKENS_FILE"
}

# do_login: получить новый access_token через client_credentials
# requires .env to be loaded
do_login() {
  load_env || die "Не найден $ENV_FILE — скопируй из config/.env.example и заполни AVITO_ADS_CLIENT_ID/AVITO_ADS_CLIENT_SECRET"
  [ -n "${AVITO_ADS_CLIENT_ID:-}" ] || die "AVITO_ADS_CLIENT_ID пустой в $ENV_FILE"
  [ -n "${AVITO_ADS_CLIENT_SECRET:-}" ] || die "AVITO_ADS_CLIENT_SECRET пустой в $ENV_FILE"

  local resp
  resp="$(curl -sS -X POST "$(token_url)" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "client_id=$AVITO_ADS_CLIENT_ID" \
    --data-urlencode "client_secret=$AVITO_ADS_CLIENT_SECRET")"
  local access expires
  access="$(printf '%s' "$resp" | jq -r '.access_token // empty')"
  expires="$(printf '%s' "$resp" | jq -r '.expires_in // 86400')"
  [ -n "$access" ] || die "Login failed: $(printf '%s' "$resp" | head -c 200)"
  save_tokens "$access" "$expires"
  ok "Got access token (mode=${AVITO_ADS_MODE:-sandbox}, ttl=${expires}s)"
}

# token_is_fresh: возвращает 0 если access_token валиден ещё минимум 5 минут
token_is_fresh() {
  load_tokens || return 1
  [ -n "${AVITO_ADS_TOKEN_EXPIRES_AT:-}" ] || return 1
  # Compare expires_at vs (now + 5 min) using python for portability
  python3 -c "
import datetime, sys
try:
    exp = datetime.datetime.strptime('${AVITO_ADS_TOKEN_EXPIRES_AT}', '%Y-%m-%dT%H:%M:%SZ')
    now = datetime.datetime.utcnow()
    sys.exit(0 if (exp - now).total_seconds() > 300 else 1)
except Exception:
    sys.exit(1)
" 2>/dev/null
}

# ensure_token: если токена нет / просрочен — обновить
ensure_token() {
  if token_is_fresh; then
    return 0
  fi
  do_login
}

# api_request <METHOD> <PATH> [curl args ...]
# Делает запрос с авто-refresh при 401. Печатает body в stdout.
# PATH начинается с /v1/... (без префикса ads/ или ads-sandbox/).
api_request() {
  local method="$1" path="$2"; shift 2
  ensure_token
  load_tokens

  local url="$(api_base)$path"
  local resp code body headers_file
  headers_file="$(mktemp)"
  resp="$(curl -sS -w '\n__HTTP_CODE__%{http_code}' \
    -X "$method" \
    -H "Authorization: Bearer $AVITO_ADS_ACCESS_TOKEN" \
    -H "Accept: application/json" \
    -D "$headers_file" \
    "$@" \
    "$url")"
  code="$(printf '%s' "$resp" | tail -n1 | sed 's/^.*__HTTP_CODE__//')"
  body="$(printf '%s' "$resp" | sed '$d' | sed 's/__HTTP_CODE__[0-9]*$//')"

  if [ "$code" = "401" ]; then
    warn "Got 401 — перевыпускаю токен"
    do_login
    load_tokens
    resp="$(curl -sS -w '\n__HTTP_CODE__%{http_code}' \
      -X "$method" \
      -H "Authorization: Bearer $AVITO_ADS_ACCESS_TOKEN" \
      -H "Accept: application/json" \
      -D "$headers_file" \
      "$@" \
      "$url")"
    code="$(printf '%s' "$resp" | tail -n1 | sed 's/^.*__HTTP_CODE__//')"
    body="$(printf '%s' "$resp" | sed '$d' | sed 's/__HTTP_CODE__[0-9]*$//')"
  fi

  # Surface Api-Point-Balance to stderr so the caller can see remaining points
  local balance
  balance="$(grep -i '^Api-Point-Balance:' "$headers_file" 2>/dev/null | awk -F': ' '{print $2}' | tr -d '\r\n' || true)"
  if [ -n "$balance" ]; then
    warn "Api-Point-Balance: $balance"
  fi
  rm -f "$headers_file"

  if [ "$code" -ge 400 ]; then
    warn "HTTP $code: $url"
  fi
  printf '%s' "$body"
}

# account_id: возвращает accountID из env (нужен почти во всех URL)
account_id() {
  load_env || die "Не найден $ENV_FILE"
  [ -n "${AVITO_ADS_ACCOUNT_ID:-}" ] || die "AVITO_ADS_ACCOUNT_ID пустой в $ENV_FILE — пропиши accountID кабинета"
  echo "$AVITO_ADS_ACCOUNT_ID"
}
