# Миграция GD-Lounge с Supabase Cloud на Pigsty

Чеклист данных и шагов для переноса проекта **GD-Lounge** с Supabase на сервер Pigsty (104.223.25.234).

---

## 1. Какие данные нужны для переноса (проверить и собрать)

### 1.1 Доступ к Supabase (обязательно)

| Что | Где взять | Куда записать |
|-----|-----------|----------------|
| **Project ref** | Dashboard → Project Settings → General → Reference ID | `SUPABASE_GDLOUNGE_REF` в `supabase-credentials.env` |
| **Пароль БД** | Project Settings → Database → Reset password (если не помните) | `SUPABASE_GDLOUNGE_PASSWORD` в `supabase-credentials.env` |
| **Connection string (Direct)** | Project Settings → Database → Connection string → URI | Для экспорта: `postgresql://postgres.[REF]:[PASSWORD]@db.[REF].supabase.com:5432/postgres` |

Без этих данных экспорт БД невозможен.

### 1.2 Инвентаризация БД (один запуск SQL)

Запустите **один раз** по проекту GD-Lounge (подставьте свои REF и пароль):

```bash
# Из корня репозитория pigsty, после заполнения supabase-credentials.env:
source supabase-credentials.env
export SOURCE_DB_URL="postgresql://postgres.${SUPABASE_GDLOUNGE_REF}:${SUPABASE_GDLOUNGE_PASSWORD}@db.${SUPABASE_GDLOUNGE_REF}.supabase.com:5432/postgres"
psql "$SOURCE_DB_URL" -f sql/supabase_inventory.sql > docs/inventory_gdlounge.txt
```

**Что получится в `inventory_gdlounge.txt`:**

- Версия PostgreSQL, размер БД
- Расширения (extensions)
- Схемы и размер по схемам
- Таблицы (public, auth, storage, realtime) и их размеры
- Роли (не системные)
- Таблицы с RLS и политики
- Storage: бакеты и число объектов (если есть схема storage)
- Realtime: публикации (если есть)
- Функции и триггеры в public
- Количество пользователей в auth.users (если есть схема auth)

Файл можно передать для анализа (паролей в нём нет). Если схем `storage` или `auth` нет, часть запросов выдаст ошибку — остальной вывод будет.

Подробнее: [SUPABASE-INVENTORY-MIGRATION.md](./SUPABASE-INVENTORY-MIGRATION.md).

### 1.3 Что проверить вручную в Dashboard

| Раздел | Что записать |
|--------|----------------|
| **Storage** | Бакеты (имена, public/private), объём файлов, политики — нужны ли файлы для GD-Lounge и куда их переносить. |
| **Auth** | Провайдеры (Email, OAuth и т.д.), Site URL, Redirect URLs, кастомный SMTP — для воспроизведения на Pigsty или гибрида. |
| **Realtime** | Используется ли в приложении — какие таблицы/события. |
| **Edge Functions** | Список функций (Dashboard → Edge Functions или `supabase/functions/`) — чем заменить на Pigsty. |
| **API** | Project URL, anon key, service_role key — для переключения приложения на Pigsty (при полном self-host). |

---

## 2. Подготовка на Pigsty

### 2.1 Целевая БД

В `pigsty.yml` уже добавлена БД для GD-Lounge:

```yaml
- name: gdloungedb
  comment: "Миграция из Supabase Cloud — GD-Lounge"
```

Создать БД на сервере (один раз):

```bash
cd ~/pigsty
./pgsql.yml -l pg-meta
```

Либо вручную:

```bash
psql -h 104.223.25.234 -p 5432 -U postgres -d postgres -c "CREATE DATABASE gdloungedb OWNER postgres;"
```

### 2.2 Пользователь приложения (при необходимости)

Если приложению нужен отдельный пользователь БД — добавить в `pigsty.yml` в `pg_users` и применить плейбук. Строка подключения для приложения:

- Через PgBouncer: `postgresql://USER:PASSWORD@104.223.25.234:6432/gdloungedb`
- Напрямую: `postgresql://USER:PASSWORD@104.223.25.234:5432/gdloungedb`

---

## 3. Экспорт и восстановление

### 3.1 Экспорт из Supabase

```bash
export SOURCE_DB_URL="postgresql://postgres.[REF]:[PASSWORD]@db.[REF].supabase.com:5432/postgres"
# Вариант A — раздельные файлы (удобно править)
supabase db dump --db-url "$SOURCE_DB_URL" -f roles.sql --role-only
supabase db dump --db-url "$SOURCE_DB_URL" -f schema.sql
supabase db dump --db-url "$SOURCE_DB_URL" -f data.sql --use-copy --data-only

# Вариант B — один дамп (быстрее)
pg_dump "$SOURCE_DB_URL" --no-owner --no-privileges \
  --exclude-schema=graphql_public --exclude-schema=auth --exclude-schema=storage \
  --exclude-schema=realtime --exclude-schema=extensions \
  --format custom --file backup_gdlounge.dump
```

Список схем подправьте под проект (если нужны auth/storage — не исключайте их и готовьтеся к настройке контейнеров Supabase на Pigsty).

### 3.2 Восстановление на Pigsty

```bash
export TARGET_DB_URL="postgresql://postgres:ПАРОЛЬ_ПОСТГРЕС@104.223.25.234:5432/gdloungedb"

# Если использовали вариант A:
psql "$TARGET_DB_URL" --single-transaction -v ON_ERROR_STOP=1 -f roles.sql
psql "$TARGET_DB_URL" --single-transaction -v ON_ERROR_STOP=1 -f schema.sql
psql "$TARGET_DB_URL" --single-transaction -v ON_ERROR_STOP=1 -c 'SET session_replication_role = replica' -f data.sql

# Если вариант B:
pg_restore -h 104.223.25.234 -p 5432 -U postgres -d gdloungedb --no-owner --no-privileges backup_gdlounge.dump
```

Пароль Postgres — из Pigsty (`pg_admin_password` или суперпользователь кластера).

---

## 4. После миграции

- **Расширения:** включить в БД те же, что в Cloud (`CREATE EXTENSION IF NOT EXISTS ...`), кроме Supabase-only (pgsodium, pg_graphql, pg_net).
- **Права и RLS:** проверить политики и роли (anon, authenticated, service_role при использовании Supabase API на Pigsty).
- **Storage:** файлы переносятся отдельно — см. [STORAGE-MIGRATION-SUPABASE-TO-PIGSTY.md](./STORAGE-MIGRATION-SUPABASE-TO-PIGSTY.md).
- **Realtime:** при использовании — настроить logical replication и публикации; см. [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](./MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md) §8.3.

---

## 5. Краткий чеклист

- [ ] Взять в Supabase: Project ref, пароль БД, connection string.
- [ ] Записать в `supabase-credentials.env`: `SUPABASE_GDLOUNGE_REF`, `SUPABASE_GDLOUNGE_PASSWORD`.
- [ ] Запустить `sql/supabase_inventory.sql` → сохранить в `inventory_gdlounge.txt`.
- [ ] Проверить в Dashboard: Storage, Auth, Realtime, Edge Functions, API keys.
- [ ] Создать БД `gdloungedb` на Pigsty (`./pgsql.yml -l pg-meta` или вручную).
- [ ] Экспорт из Supabase (CLI или pg_dump).
- [ ] Восстановление в `gdloungedb` на 104.223.25.234.
- [ ] Расширения, права, RLS; при необходимости — Storage, Realtime.
- [ ] Переключить приложение GD-Lounge на Pigsty (connection string и/или API).

Подробная инструкция по миграции: [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](./MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md).
