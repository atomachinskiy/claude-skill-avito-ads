#!/usr/bin/env bash
# Ручное обновление access_token (через client_credentials).
# Авто-обновление сделает api_request при 401 сам — этот скрипт нужен только если
# хочется заранее освежить токен (например, после долгого простоя).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

do_login
