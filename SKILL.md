---
name: avito-ads
description: Работа с публичным API Авито Реклама (api.avito.ru/ads) — DSP-кабинет с CPM/CPC баннерами, HTML и видео. Чтение (аккаунт, рекламодатели, договоры, кампании, группы, креативы, статистика до 100 дней с дневной гранулярностью) и запись (изменение бюджета и ставки групп с ручным управлением, переводы между родительским и дочерним аккаунтами, ОРД-цикл — создание рекламодателей и договоров, управление пользователями). Используй когда клиент просит проанализировать DSP-рекламу на Авито, построить отчёт по тратам, сравнить кампании, починить ставку, добавить рекламодателя или договор для ОРД-маркировки, перевести деньги между связанными аккаунтами.
allowed-tools: Bash, Read, Write, Edit
---

# Avito Реклама API — публичный DSP-кабинет

Скилл для работы с публичным API кабинета **Avito Реклама** — это **DSP-платформа** Avito для performance-рекламы (баннеры, HTML, видео с моделями CPM/CPC). Не путать с classifieds API (объявления, мессенджер, продвижение) — там другой набор эндпоинтов на тех же `api.avito.ru`.

> **Кому это:** перформанс-маркетологам которые льют рекламу на Avito Реклама, агентствам с несколькими клиентами (через child-аккаунты и договоры), внутренним командам с одним кабинетом, разработчикам интеграций с MMP / BI / Sheets.

---

## КОГДА ТРИГГЕРИТЬСЯ

**Чтение / аналитика**
- «Покажи активные кампании в Avito Реклама»
- «Сколько потрачено за период X»
- «Какой баланс у моего кабинета / у дочерних аккаунтов»
- «Сделай отчёт по тратам за месяц»
- «Сравни CPM/CTR кампаний за неделю»
- «Покажи группы с расходом > 5000₽ за последние 7 дней»
- «Найди креативы с CTR < 0.5% — кандидаты на отключение»

**Управление ставкой (только ручные стратегии)**
- «Подними бюджет группы 12345 до 5000»
- «Снизь CPC группы 67890 до 15₽»

**ОРД для агентств**
- «Создай рекламодателя ООО X с ИНН Y»
- «Заведи договор service на рекламодателя Z, номер ДА-2025/01»
- «Покажи мои договоры»
- «Создай доп. соглашение к договору 1122334455»

**Мультиаккаунт**
- «Покажи балансы по всем дочерним аккаунтам»
- «Создай дочерний аккаунт для нового клиента»
- «Переведи 5000₽ с родителя на дочку 998186750»

**Пользователи**
- «Добавь userID 123456 как админа в кабинет»
- «Покажи кто имеет доступ к кабинету»
- «Удали юзера 654321»

---

## АРХИТЕКТУРА API

### Base URL

```
prod:    https://api.avito.ru/ads/v1/...
sandbox: https://api.avito.ru/ads-sandbox/v1/...
```

Режим переключается через `AVITO_ADS_MODE` в `config/.env` (`sandbox` | `prod`). По умолчанию — sandbox.

**Дуальный accountID в .env:**
- `AVITO_ADS_ACCOUNT_ID` — боевой ID кабинета (стабильный)
- `AVITO_ADS_SANDBOX_ACCOUNT_ID` — ID тестового аккаунта в песочнице (живёт до 00:00 UTC)

`cli.py` и `.sh`-обёртки автоматически подставляют `SANDBOX_ACCOUNT_ID` когда `MODE=sandbox`, и `ACCOUNT_ID` когда `MODE=prod`. Мастер настройки создаёт тестовый аккаунт автоматически при выборе sandbox. Для ежедневного обновления — `bash scripts/sandbox-refresh-account.sh` (лимит 1 тестовый в сутки).

### Auth flow (OAuth 2.0 client_credentials)

```
POST /token        grant_type=client_credentials + client_id + client_secret
                   → { access_token, expires_in: 86400, token_type: "Bearer" }
```

- **access_token** живёт **24 часа**, передаётся в `Authorization: Bearer <token>`
- **Refresh-токена нет** — при истечении просто перевыпускается через client_credentials заново
- Ключи выпускаются в кабинете: Аккаунт → API → «Создать ключ» (доступно только админу)
- Ключи привязаны к конкретному `accountID` — для дочерних аккаунтов нужны отдельные ключи

`scripts/_common.sh` и `scripts/cli.py` делают auto-refresh: при 401 перевыпускают токен и повторяют запрос.

### Иерархия сущностей

```
Account (рекламный кабинет одного ЮЛ/ИП)
├── Advertisers (рекламодатели — ЮЛ/ИП от лица которых размещается реклама)
│   └── Contracts (договоры — если рекламодатель ≠ аккаунт)
├── Child accounts (дочерние аккаунты на одном договоре с родителем)
└── Campaigns (кампании — общая цель + модель оплаты CPM/CPC + тип textImage/HTML/video)
    └── Groups (группы — бюджет, ставка, расписание, таргетинг)
        └── Creatives (креативы — конкретные баннеры/видео/HTML)
```

### Группы эндпоинтов

| Группа | Эндпоинты | Что |
|---|---|---|
| Account | 3 | get account, get balance, **POST create (только sandbox)** |
| Child accounts | 5 | list children, list with balances, create-nonpayer-child, funds-transfer, bonus-transfer |
| Advertisers (ОРД) | 2 | create-advertiser, list advertisers |
| Contracts (ОРД) | 2 | create-contract (service/intermediary/external + доп. соглашения), list contracts |
| Campaigns | 1 | list (создание ТОЛЬКО через UI) |
| Groups | 3 | list, change-budget, change-price (только ручные стратегии) |
| Creatives | 1 | list (создание ТОЛЬКО через UI) |
| Stats | 3 | campaign stats, groups stats, creatives stats (до 100 дней) |
| Users | 4 | list, add-user, set-user-role, delete-user |

Полная карта эндпоинтов и схемы тел запросов — в `references/endpoints.md`.

---

## УСТАНОВКА (универсальная, для любого пользователя)

### Шаг 1 — Клонирование

```bash
git clone https://github.com/atomachinskiy/claude-skill-avito-ads.git ~/.claude/skills/avito-ads
chmod +x ~/.claude/skills/avito-ads/scripts/*.sh
```

### Шаг 2 — Получить ключи в кабинете Avito Реклама

1. Зайди в https://ads.avito.ru/cabinet (нужна роль **Администратор**)
2. Аккаунт → API → «Создать ключ»
3. Скопируй `client_id` и `client_secret`
4. Запомни `accountID` — числовой ID кабинета (виден в UI и URL)

⚠️ **Под каждый кабинет — свои ключи.** Если работаешь с дочерним аккаунтом — выпускай ключи внутри него отдельно. Ключи родителя не дают доступа к дочерним.

### Шаг 3 — Запустить интерактивный мастер

**macOS / Linux:**
```bash
bash ~/.claude/skills/avito-ads/scripts/avito-ads-launch-wizard.sh
```

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\avito-ads\scripts\avito-ads-launch-wizard.ps1"
```

Мастер откроется в **отдельном окне терминала** (чтобы `client_secret` не попал в transcript AI), запросит `client_id`/`client_secret`/`accountID`/режим, получит токен и сохранит:

- `config/.env` (chmod 600) — креды и режим
- `~/.claude/secrets/avito-ads-tokens` (chmod 600) — access_token

### Шаг 4 — Sanity-check

```bash
bash ~/.claude/skills/avito-ads/scripts/balance.sh
bash ~/.claude/skills/avito-ads/scripts/account.sh
```

Должны вернуться баланс и реквизиты твоего аккаунта.

### Альтернатива: ручная настройка без мастера

```bash
cp ~/.claude/skills/avito-ads/config/.env.example ~/.claude/skills/avito-ads/config/.env
chmod 600 ~/.claude/skills/avito-ads/config/.env
# отредактируй .env: впиши AVITO_ADS_CLIENT_ID, AVITO_ADS_CLIENT_SECRET, AVITO_ADS_ACCOUNT_ID, AVITO_ADS_MODE
bash ~/.claude/skills/avito-ads/scripts/auth-refresh.sh
```

---

## КАТАЛОГ СКРИПТОВ

```
scripts/
├── _common.sh                       # Auth + auto-refresh + api_request helper (для всех .sh)
├── cli.py                           # Универсальный CLI: любой HTTP method + path
├── avito-ads-launch-wizard.sh       # macOS/Linux обёртка которая открывает мастер в отдельном окне
├── avito-ads-launch-wizard.ps1      # Windows-версия (PowerShell)
├── avito-ads-oauth-setup.sh         # Интерактивный мастер первичной настройки (.sh) — auto-создаёт sandbox-аккаунт
├── avito-ads-oauth-setup.ps1        # Интерактивный мастер первичной настройки (.ps1)
├── auth-refresh.sh                  # Ручное обновление access_token
├── sandbox-refresh-account.sh       # Создать свежий sandbox-аккаунт (запускай ежедневно в sandbox-режиме)
│
├── account.sh                       # Реквизиты аккаунта
├── balance.sh                       # Баланс + бонусы
├── list-advertisers.sh              # Рекламодатели (фильтр по ролям rd/ra/rr)
├── list-contracts.sh                # Договоры (для ОРД)
├── list-campaigns.sh                # Кампании (фильтр по статусу/модели оплаты)
├── list-groups.sh                   # Группы (по аккаунту или по кампании)
├── list-creatives.sh                # Креативы (по группе / по кампании / по аккаунту)
├── list-children.sh                 # Дочерние аккаунты (с балансами или без)
├── list-users.sh                    # Пользователи аккаунта
├── stats-campaign.sh                # Статистика кампании за период
├── change-group-budget.sh           # Изменить бюджет группы
└── change-group-price.sh            # Изменить ставку группы (CPC или CPM по модели кампании)
```

### Универсальный CLI

```bash
python3 scripts/cli.py GET  /v1/account/{accountID}
python3 scripts/cli.py GET  /v1/account/{accountID}/balance
python3 scripts/cli.py POST /v1/account/{accountID}/campaigns --body-inline '{"filter":{},"limit":20,"page":1}'
python3 scripts/cli.py POST /v1/account/{accountID}/campaigns/987/stats --body stats.json
```

- `{accountID}` в path автоматически подставляется из `AVITO_ADS_ACCOUNT_ID` в `.env`
- `--param k=v` — query параметры (повторяй для нескольких)
- `--body file.json` — body из файла (для POST/PUT)
- `--body-inline '{...}'` — body inline
- `--pretty` — pretty-print JSON
- `--raw` — без парсинга JSON
- `--show-balance` — печатает заголовок `Api-Point-Balance` в stderr

---

## КЛЮЧЕВЫЕ СЦЕНАРИИ

### Сценарий 1 — Отчёт по активным кампаниям за месяц

```bash
# 1. Все активные кампании
bash scripts/list-campaigns.sh active | jq '.campaigns[] | {id, name, paymentModel, budget}'

# 2. Для каждой кампании — статистика за период
for cid in $(bash scripts/list-campaigns.sh active | jq '.campaigns[].id'); do
  bash scripts/stats-campaign.sh "$cid" 2025-04-01 2025-04-30 \
    | jq '.campaign | {id, name, total: .totalData}'
done
```

AI агрегирует totalData по всем кампаниям, считает доли spend/clicks, формирует таблицу/HTML-отчёт.

### Сценарий 2 — Поиск слабых креативов

```bash
# Все креативы конкретной группы
bash scripts/list-creatives.sh group 111222333

# Статистика по креативам кампании за месяц
python3 scripts/cli.py POST /v1/account/{accountID}/campaigns/12345/creatives/stats \
  --body-inline '{"dateFrom":"2025-04-01","dateTo":"2025-04-30","creativeIDs":[444555666,444555667]}'
```

AI сортирует по `ctr` asc, рекомендует отключить креативы с CTR < 0.3% или нулевыми кликами.

### Сценарий 3 — Подключение нового рекламодателя для ОРД

```bash
# 1. Создать рекламодателя
python3 scripts/cli.py POST /v1/account/{accountID}/create-advertiser --body-inline '{
  "shortName": "ООО Клиент",
  "longName": "Общество с ограниченной ответственностью Клиент",
  "inn": "7712345678",
  "ogrn": "1177746000000",
  "kpp": "771701001",
  "legalAddress": "г. Москва, ул. ...",
  "actualAddress": "г. Москва, ул. ...",
  "legalType": "ul",
  "legalRole": "rd"
}'
# → { "id": 987654321 }

# 2. Создать сервисный договор
python3 scripts/cli.py POST /v1/account/{accountID}/create-contract --body-inline '{
  "advertiserId": 987654321,
  "type": "service",
  "subject": "distribution",
  "description": "direct_with_advertiser",
  "isReportingRequired": true,
  "date": "2025-01-15",
  "number": "ДА-2025/01",
  "intermediary": {
    "shortName": "ООО Исполнитель",
    "longName": "Общество с ограниченной ответственностью Исполнитель",
    "inn": "7798765432",
    "ogrn": "1177746999999",
    "kpp": "779801001",
    "legalAddress": "г. Москва, ул. Исполнителя, д. 1",
    "actualAddress": "г. Москва, ул. Исполнителя, д. 1",
    "legalType": "ul"
  }
}'
# → { "id": 1122334455 }
```

⚠️ **Field `intermediary` обязателен** для всех типов договоров когда не передан `parentId` — даже для `type: "service"`. Это поведение подтверждено sandbox-тестом, но в публичной документации не описано явно.

Подробности по типам договоров и обязательным полям — в `references/ord.md`.

### Сценарий 4 — Управление балансами агентства

```bash
# Балансы по всем дочкам в одном вызове
bash scripts/list-children.sh | jq '.children[] | {name: .account.shortName, balance: .balance.balance, bonus: .balance.bonusBalance}'

# Перевод 1000₽ с родителя на дочку 998186750
python3 scripts/cli.py POST /v1/account/{accountID}/funds-transfer --body-inline '{
  "accountIdTo": 998186750,
  "amount": 1000
}'
```

⚠️ **Направление перевода:** `accountID` в path — кто отправляет, `accountIdTo` — кто получает. Для перевода с дочки на родителя нужен токен дочки.

### Сценарий 5 — Подъём бюджета группы

```bash
bash scripts/change-group-budget.sh 987654321 5000   # установить бюджет в 5000₽
bash scripts/change-group-price.sh  987654321 25    # установить ставку 25₽ (CPC или CPM по модели кампании)
```

⚠️ Работает **только для групп с ручным управлением ставкой.** Группы с автостратегиями (target_cpa и т.п.) через API менять нельзя — только UI.

---

## БЕЗОПАСНОСТЬ

- ❌ **Никогда не передавай `client_secret` / `access_token` через CLI-флаги** — они уходят в shell history. Только через `.env` или `secrets/`.
- ❌ **Не присылай пользователю «дай client_secret в чат»** — пользователь сам кладёт через мастер в `config/.env`.
- ❌ Не делай скрин с access_token и не копируй его в TG/чат.
- ❌ Не показывай содержимое `config/.env` / `~/.claude/secrets/avito-ads-tokens` в выводе.
- ✅ Все секреты — `chmod 600`, в `config/.env` и `~/.claude/secrets/avito-ads-tokens`.
- ✅ Если access_token не получается (401 после refresh) — попроси пользователя перезапустить `avito-ads-launch-wizard.sh` и перевыпустить ключи в кабинете.
- ✅ Балл API расходуется на каждый запрос — следи за заголовком `Api-Point-Balance` в выводе. Не флуди.

---

## ИЗВЕСТНЫЕ ОГРАНИЧЕНИЯ AVITO РЕКЛАМА API v1

- **Создание кампаний / групп / креативов через API НЕЛЬЗЯ** — только UI кабинета. API даёт CRUD только на чтение + change-budget/price групп.
- **Автостратегии не управляются** — change-budget/change-price работают только для групп с ручной ставкой.
- **Максимальный период статистики** — 100 дней между `dateFrom` и `dateTo`.
- **Песочница: 1 тестовый аккаунт в сутки**, живёт до 00:00 текущего дня. Дочерние аккаунты в sandbox создавать можно, но токены для них использовать нельзя.
- **API-баллы** — у каждого метода своя стоимость в баллах (см. `x-cost` в Swagger или заголовок `Api-Point-Balance` в ответе). 10 000 баллов в кабинете — это не «10 000 запросов».
- **Все денежные значения** — целые числа в рублях **с НДС**.
- **`{accountID}` обязателен в каждом URL** — даже на ручках с одним аккаунтом.
- **Ключи привязаны к одному accountID** — для доступа к дочернему аккаунту нужно выпускать ключи в нём отдельно.

---

## ССЫЛКИ

- API спецификация (Swagger 3.0): https://developers.avito.ru/api-catalog/ads/documentation
- Каталог всех API Avito: https://developers.avito.ru/api-catalog
- Кабинет: https://ads.avito.ru
- Этот скилл: https://github.com/atomachinskiy/claude-skill-avito-ads

---

**Версия:** 0.1
**Обновлено:** 2026-05-28
