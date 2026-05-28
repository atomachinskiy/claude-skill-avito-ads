#!/usr/bin/env bash
# Дочерние аккаунты с балансами.
#
# Usage:
#   list-children.sh           # с балансами (default)
#   list-children.sh plain     # без балансов

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

ACC="$(account_id)"
KIND="${1:-with-balances}"

if [ "$KIND" = "plain" ]; then
  api_request GET "/v1/account/$ACC/children" | jq .
else
  api_request GET "/v1/account/$ACC/children-with-balances" | jq .
fi
