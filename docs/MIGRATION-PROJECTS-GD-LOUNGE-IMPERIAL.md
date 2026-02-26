# Миграция двух проектов: GD-lounge и imperial

Сводка по инвентаризации и целевые БД на Pigsty для переноса **GD-lounge** и **imperial** с Supabase Cloud.

---

## 1. Соответствие проектов и БД на Pigsty

| Supabase Cloud   | БД на Pigsty   |
|------------------|----------------|
| **GD-lounge**    | `gdloungedb`   |
| **imperial**     | `imperialdb`  |

В `pigsty.yml` обе БД уже добавлены в `pg_databases` кластера `pg-meta`. Создание: `./pgsql.yml -l pg-meta`.

**Проверка сервера перед миграцией:** запустите `scripts/check_pigsty_before_migration.ps1` (загружает `supabase-credentials.env`). Скрипт проверяет доступ по SSH, порты 5432/6432, MinIO и наличие БД. Если `gdloungedb` и `imperialdb` отсутствуют — на сервере выполните создание БД (см. ниже).

**Создание БД на сервере (когда PostgreSQL уже в состоянии running):**
```bash
ssh st@104.223.25.234
cd ~/pigsty
./pgsql-db.yml -l pg-meta -e dbname=gdloungedb
./pgsql-db.yml -l pg-meta -e dbname=imperialdb
```
Если плейбук падает с «database system is shutting down», дождитесь стабилизации кластера (например `patronictl list`) и повторите. Альтернатива — скрипт `scripts/ensure_migration_dbs.sh`: скопировать на сервер и выполнить `sudo -u postgres bash -s < ensure_migration_dbs.sh` после того, как подключение к Postgres успешно.

**Пароль Supabase с символом `$`:** в connection string пароль с `$` нужно заключать в одинарные кавычки (bash) или экранировать/задавать через переменную окружения, чтобы shell не интерпретировал `$`.

---

## 2. Сводка по инвентаризации

### 2.1 GD-lounge

| Параметр        | Значение |
|-----------------|----------|
| Размер БД       | 12 MB   |
| Postgres        | 17.6    |
| Auth users      | 0       |

**Расширения (исключить при восстановлении на Pigsty):** pg_graphql, supabase_vault. Остальные: pg_stat_statements, pgcrypto, uuid-ossp — при необходимости включить в БД.

**Таблицы public (бизнес-данные):** news (472 kB), leads (64 kB), gallery, menu_items, menu_categories, events (по 32 kB).

**RLS в public:** события, галерея, лиды, меню, новости — политики на SELECT/INSERT для public или authenticated.

**Storage:** 1 бакет `assets` (public), 112 объектов, ~180 MB. Лимит файла 50 MB, MIME image/*, video/*.

**Realtime:** публикация `supabase_realtime`. Функции и триггеры в public: нет.

---

### 2.2 imperial

| Параметр        | Значение |
|-----------------|----------|
| Размер БД       | 17 MB   |
| Postgres        | 17.6    |
| Auth users      | 0       |

**Расширения:** те же, что у GD-lounge (pg_graphql, supabase_vault — исключить при восстановлении).

**Таблицы public (бизнес-данные):** products (1400 kB), furniture_items (624 kB), product_categories (312 kB), categories (232 kB), furniture_item_categories (184 kB), news (168 kB), events (144 kB), orders (128 kB), brand_collection_categories (128 kB), users (96 kB), furniture_categories, furniture_brands (80 kB), brand_collections (64 kB), order_items (48 kB), brands (40 kB), admin_users, refunds (32 kB), product_count_cache (16 kB).

**RLS в public:** в инвентаризации политики по public не перечислены (null) — проверить после переноса.

**Storage:** 5 бакетов (все public): `event-images`, `furniture-images`, `news-images`, `product-images`, `site-images`. Объекты: product-images 1240 (~134 MB), site-images 27 (~6 MB), news-images 5 (~7.7 MB), event-images 4 (~713 kB). Лимиты и MIME не заданы (null).

**Realtime:** публикация `supabase_realtime`.

**Функции в public:** refresh_product_count_cache, set_events_updated_at, update_updated_at_column.

**Триггеры:** events_updated_at → set_events_updated_at; furniture_items_updated_at, orders_updated_at, products_updated_at → update_updated_at_column.

---

## 3. Общие шаги миграции (Supabase CLI)

Для **каждого** проекта выполнить один и тот же порядок.

### 3.1 Экспорт (локально)

```bash
# GD-lounge
export SOURCE_URL="postgresql://postgres.GDLOUNGE_REF:PASSWORD@db.GDLOUNGE_REF.supabase.com:5432/postgres"
mkdir -p migration_gdlounge
supabase db dump --db-url "$SOURCE_URL" -f migration_gdlounge/roles.sql --role-only
supabase db dump --db-url "$SOURCE_URL" -f migration_gdlounge/schema.sql
supabase db dump --db-url "$SOURCE_URL" -f migration_gdlounge/data.sql --use-copy --data-only

# imperial
export SOURCE_URL="postgresql://postgres.IMPERIAL_REF:PASSWORD@db.IMPERIAL_REF.supabase.com:5432/postgres"
mkdir -p migration_imperial
supabase db dump --db-url "$SOURCE_URL" -f migration_imperial/roles.sql --role-only
supabase db dump --db-url "$SOURCE_URL" -f migration_imperial/schema.sql
supabase db dump --db-url "$SOURCE_URL" -f migration_imperial/data.sql --use-copy --data-only
```

Пароли и REF — из `supabase-credentials.env` (SUPABASE_GDLOUNGE_*, SUPABASE_IMPERIAL_*).

### 3.2 Правки в schema.sql (оба проекта)

- Заменить `OWNER TO "supabase_admin"` на `OWNER TO postgres`.
- Закомментировать или удалить строки с расширениями: pg_graphql, supabase_vault.

### 3.3 Восстановление на Pigsty

```bash
export TARGET_BASE="postgresql://postgres:PIGSTY_POSTGRES_PASSWORD@104.223.25.234:5432"

# GD-lounge → gdloungedb
psql "$TARGET_BASE/gdloungedb" -v ON_ERROR_STOP=1 -f migration_gdlounge/roles.sql
psql "$TARGET_BASE/gdloungedb" -v ON_ERROR_STOP=1 -f migration_gdlounge/schema.sql
psql "$TARGET_BASE/gdloungedb" -v ON_ERROR_STOP=1 -c 'SET session_replication_role = replica' -f migration_gdlounge/data.sql

# imperial → imperialdb
psql "$TARGET_BASE/imperialdb" -v ON_ERROR_STOP=1 -f migration_imperial/roles.sql
psql "$TARGET_BASE/imperialdb" -v ON_ERROR_STOP=1 -f migration_imperial/schema.sql
psql "$TARGET_BASE/imperialdb" -v ON_ERROR_STOP=1 -c 'SET session_replication_role = replica' -f migration_imperial/data.sql
```

### 3.4 После миграции

- Проверить расширения в каждой БД (pgcrypto, uuid-ossp при необходимости).
- Проверить RLS и права ролей (anon, authenticated при использовании PostgREST).
- **Storage:** файлы переносить отдельно по [STORAGE-MIGRATION-SUPABASE-TO-PIGSTY.md](./STORAGE-MIGRATION-SUPABASE-TO-PIGSTY.md): GD-lounge — бакет assets; imperial — бакеты event-images, furniture-images, news-images, product-images, site-images.

---

## 4. Миграция дампом (pg_dump / pg_restore)

Вариант с одним файлом на проект: экспорт через `pg_dump`, восстановление через `pg_restore` в `gdloungedb` и `imperialdb`.

### 4.1 Подготовка

1. БД на Pigsty уже созданы (`gdloungedb`, `imperialdb`) — при необходимости: `./pgsql.yml -l pg-meta`.
2. В `supabase-credentials.env` заполнены REF и пароль БД для обоих проектов; пароль postgres для Pigsty — для шага восстановления.
3. Установлены клиенты PostgreSQL (входят в набор `psql`, `pg_dump`, `pg_restore`).

### 4.2 Экспорт из Supabase (обе БД)

Подставьте в URL REF и пароль из `supabase-credentials.env`. Схемы `graphql_public` и `extensions` исключены (расширения Supabase-only).

**Важно:** с сервера Pigsty (или из IPv4-only сети) хост `db.REF.supabase.co` может быть недоступен (Supabase отдаёт IPv6). Используйте **Session pooler**: в Dashboard → Connect выберите Session pooler и возьмите хост вида `aws-0-<region>.pooler.supabase.com`; в URL подставьте его вместо `db.REF.supabase.co` (порт 5432, пользователь и пароль те же).

**Windows (PowerShell):**

```powershell
# Загрузить переменные из supabase-credentials.env (заполните файл перед запуском)
Get-Content supabase-credentials.env | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process') }
}

$refGd = $env:SUPABASE_GDLOUNGE_REF
$pwdGd = $env:SUPABASE_GDLOUNGE_PASSWORD
$refImp = $env:SUPABASE_IMPERIAL_REF
$pwdImp = $env:SUPABASE_IMPERIAL_PASSWORD

# GD-lounge
pg_dump "postgresql://postgres.${refGd}:${pwdGd}@db.${refGd}.supabase.co:5432/postgres" `
  --no-owner --no-privileges `
  --exclude-schema=graphql_public --exclude-schema=extensions `
  --format custom --file backup_gdlounge.dump

# imperial
pg_dump "postgresql://postgres.${refImp}:${pwdImp}@db.${refImp}.supabase.co:5432/postgres" `
  --no-owner --no-privileges `
  --exclude-schema=graphql_public --exclude-schema=extensions `
  --format custom --file backup_imperial.dump
```

**Linux/macOS (bash):**

```bash
set -a
source supabase-credentials.env 2>/dev/null || true
set +a

pg_dump "postgresql://postgres.${SUPABASE_GDLOUNGE_REF}:${SUPABASE_GDLOUNGE_PASSWORD}@db.${SUPABASE_GDLOUNGE_REF}.supabase.com:5432/postgres" \
  --no-owner --no-privileges \
  --exclude-schema=graphql_public --exclude-schema=extensions \
  --format custom --file backup_gdlounge.dump

pg_dump "postgresql://postgres.${SUPABASE_IMPERIAL_REF}:${SUPABASE_IMPERIAL_PASSWORD}@db.${SUPABASE_IMPERIAL_REF}.supabase.com:5432/postgres" \
  --no-owner --no-privileges \
  --exclude-schema=graphql_public --exclude-schema=extensions \
  --format custom --file backup_imperial.dump
```

Если Supabase доступен только по IPv4, в URL замените хост на pooler (см. Dashboard → Connect → Session pooler).

### 4.3 Восстановление на Pigsty

Пароль postgres — из конфига Pigsty (`pg_admin_password` или ваш пароль суперпользователя). Хост: `104.223.25.234`, порт: `5432`.

**PowerShell:**

```powershell
$pigstyPwd = $env:PIGSTY_POSTGRES_PASSWORD   # задайте или добавьте в supabase-credentials.env
$target = "postgresql://postgres:${pigstyPwd}@104.223.25.234:5432"

pg_restore -h 104.223.25.234 -p 5432 -U postgres -d gdloungedb --no-owner --no-privileges backup_gdlounge.dump
pg_restore -h 104.223.25.234 -p 5432 -U postgres -d imperialdb --no-owner --no-privileges backup_imperial.dump
```

**bash:**

```bash
export PIGSTY_POSTGRES_PASSWORD="ваш_пароль_postgres"
pg_restore -h 104.223.25.234 -p 5432 -U postgres -d gdloungedb --no-owner --no-privileges backup_gdlounge.dump
pg_restore -h 104.223.25.234 -p 5432 -U postgres -d imperialdb --no-owner --no-privileges backup_imperial.dump
```

При ошибках про роли (например `supabase_admin`) можно игнорировать предупреждения или создать недостающие роли на Pigsty (см. [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](./MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md) §8).

### 4.4 Скрипт (опционально)

Готовый скрипт для экспорта и восстановления: `scripts/migrate_supabase_dump.ps1` (PowerShell). Заполните `supabase-credentials.env` и при необходимости добавьте в него `PIGSTY_POSTGRES_PASSWORD`, затем запустите скрипт из корня репозитория.

---

## 5. Связанные документы

- [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](./MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md) — полная инструкция по миграции, выбор способа экспорта, типовые правки.
- [SUPABASE-INVENTORY-MIGRATION.md](./SUPABASE-INVENTORY-MIGRATION.md) — инвентаризация перед миграцией (БД, Storage, Auth, add-ons).
- [STORAGE-MIGRATION-SUPABASE-TO-PIGSTY.md](./STORAGE-MIGRATION-SUPABASE-TO-PIGSTY.md) — перенос файлов Storage.
