#!/usr/bin/env bash
# Реквизиты текущего рекламного аккаунта (ЮЛ/ИП, ИНН, ОГРН, адрес).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

ACC="$(account_id)"
api_request GET "/v1/account/$ACC" | jq .
