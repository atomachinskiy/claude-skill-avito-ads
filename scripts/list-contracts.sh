#!/usr/bin/env bash
# Список договоров (для ОРД).
#
# Usage:
#   list-contracts.sh                # все
#   PAGE=2 LIMIT=50 list-contracts.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

ACC="$(account_id)"
PAGE="${PAGE:-1}"
LIMIT="${LIMIT:-50}"

BODY="{\"filter\":{},\"limit\":$LIMIT,\"page\":$PAGE}"

api_request POST "/v1/account/$ACC/contracts" \
  -H 'Content-Type: application/json' \
  --data "$BODY" | jq .
