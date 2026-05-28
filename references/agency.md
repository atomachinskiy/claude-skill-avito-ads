# Агентские сценарии (мультиаккаунт)

## Когда нужен мультиаккаунт

- Агентство ведёт нескольких клиентов
- Каждый клиент = отдельное ЮЛ/ИП
- Хочется единый родительский аккаунт + дочерние под каждого клиента
- Нужны переводы средств между ними

## Создание дочернего аккаунта

```bash
python3 scripts/cli.py POST /v1/account/{accountID}/create-nonpayer-child-account --body-inline '{
  "shortName": "Дочка ООО Клиент",
  "isSelfAdvertisingEnabled": false
}'
```

Поля:
- `shortName` — краткое имя дочернего аккаунта
- `isSelfAdvertisingEnabled` — можно ли в нём рекламировать родителя. Если рекламируется только клиент, ставь `false`

Ответ:
```json
{
  "accountID": 998186750,
  "clientKey": "abc123...",
  "clientSecret": "def456..."
}
```

⚠️ `clientKey`/`clientSecret` — это пара ключей для **выпуска отдельного токена дочернего аккаунта**. Сохрани их в `config/.env` отдельной копии скилла (если будешь работать с дочкой как с самостоятельным кабинетом). В песочнице эти ключи использовать нельзя.

## Просмотр дочерних аккаунтов

```bash
# Без балансов
bash scripts/list-children.sh plain

# С балансами (быстрый снапшот)
bash scripts/list-children.sh
```

Ответ с балансами:
```json
{
  "children": [
    {
      "account": { "id": 987654321, "shortName": "Дочерний аккаунт" },
      "balance": { "balance": 2500, "bonusBalance": 100 }
    }
  ]
}
```

У дочерних аккаунтов на одном договоре с родителем поле `contract` в ответе не передаётся.

## Перевод денег и бонусов

Логика направления одинакова для денег (`funds-transfer`) и бонусов (`bonus-transfer`):

- `accountID` в path — **аккаунт-источник** (с него списываются средства)
- `accountIdTo` в теле — **аккаунт-получатель**
- Перевод выполняется от имени аккаунта-источника, поэтому:
  - для перевода с родителя на дочку нужен **токен родителя**
  - для перевода с дочки на родителя нужен **токен дочки**
- `accountIdTo` должен указывать на связанный аккаунт (пара родитель/дочка)
- `amount` — целое число ≥1

| Сценарий | Метод | Чей токен |
|---|---|---|
| Родитель → дочка (деньги) | `POST /v1/account/{PARENT}/funds-transfer` | родителя |
| Дочка → родитель (деньги) | `POST /v1/account/{CHILD}/funds-transfer` | дочки |
| Родитель → дочка (бонусы) | `POST /v1/account/{PARENT}/bonus-transfer` | родителя |
| Дочка → родитель (бонусы) | `POST /v1/account/{CHILD}/bonus-transfer` | дочки |

Пример (родитель → дочка):
```bash
python3 scripts/cli.py POST /v1/account/{accountID}/funds-transfer --body-inline '{
  "accountIdTo": 987654321,
  "amount": 100
}'
```

Успешный ответ — пустой объект `{}`.

## End-to-end сценарий

```bash
# 1. Родитель → дочка: 100 ₽
python3 scripts/cli.py POST /v1/account/PARENT_ID/funds-transfer --body-inline '{
  "accountIdTo": CHILD_ID, "amount": 100
}'

# 2. Проверка балансов
bash scripts/list-children.sh

# 3. Дочка → родитель: вернуть 30 ₽ (нужен токен дочки — отдельный config/.env)
python3 scripts/cli.py POST /v1/account/CHILD_ID/funds-transfer --body-inline '{
  "accountIdTo": PARENT_ID, "amount": 30
}'
```

## Управление пользователями

Внутри одного аккаунта можно дать доступ нескольким пользователям с разными ролями:

```bash
# Список юзеров
bash scripts/list-users.sh

# Добавить
python3 scripts/cli.py POST /v1/account/{accountID}/add-user --body-inline '{
  "userId": 123456, "role": "admin"
}'

# Поменять роль
python3 scripts/cli.py POST /v1/account/{accountID}/set-user-role --body-inline '{
  "userId": 123456, "role": "viewer"
}'

# Удалить
python3 scripts/cli.py DELETE /v1/account/{accountID}/delete-user/123456
```

Роли:
- `admin` — полный доступ
- `viewer` — только чтение

## Best practices для агентств

- На каждого клиента — отдельный дочерний аккаунт + отдельные ключи (выпускаются внутри дочки, не у родителя)
- Если работаешь с >3 кабинетов через один скилл — заводи копии `config/.env` под каждый клиент. Например, `config/.env.client-X`, и подкладывай через `cp config/.env.client-X config/.env` перед запуском
- `bonus-transfer` отдельным эндпоинтом — не путай с funds-transfer. Бонусы в Avito — отдельная валюта
- Все денежные значения — целые рубли (не копейки)
- При переводе toggling `isSelfAdvertisingEnabled` дочки — мы решаем, может ли дочерний аккаунт рекламировать продукт родителя

## ОРД-цикл для агентства

Если рекламодатель ≠ аккаунт (дочка / посредник) — обязательно завести договор. См. `ord.md`.

Минимальный пакет для нового клиента в агентстве:
1. Создать рекламодателя (`create-advertiser`)
2. Создать договор (`create-contract`, type `service` или `intermediary`)
3. Если нужен отдельный кабинет для клиента — `create-nonpayer-child-account`
4. Залить туда стартовый бюджет (`funds-transfer`)
5. Внутри дочки выпустить отдельные ключи API
