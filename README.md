# claude-skill-avito-ads

Claude Code skill для работы с **публичным API Авито Реклама** (`api.avito.ru/ads/v1`) — это DSP-кабинет Авито для performance-рекламы (CPM/CPC баннеры, HTML, видео).

Покрывает чтение (аккаунт, рекламодатели, договоры, кампании, группы, креативы, статистика с дневной гранулярностью до 100 дней) и доступную в API запись (изменение бюджета и ставки групп с ручным управлением, переводы между родительским и дочерним аккаунтами, ОРД-цикл — создание рекламодателей и договоров, управление пользователями).

> **Не путать с classifieds API Avito** (объявления, мессенджер, продвижение, авито.работа и т.д.) — там отдельный набор эндпоинтов на том же `api.avito.ru`. Этот скилл закрывает только новый DSP-кабинет «Авито Реклама».

## Установка

### macOS / Linux

```bash
git clone https://github.com/atomachinskiy/claude-skill-avito-ads.git ~/.claude/skills/avito-ads
chmod +x ~/.claude/skills/avito-ads/scripts/*.sh
bash ~/.claude/skills/avito-ads/scripts/avito-ads-launch-wizard.sh
```

Откроется отдельное окно терминала с интерактивным мастером — он попросит `client_id`, `client_secret`, `accountID` и режим (sandbox/prod). После заполнения получит токен и сохранит всё в `config/.env` (chmod 600) и `~/.claude/secrets/avito-ads-tokens` (chmod 600).

### Windows

```powershell
git clone https://github.com/atomachinskiy/claude-skill-avito-ads.git $env:USERPROFILE\.claude\skills\avito-ads
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\avito-ads\scripts\avito-ads-launch-wizard.ps1"
```

### Получение ключей

1. https://ads.avito.ru/cabinet — нужна роль **Администратор**
2. Аккаунт → API → «Создать ключ»
3. Скопируй `client_id` и `client_secret` (показывается один раз — сохрани в надёжном месте)
4. Запомни `accountID` — числовой ID кабинета (виден в UI и URL)

⚠️ Под каждый кабинет — свои ключи. Если работаешь с дочерним аккаунтом, выпускай ключи внутри него отдельно.

### Sanity-check

После установки в чате с Клодом скажи:

```
покажи баланс моего avito реклама кабинета
```

Клод вызовет `bash ~/.claude/skills/avito-ads/scripts/balance.sh` и вернёт `{ balance: ..., bonusBalance: ... }`.

## Зависимости

- `bash`, `curl`, `jq`, `python3` (Python ≥ 3.8)

На macOS: `brew install jq`. На Linux: `apt install jq` / `dnf install jq`. На Windows: используй Git Bash + Python с python.org (jq не обязателен — Python-CLI работает напрямую).

## Архитектура

- **Auth flow:** OAuth 2.0 client_credentials. `client_id + client_secret → access_token (24h TTL)`. Refresh-токена нет — при истечении просто перевыпускается через client_credentials заново. Токены в `~/.claude/secrets/avito-ads-tokens` (chmod 600). `cli.py` делает auto-refresh при 401.
- **Universal CLI:** `cli.py` принимает любой HTTP method + path + params + body → возвращает JSON. Плейсхолдер `{accountID}` в path подставляется автоматически из `.env`.
- **Тонкие обёртки:** `list-campaigns.sh`, `balance.sh`, `change-group-budget.sh` и др. — для частых сценариев. AI вызывает их напрямую без раздумий над форматом body.
- **Песочница по умолчанию:** `AVITO_ADS_MODE=sandbox` — запросы не тратят API-баллы. Когда готов — поменяй на `prod` в `.env`.
- **Безопасность:** `client_secret` никогда не передаётся через CLI-флаги, только через `config/.env`. Токены не попадают в shell history.

## Готовые сценарии

- «Покажи активные кампании в Avito Реклама»
- «Сколько потрачено за последний месяц по всем активным кампаниям»
- «Сравни CPM/CTR кампаний за неделю»
- «Найди креативы с CTR < 0.5% — кандидаты на отключение»
- «Подними бюджет группы 12345 до 5000»
- «Снизь CPC группы 67890 до 15₽»
- «Покажи балансы по всем дочерним аккаунтам»
- «Создай рекламодателя ООО X с ИНН Y» (для ОРД)
- «Заведи сервисный договор на рекламодателя 987654321»
- «Переведи 5000₽ с родителя на дочку 998186750»

См. полный каталог триггеров в `SKILL.md`.

## Ограничения Avito Реклама API v1

- **Создание кампаний / групп / креативов через API нельзя** — только UI кабинета. API даёт только чтение + change-budget/change-price групп.
- **Автостратегии не управляются** — change-budget/change-price работают только для групп с ручной ставкой.
- **Максимальный период статистики** — 100 дней между `dateFrom` и `dateTo`.
- **Песочница: 1 тестовый аккаунт в сутки**, живёт до 00:00 UTC. Дочерние аккаунты в sandbox создавать можно, но токены для них использовать нельзя.
- **API-баллы** — каждый запрос расходует баллы из баланса кабинета (10 000 на старте, у каждого метода своя стоимость; см. заголовок `Api-Point-Balance` в ответе).
- **Денежные значения** — целые рубли с НДС, не копейки.
- **`{accountID}` обязателен в каждом URL** — даже на ручках с одним аккаунтом.
- **Ключи привязаны к одному accountID** — для доступа к дочернему аккаунту выпускай ключи в нём отдельно.

## Ссылки

- **API спецификация (Swagger 3.0):** https://developers.avito.ru/api-catalog/ads/documentation
- **Каталог всех API Avito:** https://developers.avito.ru/api-catalog
- **Кабинет Авито Реклама:** https://ads.avito.ru
- **Этот скилл:** https://github.com/atomachinskiy/claude-skill-avito-ads

## Лицензия

MIT.

## Backlog

- [ ] Когда Avito выпустит создание кампаний/групп/креативов через API — добавить `create-campaign.sh` и шаблоны JSON
- [ ] Поддержка автостратегий в change-budget/price (ждём документации)
- [ ] Wrapper для exports в Google Sheets (как в vk-ads — `fill-monthly-report.py`)
- [ ] Поддержка multi-account через профили в config (для агентств с >5 кабинетов)
