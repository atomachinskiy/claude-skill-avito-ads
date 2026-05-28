#!/usr/bin/env bash
# Текущий баланс рекламного аккаунта (₽ + бонусы).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

ACC="$(account_id)"
api_request GET "/v1/account/$ACC/balance" | jq .
