# ОРД-цикл для агентств (рекламодатели + договоры)

Если ты работаешь от агентства — Роскомнадзор требует ОРД-цикл: рекламодатели + договоры + ERID на креативах. На уровне Avito Реклама API закрываются первые два пункта.

## Когда заводить рекламодателя

Рекламодатель — это **ЮЛ/ИП от лица которого размещается реклама**. У одного аккаунта может быть несколько рекламодателей.

**Кейсы:**
- Аккаунт = ИП твоего агентства, реклама — клиента → нужен рекламодатель = клиент
- Аккаунт = твоё ООО, реклама — твоей продукции → рекламодатель не нужен (аккаунт сам себе рекламодатель)
- Аккаунт = агентство, клиентов 5 → 5 рекламодателей в одном аккаунте

## Создание рекламодателя

```bash
python3 scripts/cli.py POST /v1/account/{accountID}/create-advertiser --body-inline '{
  "shortName": "ООО Клиент",
  "longName": "Общество с ограниченной ответственностью Клиент",
  "inn": "7712345678",
  "ogrn": "1177746000000",
  "kpp": "771701001",
  "legalAddress": "г. Москва, ул. Клиентская, д. 1",
  "actualAddress": "г. Москва, ул. Клиентская, д. 1",
  "legalType": "ul",
  "legalRole": "rd"
}'
```

Поля:

| Поле | Тип | Обязательное | Описание |
|---|---|---|---|
| shortName, longName | string | да | Краткое и полное наименование |
| inn, ogrn | string | да | ИНН и ОГРН (для ИП — ОГРНИП) |
| kpp | string | нет | КПП (для ИП пусто) |
| legalAddress, actualAddress | string | да | Юр + фактический адрес |
| legalType | enum | да | `ul` (юр. лицо) / `ip` (ИП) |
| legalRole | enum | да | `rd` / `ra` / `rr` |

Роли:
- `rd` — рекламодатель (тот за чьи деньги размещается реклама)
- `ra` — рекламное агентство (промежуточное звено в цепочке)
- `rr` — рекламораспространитель (площадка / паблишер)

## Когда заводить договор

Договор нужен **только если рекламодатель и аккаунт — разные ЮЛ/ИП**. Если совпадают — договор не создавай.

## Типы договоров

### service — на оказание услуг

```json
{
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
}
```

Обязательные: `subject`, `description`, `isReportingRequired`, `date`, `number`, `intermediary` (если не передан `parentId`). Запрещено: `cid`.

**`subject` enum** (по результатам sandbox-тестов): `distribution`, `mediation`. Полный список — в Swagger 3.0 спецификации (https://developers.avito.ru/api-catalog/ads/documentation → «Скачать swagger»).

**`description` enum**: `direct_with_advertiser`, `advertiser_intermediary` и др. — см. Swagger.

⚠️ **Важно:** `intermediary` обязательно для всех типов договоров когда не передан `parentId`, **даже для type=service** (хотя в публичной документации это явно не описано). Это поведение подтверждено sandbox-тестом 2026-05-28.

### intermediary — посреднический

```json
{
  "advertiserId": 987654321,
  "type": "intermediary",
  "subject": "mediation",
  "object": "commercial",
  "description": "direct_with_advertiser",
  "isReportingRequired": true,
  "isFundsAllocationToPrincipal": false,
  "date": "2025-01-15",
  "number": "ДА-2025/01",
  "intermediary": {
    "shortName": "ООО Реклама",
    "longName": "Общество с ограниченной ответственностью Реклама",
    "inn": "7712345678",
    "ogrn": "1177746123456",
    "kpp": "771701001",
    "legalAddress": "г. Москва, ул. Примерная, д. 1",
    "actualAddress": "г. Москва, ул. Примерная, д. 1",
    "legalType": "ul"
  }
}
```

Обязательные: `subject`, `object`, `isReportingRequired`, `isFundsAllocationToPrincipal`, `date`, `number`, `intermediary` (если нет parentId). Запрещено: `cid`.

### external — внешний договор

```json
{
  "advertiserId": 987654321,
  "type": "external",
  "cid": "EXT-2024-001234",
  "subject": "representation",
  "object": "other",
  "description": "advertiser_intermediary",
  "isReportingRequired": false,
  "isFundsAllocationToPrincipal": false
}
```

Обязательное: `cid` (внешний идентификатор). Запрещено: `parentId`. Поля `date`/`number` необязательны.

### Дополнительное соглашение

К существующему договору — через `parentId`:

```json
{
  "advertiserId": 987654321,
  "type": "intermediary",
  "subject": "distribution",
  "object": "distribution",
  "description": "direct_with_advertiser",
  "isReportingRequired": true,
  "isFundsAllocationToPrincipal": true,
  "date": "2025-03-01",
  "number": "ДС-2025/03",
  "parentId": 1122334455
}
```

Поле `intermediary` передавать нельзя; `date`/`number` остаются обязательными (как и для любого договора с `type ≠ external`).

## Проверки при создании договора

- Если указан `advertiserId`, рекламодатель должен существовать
- Для аккаунта должен существовать **актуальный performance-договор с Авито**, иначе создание упадёт с ошибкой
- Поле `intermediary` обязательно, если не передан `parentId`; при наличии `parentId` передавать `intermediary` нельзя
- Родительский договор не может быть дополнительным соглашением
- Рекламодатель и посредник не должны совпадать по ИНН
- Аккаунт не может быть посредником, кроме случая `description = "direct_with_advertiser"`
- Доп. соглашение к performance-договору допустимо только если форма родительского договора — `application`

## Список договоров

```bash
bash scripts/list-contracts.sh
```

Фильтры (передаются в body):
- `ids` — array of int
- `numbers` — array of string
- `contractors` — фильтр по исполнителям (AdvertiserFilter)
- `clients` — фильтр по заказчикам (AdvertiserFilter)

## Что НЕ делает API

- Не выдаёт ERID креативам — это происходит при модерации в кабинете
- Не выгружает акты — у Avito Реклама нет публичных методов для актов / отчётов ОРД (есть только в основном Avito Pro API для классифайдов)
- Не отправляет в ЕРИР — Avito делает это сама как оператор рекламных данных
