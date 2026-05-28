# Backlog

## Когда Avito расширит API

Из roadmap Avito (фев 2026): автобиддер, audience constructor, MMP-интеграция, brand lift — обещают развивать в 2026.

- [ ] Поддержка создания кампаний / групп / креативов через API (когда появится)
- [ ] Управление автостратегиями (когда появится)
- [ ] Audience constructor (когда появится)
- [ ] Brand lift метрики (когда появится)
- [ ] MMP интеграции (когда появится)

## Удобства

- [ ] Multi-account профили: `config/.env.client-X` + флаг `--profile X` в cli.py
- [ ] Google Sheets отчёт `fill-monthly-report.py` по образцу vk-ads
- [ ] Алерты в Slack/TG по падению CTR / росту spend / нулевым показам (опционально, для пользователей кто захочет)
- [ ] Bulk export всех кампаний с пагинацией → CSV
- [ ] Pre-flight checker: проверить что accountID имеет performance-договор перед попыткой создать договор
- [ ] Recipe `agency-onboard-client.sh`: рекламодатель + договор + дочка + начальный бюджет одной командой

## Проверки кода

- [ ] Юнит-тесты для cli.py (auth flow, retry on 401, mode switching)
- [ ] Интеграционные smoke-тесты на sandbox
- [ ] Lint shell-скриптов через shellcheck

## Документация

- [ ] Скриншоты UI кабинета → API → «Создать ключ»
- [ ] Видео-туториал установки (если будет спрос)
