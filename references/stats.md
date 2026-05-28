# Статистика Avito Реклама

Три эндпоинта статистики, все принимают одинаковый формат данных:

| Метод | Эндпоинт | Что возвращает |
|---|---|---|
| POST | `/v1/account/{accountID}/campaigns/{campaignID}/stats` | Кампания + агрегаты по группам и креативам |
| POST | `/v1/account/{accountID}/campaigns/{campaignID}/groups/stats` | Выбранные groupIDs |
| POST | `/v1/account/{accountID}/campaigns/{campaignID}/creatives/stats` | Выбранные creativeIDs |

## Тело запроса

```json
{
  "dateFrom": "2025-01-01",
  "dateTo":   "2025-01-31",
  "groupIDs":    [111222333, 111222334],   // только для groups/stats
  "creativeIDs": [444555666, 444555667]    // только для creatives/stats
}
```

**Ограничения:**
- `dateFrom` / `dateTo` — формат `YYYY-MM-DD`
- Максимальный период — **100 дней**. Для отчёта за год — режь на 4 куска
- Гранулярность в `data[]` — по дням
- `totalData` — агрегат за весь период

## Метрики (`StatsData`)

| Поле | Тип | Что |
|---|---|---|
| timestamp | string (date-time) | Дневная метка ISO 8601 |
| views | int | Показы |
| clicks | int | Клики |
| ctr | number | CTR (%) |
| spend | int | Потрачено денег (₽, целое) |
| spendBonus | int | Потрачено бонусов (₽, целое) |
| cpm | number | CPM (₽) |
| cpc | number | CPC (₽) |
| videoViews25 / 50 / 75 / 100 | int | Просмотры видео (для video-кампаний) |
| q25, q50, q75 | number | Доля просмотров на 25/50/75% |
| vtr | number | View-Through Rate, доля просмотров на 100% |

## Структура ответа (campaign stats)

```json
{
  "campaign": {
    "id": 987654321,
    "name": "Кампания 1",
    "paymentModel": "CPM",
    "campaignType": "textImage",
    "data": [ { "timestamp": "...", "views": 1000, ... } ],
    "totalData": { "views": 1000, "clicks": 50, "ctr": 5.0, "spend": 1500, ... }
  },
  "groups": [
    {
      "id": 111222333,
      "name": "Группа 1",
      "data": [],
      "totalData": { ... }
    }
  ],
  "creatives": [
    {
      "id": 444555666,
      "groupId": 111222333,
      "name": "Креатив 1",
      "data": [],
      "totalData": { ... }
    }
  ]
}
```

## Готовые сценарии

### Сводка по всем активным кампаниям за месяц

```bash
for cid in $(bash scripts/list-campaigns.sh active | jq '.campaigns[].id'); do
  bash scripts/stats-campaign.sh "$cid" 2025-04-01 2025-04-30 \
    | jq -c '{id: .campaign.id, name: .campaign.name, total: .campaign.totalData}'
done | jq -s '.'
```

### Просадка CTR за период

```bash
python3 scripts/cli.py POST /v1/account/{accountID}/campaigns/12345/stats \
  --body-inline '{"dateFrom":"2025-04-01","dateTo":"2025-04-30"}' \
  --pretty | jq '.campaign.data | map({d: .timestamp, ctr})'
```

### Топ креативов по CTR

```bash
python3 scripts/cli.py POST /v1/account/{accountID}/campaigns/12345/creatives/stats \
  --body-inline '{"dateFrom":"2025-04-01","dateTo":"2025-04-30","creativeIDs":[444555666,444555667,444555668]}' \
  | jq '.creatives | sort_by(-.totalData.ctr) | .[]'
```

### Видео-метрики

Для video-кампаний всегда смотри `videoViews25/50/75/100` + `vtr` — не только показы. Просмотр < 25% обычно говорит о слабом первом-секундном hook'е.

## Внимание

- Считай spend в рублях с НДС — все денежные значения целые
- В `data[]` может прийти пропуск дней с нулевой активностью — учитывай это при построении графиков
- Период > 100 дней режется на куски, потом склеивается на стороне клиента
