#!/usr/bin/env bash
# Список групп объявлений (по кампании или по аккаунту).
#
# Usage:
#   list-groups.sh                     # все группы аккаунта
#   list-groups.sh 1234567890          # группы конкретной кампании

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

ACC="$(account_id)"
CAMPAIGN="${1:-}"
PAGE="${PAGE:-1}"
LIMIT="${LIMIT:-50}"

FILTER='{}'
if [ -n "$CAMPAIGN" ]; then
  FILTER="{\"campaignIDs\":[$CAMPAIGN]}"
fi

BODY="{\"filter\":$FILTER,\"limit\":$LIMIT,\"page\":$PAGE}"

api_request POST "/v1/account/$ACC/groups" \
  -H 'Content-Type: application/json' \
  --data "$BODY" | jq .
