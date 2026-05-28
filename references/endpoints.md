# Каталог эндпоинтов Avito Реклама API v1

База: `https://api.avito.ru/ads/v1/...` (prod) или `https://api.avito.ru/ads-sandbox/v1/...` (sandbox).

Все list-методы используют единый формат:
```json
{ "filter": { ... }, "limit": 20, "page": 1 }
```
- `filter` обязательное, может быть `{}` — тогда без фильтрации
- `limit`: 1–100, default 20
- `page`: ≥1, default 1
- В ответе всегда `total` + массив сущностей

## Аккаунты и балансы

| Метод | Эндпоинт | Что |
|---|---|---|
| GET  | `/v1/account/{accountID}` | Реквизиты аккаунта (ИНН, ОГРН, адрес, менеджер) |
| GET  | `/v1/account/{accountID}/balance` | `{ balance, bonusBalance }` (целые ₽) |
| POST | `/v1/account/{accountID}` | **Только sandbox.** Создать тестовый аккаунт. Тело: inn, shortName, longName, ogrn, legalAddress, actualAddress, legalType (ul/ip), contact |

## Дочерние аккаунты и переводы

| Метод | Эндпоинт | Что |
|---|---|---|
| GET  | `/v1/account/{accountID}/children` | Список дочерних аккаунтов |
| GET  | `/v1/account/{accountID}/children-with-balances` | Список с балансами |
| POST | `/v1/account/{accountID}/create-nonpayer-child-account` | Создать дочерний. Тело: `{ shortName, isSelfAdvertisingEnabled }`. Ответ: `{ accountID, clientKey, clientSecret }` |
| POST | `/v1/account/{accountID}/funds-transfer` | Перевод денег. Тело: `{ accountIdTo, amount }`. `accountID` в path = источник, `accountIdTo` = получатель |
| POST | `/v1/account/{accountID}/bonus-transfer` | Перевод бонусов. Тело: `{ accountIdTo, amount }`. Семантика как у funds-transfer |

**Правило направления:**
- Родитель → дочка: токен родителя, `accountID=PARENT_ID` в path
- Дочка → родитель: токен дочки, `accountID=CHILD_ID` в path

## Рекламодатели

| Метод | Эндпоинт | Что |
|---|---|---|
| POST | `/v1/account/{accountID}/create-advertiser` | Создать рекламодателя. Тело: shortName, longName, inn, ogrn, kpp (опц для ИП), legalAddress, actualAddress, legalType (ul/ip), legalRole (rd/ra/rr). Ответ: `{ id }` |
| POST | `/v1/account/{accountID}/advertisers` | Список рекламодателей с фильтрами по ids/inns/roles |

`legalRole` enum:
- `rd` — рекламодатель
- `ra` — рекламное агентство
- `rr` — рекламораспространитель

## Договоры

| Метод | Эндпоинт | Что |
|---|---|---|
| POST | `/v1/account/{accountID}/create-contract` | Создать договор или доп. соглашение |
| POST | `/v1/account/{accountID}/contracts` | Список договоров с фильтрами по ids/numbers/contractors/clients |

Типы договоров (`type`):
- `service` — на оказание услуг. Обязательные: subject, isReportingRequired, date, number. Запрещено: cid
- `intermediary` — посреднический. Обязательные: subject, object, isReportingRequired, isFundsAllocationToPrincipal, date, number. Запрещено: cid
- `external` — внешний. Обязательное: cid. Запрещено: parentId. Поля date/number необязательны

**Доп. соглашения** — указывается `parentId` (ID родительского договора). `intermediary` передавать нельзя. Поля date/number обязательны.

См. подробности — `ord.md`.

## Кампании

| Метод | Эндпоинт | Что |
|---|---|---|
| POST | `/v1/account/{accountID}/campaigns` | Список кампаний |

**Создание кампаний через API нельзя** — только UI кабинета.

Фильтры:
- `ids` — array of int
- `paymentModels` — `CPM` / `CPC`
- `campaignTypes` — `textImage` / `HTML` / `video`
- `statuses` — см. CampaignStatus в Swagger
- `managers` — array of int (manager IDs)
- `advertisers` — array of int (advertiser IDs)
- `contractIDs`, `additionalAgreementIDs` — array of int
- `createdAt` — `{ from, to }` (YYYY-MM-DD)
- `timeFrame` — `{ from, to }` диапазон размещения

## Группы

| Метод | Эндпоинт | Что |
|---|---|---|
| POST | `/v1/account/{accountID}/groups` | Список групп |
| POST | `/v1/account/{accountID}/group/{groupID}/change-budget` | Изменить бюджет. Тело: `{ budget }` (целое ≥1 ₽ с НДС) |
| POST | `/v1/account/{accountID}/group/{groupID}/change-price` | Изменить ставку. Тело: `{ price }` (целое ≥1 ₽ с НДС, CPC/CPM по модели кампании) |

⚠️ **change-budget/change-price работают только для групп с ручным управлением ставкой.** Группы с автостратегиями (target_cpa и т.п.) через API менять нельзя.

Фильтры:
- `ids`, `campaignIDs` — array of int
- `statuses` — см. GroupsStatus
- `paces` — скорости показа
- `managers`, `advertisers` — array of int
- `paymentModels` — `CPM` / `CPC`
- `timeFrame` — `{ from, to }`

## Креативы

| Метод | Эндпоинт | Что |
|---|---|---|
| POST | `/v1/account/{accountID}/creatives` | Список креативов |

**Создание креативов через API нельзя** — только UI кабинета.

Фильтры:
- `ids`, `groupIDs`, `campaignIDs` — array of int
- `paymentModels` — `CPM` / `CPC`
- `campaignTypes` — `textImage` / `HTML` / `video`
- `statuses` — см. CreativesStatus
- `managers`, `advertisers` — array of int
- `timeFrame` — `{ from, to }`

## Статистика

| Метод | Эндпоинт | Что |
|---|---|---|
| POST | `/v1/account/{accountID}/campaigns/{campaignID}/stats` | Статистика по кампании + агрегаты по её группам и креативам |
| POST | `/v1/account/{accountID}/campaigns/{campaignID}/groups/stats` | По выбранным groupIDs |
| POST | `/v1/account/{accountID}/campaigns/{campaignID}/creatives/stats` | По выбранным creativeIDs |

Тело:
```json
{ "dateFrom": "2025-01-01", "dateTo": "2025-01-31",
  "groupIDs":    [111222333],    // для groups/stats
  "creativeIDs": [444555666]     // для creatives/stats
}
```

**Ограничения:**
- Формат дат — `YYYY-MM-DD`
- Максимальный период — **100 дней**
- Гранулярность в `data[]` — по дням; `totalData` — агрегат за весь период

Метрики (`StatsData`):
- `timestamp` — ISO 8601 (дневной)
- `views`, `clicks`, `ctr`
- `spend`, `spendBonus` — потрачено денег / бонусов (₽)
- `cpm`, `cpc`
- Видео-метрики: `videoViews25`, `videoViews50`, `videoViews75`, `videoViews100`, `q25`, `q50`, `q75`, `vtr`

## Пользователи

| Метод | Эндпоинт | Что |
|---|---|---|
| GET    | `/v1/account/{accountID}/users` | Список пользователей с ролями |
| POST   | `/v1/account/{accountID}/add-user` | Добавить. Тело: `{ userId, role }` |
| POST   | `/v1/account/{accountID}/set-user-role` | Поменять роль |
| DELETE | `/v1/account/{accountID}/delete-user/{userID}` | Удалить |

Роли:
- `admin` — полный доступ ко всему
- `viewer` — только чтение
- (другие — см. Swagger)

## Заголовки ответов

- `Api-Point-Balance` — остаток API-баллов после выполнения запроса (у каждого метода своя стоимость, см. `x-cost` в Swagger)

## Pagination — как обходить страницы

```python
page, limit = 1, 100
while True:
    body = { "filter": {}, "limit": limit, "page": page }
    resp = api.post(f"/v1/account/{acc}/campaigns", json=body)
    campaigns = resp["campaigns"]
    if not campaigns:
        break
    yield from campaigns
    if page * limit >= resp["total"]:
        break
    page += 1
```
