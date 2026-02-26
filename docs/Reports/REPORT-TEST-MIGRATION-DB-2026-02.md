# Отчёт тестовой миграции БД: Supabase Cloud → Pigsty (GD-lounge, imperial)

**Дата:** февраль 2026  
**Цель:** зафиксировать результат первого прогона экспорта и восстановления БД GD-lounge и imperial на Pigsty (gdloungedb, imperialdb) и любые ошибки/обходы.

Команды и порядок: [MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md](../MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md) §3 (Supabase CLI) или §4 (pg_dump/pg_restore).

---

## 1. Подготовка

- [ ] БД на Pigsty созданы: `./pgsql.yml -l pg-meta` (gdloungedb, imperialdb в pigsty.yml).
- [ ] Переменные в `supabase-credentials.env`: SUPABASE_GDLOUNGE_REF, SUPABASE_GDLOUNGE_PASSWORD, SUPABASE_IMPERIAL_REF, SUPABASE_IMPERIAL_PASSWORD, PIGSTY_POSTGRES_PASSWORD (для восстановления).
- [ ] При необходимости: Session pooler host для IPv4 (SUPABASE_GDLOUNGE_POOLER_HOST и т.д.) — если прямой хост Supabase недоступен.

---

## 2. Экспорт

| Проект   | Способ (CLI / pg_dump) | Файлы / дамп | Ошибки |
|----------|-------------------------|--------------|--------|
| GD-lounge |                         |              |        |
| imperial  |                         |              |        |

При ошибках (таймаут, IPv6, и т.д.) — использовать Session pooler URL вместо db.REF.supabase.com.

---

## 3. Правки в schema.sql (оба проекта)

- Заменить `OWNER TO "supabase_admin"` на `OWNER TO postgres`.
- Закомментировать или удалить: `CREATE EXTENSION pg_graphql`, `CREATE EXTENSION supabase_vault`.

Выполнено: [ ] GD-lounge  [ ] imperial. Ошибки при правках: _

---

## 4. Восстановление на Pigsty

Порядок: roles → schema → data для каждой БД.

| БД          | roles.sql | schema.sql | data.sql | Замечания |
|-------------|-----------|------------|----------|-----------|
| gdloungedb  |           |            |          |           |
| imperialdb  |           |            |          |           |

Типичные ошибки: отсутствующие роли (supabase_admin и др.), расширения — см. [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](../MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md) §8.

---

## 5. После восстановления

- [ ] Расширения: в каждой БД выполнить при необходимости `CREATE EXTENSION IF NOT EXISTS pgcrypto;`, `CREATE EXTENSION IF NOT EXISTS uuid_ossp;`.
- [ ] RLS: проверить политики и права ролей (anon, authenticated при использовании PostgREST).
- [ ] Подключение с приложения: проверить доступ к gdloungedb и imperialdb через PgBouncer (6432) с пользователем из pigsty.yml.

---

## 6. Итог

| Критерий        | Результат |
|-----------------|-----------|
| Экспорт обеих БД | OK / с ошибками |
| Восстановление  | OK / с ошибками |
| Расширения/RLS  | OK / требуется доработка |

Дополнительные замечания и обходы (если были): _

---

## 7. Связанные документы

- [MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md](../MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md) — команды экспорта и восстановления.
- [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](../MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md) — полная инструкция и типовые проблемы §8.
- [TEST-MIGRATION-INVENTORY.md](../TEST-MIGRATION-INVENTORY.md) — инвентаризация сервисов по проектам.
