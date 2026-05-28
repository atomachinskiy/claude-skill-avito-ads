#!/usr/bin/env bash
# Список креативов (по группе или по аккаунту).
#
# Usage:
#   list-creatives.sh                   # все креативы аккаунта
#   list-creatives.sh group 111222333   # креативы группы
#   list-creatives.sh campaign 12345    # креативы кампании

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

ACC="$(account_id)"
KIND="${1:-}"
ID="${2:-}"
PAGE="${PAGE:-1}"
LIMIT="${LIMIT:-50}"

FILTER='{}'
case "$KIND" in
  group)    FILTER="{\"groupIDs\":[$ID]}" ;;
  campaign) FILTER="{\"campaignIDs\":[$ID]}" ;;
esac

BODY="{\"filter\":$FILTER,\"limit\":$LIMIT,\"page\":$PAGE}"

api_request POST "/v1/account/$ACC/creatives" \
  -H 'Content-Type: application/json' \
  --data "$BODY" | jq .
