#!/usr/bin/env bash
# Статистика по кампании за период (до 100 дней).
#
# Usage:
#   stats-campaign.sh 1234567890 2025-01-01 2025-01-31

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

CAMPAIGN_ID="${1:-}"
DATE_FROM="${2:-}"
DATE_TO="${3:-}"

if [ -z "$CAMPAIGN_ID" ] || [ -z "$DATE_FROM" ] || [ -z "$DATE_TO" ]; then
  die "Usage: $0 <campaign_id> <date_from YYYY-MM-DD> <date_to YYYY-MM-DD>"
fi

ACC="$(account_id)"
BODY="{\"dateFrom\":\"$DATE_FROM\",\"dateTo\":\"$DATE_TO\"}"

api_request POST "/v1/account/$ACC/campaigns/$CAMPAIGN_ID/stats" \
  -H 'Content-Type: application/json' \
  --data "$BODY" | jq .
