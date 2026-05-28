# Песочница Avito Реклама API

Песочница (`https://api.avito.ru/ads-sandbox/`) позволяет тестировать запросы без влияния на боевые данные и без расхода API-баллов.

## Как переключиться в sandbox

В `config/.env`:
```
AVITO_ADS_MODE=sandbox
```

Скрипты и `cli.py` сами выберут правильный префикс URL.

## Создание тестового аккаунта

В sandbox доступен метод `POST /v1/account/{accountID}` (в проде он недоступен — там аккаунт заводится через UI):

```bash
curl --request POST \
  --url https://api.avito.ru/ads-sandbox/v1/account/811469958 \
  --header 'Authorization: Bearer ВАШ_ТОКЕН' \
  --header 'Content-Type: application/json' \
  --data '{
    "inn": "123456789012",
    "shortName": "shortName",
    "longName": "longName",
    "ogrn": "123456789012345",
    "legalAddress": "legalAddress",
    "actualAddress": "actualAddress",
    "legalType": "ip",
    "contact": {
      "name": "name",
      "phone": "+78005553535"
    }
  }'
```

Ответ: `{ "accountID": 998186750 }` — это ID тестового аккаунта. Используй его дальше во всех запросах.

## Ограничения песочницы

- **Время жизни** тестового аккаунта — до 00:00 текущего дня (по UTC).
- **Лимит 1 тестовый аккаунт в сутки.**
- **Дочерние аккаунты создавать можно**, но **токены для них использовать нельзя** — sandbox-токены работают только с исходным родительским аккаунтом. Факт создания проверяется через `GET /v1/account/{accountID}/children`.

## Зачем sandbox

- Отладка интеграции без расхода API-баллов на проде
- Тестирование create-advertiser / create-contract без юр. последствий
- Тестирование funds-transfer / bonus-transfer
- Проверка кода до выхода на prod кабинет
