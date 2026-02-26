# Проверка Pigsty 104.223.25.234 (24.02.2026)

**Повод:** проверка перед тестовой миграцией Supabase (GD-lounge, imperial).

---

## Результаты проверки

| Проверка | Результат |
|----------|-----------|
| SSH (st@104.223.25.234) | OK |
| Порт 5432 (PostgreSQL) | Слушается |
| Порт 6432 (PgBouncer) | Слушается |
| MinIO (9000) | HTTP 200 |
| Patroni | active (running) |
| Подключение к Postgres | **FATAL: the database system is shutting down** |
| БД gdloungedb, imperialdb | **Отсутствуют** (не созданы) |

---

## Причина

По выводу `patronictl list` узел **pg-meta-1** в роли **Replica**, состояние **starting**, тег **clonefrom: true**. Кластер развёрнут как реплика (ожидается primary для клонирования), в одноподной конфигурации primary нет, поэтому узел бесконечно остаётся в «starting» и не принимает подключения.

---

## Что сделать на сервере

1. **Перевести единственный узел в primary.** Варианты (выполнять с доступом к серверу):
   - По документации Pigsty: переинициализация кластера или смена роли (single-node primary). См. [Pigsty — Patroni](https://pigsty.io/docs/pgsql/patroni/).
   - Вручную (осторожно): остановить Patroni, в каталоге данных Postgres выполнить `pg_ctl promote` (или удалить `standby.signal`), запустить Patroni снова — узел должен занять lock как primary.
   - Либо заново развернуть кластер как single-node primary (без clonefrom), если в вашей версии Pigsty это делается через конфиг/плейбук.

2. **После того как Postgres начнёт принимать подключения**, создать БД:
   ```bash
   cd ~/pigsty
   ./pgsql-db.yml -l pg-meta -e dbname=gdloungedb
   ./pgsql-db.yml -l pg-meta -e dbname=imperialdb
   ```
   Либо выполнить скрипт `scripts/ensure_migration_dbs.sh` (см. [MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md](../MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md)).

3. **Проверить:** `sudo -u postgres psql -d postgres -t -c "SELECT datname FROM pg_database WHERE datname IN ('gdloungedb','imperialdb');"` — должны вернуться обе базы.

---

## Связанные документы

- [MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md](../MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md) — создание БД и миграция.
- [scripts/check_pigsty_before_migration.ps1](../../scripts/check_pigsty_before_migration.ps1) — локальная проверка перед миграцией.
