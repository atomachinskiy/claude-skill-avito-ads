#!/usr/bin/env bash
# Список кампаний с фильтрами.
#
# Usage:
#   list-campaigns.sh                           # все кампании (page 1, limit 20)
#   list-campaigns.sh active                    # только active
#   list-campaigns.sh active CPC                # active + CPC payment model
#   PAGE=2 LIMIT=50 list-campaigns.sh active   # с пагинацией

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

ACC="$(account_id)"
STATUS="${1:-}"
PAYMENT="${2:-}"
PAGE="${PAGE:-1}"
LIMIT="${LIMIT:-20}"

FILTER='{}'
if [ -n "$STATUS" ] && [ -n "$PAYMENT" ]; then
  FILTER="{\"statuses\":[\"$STATUS\"],\"paymentModels\":[\"$PAYMENT\"]}"
elif [ -n "$STATUS" ]; then
  FILTER="{\"statuses\":[\"$STATUS\"]}"
elif [ -n "$PAYMENT" ]; then
  FILTER="{\"paymentModels\":[\"$PAYMENT\"]}"
fi

BODY="{\"filter\":$FILTER,\"limit\":$LIMIT,\"page\":$PAGE}"

api_request POST "/v1/account/$ACC/campaigns" \
  -H 'Content-Type: application/json' \
  --data "$BODY" | jq .
