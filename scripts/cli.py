#!/usr/bin/env python3
"""Универсальный CLI для Avito Реклама API.

Поддерживает любой эндпоинт через GET/POST/PUT/DELETE/PATCH.
Auto-refresh access_token при 401 (через client_credentials).

Usage:
  cli.py GET  /v1/account/{accountID}
  cli.py GET  /v1/account/{accountID}/balance
  cli.py POST /v1/account/{accountID}/campaigns --body-inline '{"filter":{}, "limit":20, "page":1}'
  cli.py POST /v1/account/{accountID}/campaigns/123/stats --body stats.json

Если placeholder {accountID} в path — подставится из config/.env AVITO_ADS_ACCOUNT_ID.

Mode (prod vs sandbox) берётся из AVITO_ADS_MODE в config/.env (default: sandbox).
"""
import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import urllib.error

SKILL_DIR = os.environ.get(
    'AVITO_ADS_SKILL_DIR',
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)
ENV_FILE = os.path.join(SKILL_DIR, 'config', '.env')
TOKENS_FILE = os.path.expanduser('~/.claude/secrets/avito-ads-tokens')


def _load_kv(path):
    """Read simple KEY=VALUE file, ignore # comments."""
    data = {}
    if not os.path.exists(path):
        return data
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            k, v = line.split('=', 1)
            data[k.strip()] = v.strip()
    return data


def _env():
    return _load_kv(ENV_FILE)


def api_base():
    env = _env()
    base = env.get('AVITO_ADS_BASE', 'https://api.avito.ru')
    mode = env.get('AVITO_ADS_MODE', 'sandbox').lower()
    suffix = '/ads' if mode == 'prod' else '/ads-sandbox'
    return base + suffix


def token_url():
    env = _env()
    return env.get('AVITO_ADS_TOKEN_URL', 'https://api.avito.ru/token')


def _save_tokens(access, expires_in, mode):
    now = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    expires_at = time.strftime(
        '%Y-%m-%dT%H:%M:%SZ',
        time.gmtime(time.time() + int(expires_in)),
    )
    payload = (
        f'# Avito Реклама access token (issued {now})\n'
        f'# expires in {expires_in} seconds (≈ 24h)\n'
        f'AVITO_ADS_ACCESS_TOKEN={access}\n'
        f'AVITO_ADS_TOKEN_EXPIRES_AT={expires_at}\n'
        f'AVITO_ADS_TOKEN_MODE={mode}\n'
    )
    os.makedirs(os.path.dirname(TOKENS_FILE), exist_ok=True)
    with open(TOKENS_FILE, 'w') as f:
        f.write(payload)
    os.chmod(TOKENS_FILE, 0o600)


def do_login():
    """Full login: client_credentials → access_token."""
    env = _env()
    cid = env.get('AVITO_ADS_CLIENT_ID')
    sec = env.get('AVITO_ADS_CLIENT_SECRET')
    if not cid or not sec:
        sys.exit(
            f'AVITO_ADS_CLIENT_ID / AVITO_ADS_CLIENT_SECRET не заполнены в {ENV_FILE}.\n'
            f'Запусти: bash {SKILL_DIR}/scripts/avito-ads-oauth-setup.sh'
        )

    body = urllib.parse.urlencode({
        'grant_type': 'client_credentials',
        'client_id': cid,
        'client_secret': sec,
    }).encode()
    req = urllib.request.Request(
        token_url(),
        data=body,
        method='POST',
        headers={'Content-Type': 'application/x-www-form-urlencoded'},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(
            f'Token request failed: HTTP {e.code} '
            f'{e.read()[:300].decode("utf-8", "replace")}'
        )
    if 'access_token' not in data:
        sys.exit(f'Token request failed: {data}')
    _save_tokens(
        data['access_token'],
        data.get('expires_in', 86400),
        env.get('AVITO_ADS_MODE', 'sandbox'),
    )
    return data['access_token']


def _token_is_fresh():
    tokens = _load_kv(TOKENS_FILE)
    if not tokens.get('AVITO_ADS_ACCESS_TOKEN'):
        return False
    exp = tokens.get('AVITO_ADS_TOKEN_EXPIRES_AT')
    if not exp:
        return False
    try:
        # Strip trailing Z and parse as UTC
        from datetime import datetime, timedelta
        exp_dt = datetime.strptime(exp.rstrip('Z'), '%Y-%m-%dT%H:%M:%S')
        now = datetime.utcnow()
        return (exp_dt - now) > timedelta(minutes=5)
    except Exception:
        return False


def get_access_token(force=False):
    if not force and _token_is_fresh():
        return _load_kv(TOKENS_FILE)['AVITO_ADS_ACCESS_TOKEN']
    return do_login()


def _resolve_path(path):
    """Substitute {accountID} placeholder from .env if present."""
    if '{accountID}' not in path:
        return path
    env = _env()
    acc = env.get('AVITO_ADS_ACCOUNT_ID')
    if not acc:
        sys.exit(
            'AVITO_ADS_ACCOUNT_ID пустой в .env, но в path есть {accountID}. '
            'Пропиши accountID или подставь его в path вручную.'
        )
    return path.replace('{accountID}', acc)


def api_request(method, path, params=None, body=None, retry_on_401=True):
    """Make API request, auto-refresh on 401, return (parsed_or_raw, api_point_balance)."""
    access = get_access_token()
    path = _resolve_path(path)
    if not path.startswith('/'):
        path = '/' + path
    url = api_base() + path
    if params:
        url += '?' + urllib.parse.urlencode(params, doseq=True)
    headers = {
        'Authorization': f'Bearer {access}',
        'Accept': 'application/json',
    }
    data = None
    if body is not None:
        if isinstance(body, (dict, list)):
            data = json.dumps(body, ensure_ascii=False).encode('utf-8')
            headers['Content-Type'] = 'application/json'
        else:
            data = body.encode('utf-8') if isinstance(body, str) else body
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            balance = r.headers.get('Api-Point-Balance')
            try:
                return json.loads(raw), balance
            except json.JSONDecodeError:
                return raw.decode('utf-8', 'replace'), balance
    except urllib.error.HTTPError as e:
        if e.code == 401 and retry_on_401:
            get_access_token(force=True)
            return api_request(method, path, params, body, retry_on_401=False)
        body_text = e.read().decode('utf-8', 'replace')
        balance = e.headers.get('Api-Point-Balance') if hasattr(e, 'headers') else None
        try:
            return {'__http_error__': e.code, 'body': json.loads(body_text)}, balance
        except json.JSONDecodeError:
            return {'__http_error__': e.code, 'body': body_text}, balance


def parse_kv_list(items):
    out = {}
    for item in items or []:
        if '=' not in item:
            sys.exit(f'--param expects k=v, got: {item}')
        k, v = item.split('=', 1)
        if k in out:
            if not isinstance(out[k], list):
                out[k] = [out[k]]
            out[k].append(v)
        else:
            out[k] = v
    return out


def main():
    ap = argparse.ArgumentParser(description='Avito Реклама API CLI')
    ap.add_argument('method', choices=['GET', 'POST', 'PUT', 'DELETE', 'PATCH'])
    ap.add_argument('path', help='e.g. /v1/account/{accountID}/balance')
    ap.add_argument('--param', action='append', default=[], help='Query param k=v')
    ap.add_argument('--body', help='Path to JSON file for body')
    ap.add_argument('--body-inline', help='Inline JSON string for body')
    ap.add_argument('--pretty', action='store_true', help='Pretty-print JSON')
    ap.add_argument('--raw', action='store_true', help='Print raw body, no JSON parse')
    ap.add_argument('--show-balance', action='store_true',
                    help='Print Api-Point-Balance header to stderr')
    args = ap.parse_args()

    params = parse_kv_list(args.param) if args.param else None
    body = None
    if args.body:
        with open(args.body) as f:
            body = json.load(f)
    elif args.body_inline:
        body = json.loads(args.body_inline)

    result, balance = api_request(args.method, args.path, params=params, body=body)

    if args.show_balance and balance:
        sys.stderr.write(f'Api-Point-Balance: {balance}\n')

    if args.raw:
        if isinstance(result, str):
            print(result)
        else:
            print(json.dumps(result, ensure_ascii=False))
    elif args.pretty:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
