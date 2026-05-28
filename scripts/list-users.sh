#!/usr/bin/env bash
# Список пользователей рекламного аккаунта с их ролями.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

ACC="$(account_id)"
api_request GET "/v1/account/$ACC/users" | jq .
