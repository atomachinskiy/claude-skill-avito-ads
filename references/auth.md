# Авторизация — Avito Реклама API

## OAuth 2.0 client_credentials

```
POST https://api.avito.ru/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
client_id=ВАШ_CLIENT_ID
client_secret=ВАШ_CLIENT_SECRET
```

**Ответ:**
```json
{
  "access_token": "chGeRx_aRDqcz_fbGvPGSgebH_TMK_pKDOIzFxeR",
  "expires_in": 86400,
  "token_type": "Bearer"
}
```

## Использование

Каждый запрос:
```
Authorization: Bearer <access_token>
```

## Свойства токена

- **TTL:** 24 часа (`expires_in: 86400`)
- **Refresh-токена нет** — при истечении просто перевыпускается через client_credentials заново
- **Привязка к accountID** — токен работает только с тем аккаунтом, в котором были выпущены ключи
- **Дочерние аккаунты** — для доступа к ним нужно выпускать ключи в самом дочернем кабинете отдельно

## Где взять ключи

1. https://ads.avito.ru/cabinet → нужна роль **Администратор**
2. Аккаунт → API → «Создать ключ»
3. Сохрани `client_id` + `client_secret` (показывается один раз)

## HTTP коды

| Код | Когда | Что делать |
|---|---|---|
| 200 | OK | – |
| 400 | Невалидное тело: amount < 1, пустые обязательные, неверный формат дат, период > 100 дней | Проверить body |
| 401 | Token просрочен/невалиден | Перевыпустить через client_credentials |
| 403 | Token не имеет прав на `accountID` в path | Выпустить ключи для нужного accountID |
| 404 | Аккаунт/сущность не найдены в контексте этого токена | Проверить ID |
| 429 | Rate limit | Backoff + retry |
| 500 | Серверная ошибка | Retry |
| 503 | Service unavailable | Retry с backoff |

## Auto-refresh в скилле

`scripts/_common.sh` (для shell-обёрток) и `scripts/cli.py` (для Python) реализуют:

1. Проверяют `expires_at` в `~/.claude/secrets/avito-ads-tokens` — если до истечения меньше 5 минут, перевыпускают токен заранее
2. При 401 от API перевыпускают токен и повторяют запрос один раз

Файлы:
- `config/.env` — `client_id`, `client_secret`, `accountID`, режим (sandbox/prod), chmod 600
- `~/.claude/secrets/avito-ads-tokens` — `access_token`, `expires_at`, chmod 600
