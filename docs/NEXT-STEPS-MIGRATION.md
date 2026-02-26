# Дальнейшие шаги: тестовая миграция Supabase → Pigsty

БД **gdloungedb** и **imperialdb** на сервере созданы. Дальше — по плану тестовой миграции.

---

## Текущий статус (что уже сделано)

| Шаг | Статус |
|-----|--------|
| БД gdloungedb, imperialdb на сервере | ✅ Созданы, данные перенесены (pull_supabase_to_server.sh) |
| MinIO на сервере | ✅ Плейбук применён, бакеты и пользователи созданы |
| Storage Supabase → MinIO | ✅ Перенесено (gd-lounge-assets 115, imperial event/news/product) |
| Проверка перед копированием конфига | ✅ [CHECK-BEFORE-COPY-TO-SERVER.md](./CHECK-BEFORE-COPY-TO-SERVER.md) |

**Дальше:** подключение фронта к Pigsty и проверка работы.

---

## 0. Вариант: скачать данные прямо на сервер (один скрипт)

Скрипт **`scripts/pull_supabase_to_server.sh`** выполняет на сервере: экспорт из Supabase (pg_dump через Session pooler) и восстановление в gdloungedb/imperialdb.

**Шаги:**

1. Подготовить файл учётных данных **на сервере** (пароль с `$` задать в одинарных кавычках, иначе bash его обрежет):
   ```bash
   # На своей машине создать временный файл для сервера:
   # supabase-credentials.env с полями в кавычках для паролей, например:
   # SUPABASE_GDLOUNGE_PASSWORD='$sharkMan2026$'
   # SUPABASE_IMPERIAL_PASSWORD='$sharkMan2026$'
   ```
   Скопировать на сервер:  
   `scp supabase-credentials.env st@104.223.25.234:~/`

2. Скопировать скрипт и запустить на сервере:
   ```powershell
   scp scripts/pull_supabase_to_server.sh st@104.223.25.234:~/
   ssh st@104.223.25.234 "chmod +x ~/pull_supabase_to_server.sh && ~/pull_supabase_to_server.sh"
   ```
   Либо зайти по SSH и запустить: `./pull_supabase_to_server.sh` (файл `~/supabase-credentials.env` должен быть).

Дампы сохраняются на сервере в `~/migration_supabase/` (или в каталог из переменной `MIGRATION_WORKDIR`). Ошибки pg_restore про роли и расширения (pg_graphql, supabase_vault, schema extensions) можно игнорировать — данные в `public` восстанавливаются.

**Imperial:** если при экспорте imperial появляется «Tenant or user not found», у проекта другой Session pooler. В Dashboard → проект imperial → Connect → Session pooler скопируйте хост (например `aws-0-eu-central-1.pooler.supabase.com`) и добавьте в `supabase-credentials.env`: `SUPABASE_IMPERIAL_POOLER_HOST=этот_хост`. Затем снова запустите скрипт (или выполните вручную только дамп imperial и восстановление в imperialdb).

---

## 1. Экспорт из Supabase Cloud (вручную)

На машине, где установлен **Supabase CLI** и есть доступ к интернету (и к Supabase, и к 104.223.25.234 при необходимости):

1. Загрузите учётные данные (из корня репо):
   ```powershell
   Get-Content supabase-credentials.env | ForEach-Object {
     if ($_ -match '^\s*([^#][^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process') }
   }
   ```

2. **GD-lounge** — экспорт в папку `migration_gdlounge/`:
   ```bash
   mkdir -p migration_gdlounge
   # Используйте Session pooler, если прямой хост недоступен (IPv4):
   # HOST=aws-1-ap-south-1.pooler.supabase.com
   export SOURCE_URL="postgresql://postgres.${SUPABASE_GDLOUNGE_REF}:${SUPABASE_GDLOUNGE_PASSWORD}@db.${SUPABASE_GDLOUNGE_REF}.supabase.co:5432/postgres"
   # Или с pooler: ...@aws-1-ap-south-1.pooler.supabase.com:5432/postgres
   supabase db dump --db-url "$SOURCE_URL" -f migration_gdlounge/roles.sql --role-only
   supabase db dump --db-url "$SOURCE_URL" -f migration_gdlounge/schema.sql
   supabase db dump --db-url "$SOURCE_URL" -f migration_gdlounge/data.sql --use-copy --data-only
   ```
   Пароль с `$` в bash задавайте в одинарных кавычках или через переменную.

3. **imperial** — то же в `migration_imperial/` (подставьте IMPERIAL_REF и IMPERIAL_PASSWORD).

Подробно: [MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md](./MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md) §3.1.

---

## 2. Правки в schema.sql (оба проекта)

В каждом `migration_gdlounge/schema.sql` и `migration_imperial/schema.sql`:

- Заменить `OWNER TO "supabase_admin"` на `OWNER TO postgres`.
- Закомментировать или удалить строки с расширениями: `pg_graphql`, `supabase_vault`.

---

## 3. Восстановление на Pigsty

Пароль postgres — из `supabase-credentials.env` (`PIGSTY_POSTGRES_PASSWORD`). Хост: `104.223.25.234`, порт **5432** (напрямую к Postgres).

```bash
export TARGET_BASE="postgresql://postgres:PIGSTY_POSTGRES_PASSWORD@104.223.25.234:5432"

# GD-lounge
psql "$TARGET_BASE/gdloungedb" -v ON_ERROR_STOP=1 -f migration_gdlounge/roles.sql
psql "$TARGET_BASE/gdloungedb" -v ON_ERROR_STOP=1 -f migration_gdlounge/schema.sql
psql "$TARGET_BASE/gdloungedb" -v ON_ERROR_STOP=1 -c 'SET session_replication_role = replica' -f migration_gdlounge/data.sql

# imperial
psql "$TARGET_BASE/imperialdb" -v ON_ERROR_STOP=1 -f migration_imperial/roles.sql
psql "$TARGET_BASE/imperialdb" -v ON_ERROR_STOP=1 -f migration_imperial/schema.sql
psql "$TARGET_BASE/imperialdb" -v ON_ERROR_STOP=1 -c 'SET session_replication_role = replica' -f migration_imperial/data.sql
```

После восстановления: проверить расширения (pgcrypto, uuid-ossp), RLS и права. Зафиксировать результат в [Reports/REPORT-TEST-MIGRATION-DB-2026-02.md](./Reports/REPORT-TEST-MIGRATION-DB-2026-02.md).

---

## 4. Storage → MinIO

1. **Проверка перед копированием:** см. [CHECK-BEFORE-COPY-TO-SERVER.md](./CHECK-BEFORE-COPY-TO-SERVER.md). Если конфиг на сервере совпадает с репо — копировать не нужно.
2. На сервере применить MinIO (если ещё не применяли): выполнить `./minio.yml -l minio` в `~/pigsty` или запустить с локальной машины `.\scripts\run_minio_on_server.ps1` (см. раздел 4 в CHECK-BEFORE-COPY-TO-SERVER.md).
3. Перенести файлы из Supabase Cloud в MinIO скриптом из `scripts/storage-migration-minio/` — по одному бакету за запуск (см. [STORAGE-MIGRATION-SUPABASE-TO-MINIO.md](./STORAGE-MIGRATION-SUPABASE-TO-MINIO.md)).

---

## 5. Проверка фронтенда

- Настроить бэкенд (или API routes во фронте) на `DATABASE_URL_GDLOUNGE` и `DATABASE_URL_IMPERIAL` (хост 104.223.25.234, порт **6432** PgBouncer; пользователь/пароль — из `pigsty.yml` для этих БД или postgres).
- Проверить: загрузка списков (новости, продукты), при необходимости загрузку файлов через API в MinIO.
- Инструкция для фронта: [FRONTEND-AFTER-SUPABASE-CLOUD.md](./FRONTEND-AFTER-SUPABASE-CLOUD.md).

---

## Порядок (кратко)

| # | Шаг | Документ |
|---|-----|----------|
| 1 | Экспорт из Supabase (CLI): roles, schema, data для GD-lounge и imperial | [MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md](./MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md) §3.1 |
| 2 | Правки в schema.sql | §3.2 |
| 3 | Восстановление в gdloungedb и imperialdb | §3.3 |
| 4 | MinIO: плейбук + скрипт переноса файлов | [STORAGE-MIGRATION-SUPABASE-TO-MINIO.md](./STORAGE-MIGRATION-SUPABASE-TO-MINIO.md) |
| 5 | Проверка фронта, инструкция для разработчиков | [FRONTEND-AFTER-SUPABASE-CLOUD.md](./FRONTEND-AFTER-SUPABASE-CLOUD.md) |

Связанные документы: [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](./MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md), [TEST-MIGRATION-INVENTORY.md](./TEST-MIGRATION-INVENTORY.md).
