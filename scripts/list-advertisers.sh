#!/usr/bin/env bash
# Список рекламодателей с фильтрами.
#
# Usage:
#   list-advertisers.sh                  # все
#   list-advertisers.sh rd               # только rd (рекламодатель)
#   list-advertisers.sh rd,ra            # rd + ra

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

ACC="$(account_id)"
ROLES="${1:-}"
PAGE="${PAGE:-1}"
LIMIT="${LIMIT:-50}"

FILTER='{}'
if [ -n "$ROLES" ]; then
  ROLES_JSON="$(printf '%s' "$ROLES" | python3 -c 'import sys,json;print(json.dumps([x.strip() for x in sys.stdin.read().split(",") if x.strip()]))')"
  FILTER="{\"roles\":$ROLES_JSON}"
fi

BODY="{\"filter\":$FILTER,\"limit\":$LIMIT,\"page\":$PAGE}"

api_request POST "/v1/account/$ACC/advertisers" \
  -H 'Content-Type: application/json' \
  --data "$BODY" | jq .
