#!/usr/bin/env bash
# Изменить ставку (price) группы — CPC или CPM (определяется моделью оплаты кампании).
# Только для групп с ручным управлением ставкой.
#
# Usage:
#   change-group-price.sh 987654321 25

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

GROUP_ID="${1:-}"
PRICE="${2:-}"

if [ -z "$GROUP_ID" ] || [ -z "$PRICE" ]; then
  die "Usage: $0 <group_id> <price_rub>"
fi

ACC="$(account_id)"
BODY="{\"price\":$PRICE}"

api_request POST "/v1/account/$ACC/group/$GROUP_ID/change-price" \
  -H 'Content-Type: application/json' \
  --data "$BODY" | jq .
