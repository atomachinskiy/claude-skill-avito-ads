#!/usr/bin/env bash
# sandbox-refresh-account.sh — создаёт свежий тестовый аккаунт в песочнице
# и записывает его ID в config/.env как AVITO_ADS_SANDBOX_ACCOUNT_ID.
#
# Sandbox-аккаунты живут до 00:00 UTC текущего дня — запускай этот скрипт
# каждый день перед работой, или когда .sh-обёртки начинают отдавать 404.
#
# В sandbox-режиме лимит: 1 тестовый аккаунт в сутки.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

load_env

if [ "${AVITO_ADS_MODE:-sandbox}" != "sandbox" ]; then
  warn "AVITO_ADS_MODE=${AVITO_ADS_MODE} — этот скрипт нужен только для sandbox-режима."
  warn "В prod accountID не меняется. Если переключаешься в sandbox: смени AVITO_ADS_MODE=sandbox и запусти ещё раз."
  exit 0
fi

[ -n "${AVITO_ADS_ACCOUNT_ID:-}" ] || die "AVITO_ADS_ACCOUNT_ID пустой в $ENV_FILE — нужен боевой accountID как namespace для создания тестового"

ensure_token

echo "Создаю тестовый аккаунт в песочнице под namespace=$AVITO_ADS_ACCOUNT_ID..."

NOW_DATE="$(date -u +'%Y-%m-%d')"
RESP="$(api_request POST "/v1/account/$AVITO_ADS_ACCOUNT_ID" \
  -H 'Content-Type: application/json' \
  --data "{
    \"inn\": \"123456789012\",
    \"shortName\": \"Sandbox $NOW_DATE\",
    \"longName\": \"Тестовый аккаунт Avito Ads sandbox $NOW_DATE\",
    \"ogrn\": \"123456789012345\",
    \"legalAddress\": \"г. Москва, ул. Тестовая, д. 1\",
    \"actualAddress\": \"г. Москва, ул. Тестовая, д. 1\",
    \"legalType\": \"ip\",
    \"contact\": {
      \"name\": \"Sandbox Test\",
      \"phone\": \"+78005553535\"
    }
  }")"

SANDBOX_ID="$(printf '%s' "$RESP" | jq -r '.accountID // empty')"

if [ -z "$SANDBOX_ID" ]; then
  warn "Не удалось создать тестовый аккаунт:"
  printf '%s\n' "$RESP" | jq . 2>/dev/null || printf '%s\n' "$RESP"
  warn ""
  warn "Возможные причины:"
  warn "  • Лимит 1 тестового аккаунта в сутки уже использован — попробуй после 00:00 UTC"
  warn "  • Боевой accountID $AVITO_ADS_ACCOUNT_ID не имеет доступа к sandbox"
  warn "  • Если уже создан сегодня — посмотри AVITO_ADS_SANDBOX_ACCOUNT_ID в $ENV_FILE, он ещё должен быть жив до 00:00 UTC"
  exit 1
fi

upsert_env_var AVITO_ADS_SANDBOX_ACCOUNT_ID "$SANDBOX_ID"

ok "Тестовый аккаунт создан: $SANDBOX_ID"
ok "Записан в $ENV_FILE как AVITO_ADS_SANDBOX_ACCOUNT_ID"
echo ""
echo "Аккаунт живёт до 00:00 UTC. Перед работой следующим днём перезапусти этот скрипт."
echo ""
echo "Теперь можно дёргать обёртки:"
echo "  bash scripts/balance.sh         # баланс sandbox-аккаунта"
echo "  bash scripts/account.sh         # реквизиты"
echo "  bash scripts/list-campaigns.sh  # кампании (пустые в свежем sandbox)"
