# Инструкция: перенос Supabase Cloud на сервер Pigsty

Пошаговый план миграции проекта с Supabase Cloud на ваш сервер Pigsty (104.223.25.234).

---

## 1. Выбор стратегии

| Вариант | Описание | Когда использовать |
|--------|----------|--------------------|
| **Гибрид** | Auth (OAuth, сессии) остаётся в Supabase Cloud, **данные** (таблицы) — в Pigsty | Минимальные изменения во фронте, быстрый старт. Подробно: [PLAN.md](./PLAN.md) и [FRONTEND-INTEGRATION.md](./FRONTEND-INTEGRATION.md). |
| **Полная миграция** | Вся БД (схема + данные) переносится на Pigsty; Auth/Storage/Realtime — либо self-host (Supabase на Pigsty), либо замена | Полный контроль над данными и инфраструктурой. |

Ниже описана **полная миграция БД** (схема и данные). Гибрид — это подмножество: переносите только нужные таблицы/данные и подключаете фронт через свой API к Pigsty (см. [FRONTEND-INTEGRATION.md](./FRONTEND-INTEGRATION.md)).

### Миграция нескольких БД

Для **нескольких** проектов Supabase Cloud: одна целевая БД на Pigsty = один проект Cloud. Один и тот же процесс повторяется для каждой пары.

**Рекомендация по способу экспорта:**
- **Одна БД** — подойдут и Supabase CLI, и pg_dump.
- **Несколько БД** — предпочтительно **Supabase CLI**: один и тот же сценарий для всех проектов (три файла: roles, schema, data), текстовые файлы можно править при ошибках (владелец, расширения) и применять одни и те же правки ко всем, удобно автоматизировать циклом по списку проектов.

Порядок:

1. **Подготовка:** создать на Pigsty целевые БД для всех проектов в `pigsty.yml` (например `gd_lounge_prod`, `project2_prod`, …) — см. [§3.1](#31-создать-целевую-базу-данных). Применить `./pgsql.yml -l pg-meta`.
2. **Экспорт:** для каждого проекта взять connection string в Dashboard → Project Settings → Database и выполнить экспорт **через Supabase CLI** в отдельную папку (например `migration_gd_lounge/` → roles.sql, schema.sql, data.sql). Одни и те же три команды для каждого проекта.
3. **Правки (опционально):** в каждом `schema.sql` заменить `supabase_admin` на `postgres`, при необходимости закомментировать расширения Supabase-only (pg_graphql, supabase_vault) — см. [§5.2](#52-восстановление-способ-a--файлы-из-supabase-cli) и таблицу в §8.2.
4. **Восстановление:** для каждой БД один и тот же порядок: roles → schema → data по [§5.2](#52-восстановление-способ-a--файлы-из-supabase-cli).
5. **После миграции:** для каждой БД — расширения, права, RLS; при необходимости Storage и Realtime; переключение приложений ([§6](#6-после-миграции-бд), [§7](#7-переключение-приложений)).

Имена БД и пользователей задавайте в `pigsty.yml` в `pg_databases` и при необходимости в `pg_users` (см. пример в [§3](#3-подготовка-бд-на-pigsty)).

---

## 2. Что нужно перед началом

- **Pigsty** уже развёрнут на 104.223.25.234 (кластер `pg-meta`, PgBouncer на 6432).
- Доступ к **Supabase Cloud**: Project Settings → Database — знаете пароль БД или можете его сбросить.
- Установлен **Supabase CLI** (для рекомендуемого способа экспорта): [Getting Started](https://supabase.com/docs/guides/local-development/cli/getting-started).
- С машины, где будете запускать экспорт/импорт — сетевой доступ к Supabase Cloud и к 104.223.25.234 (порты 5432 или 6432).

---

## 3. Подготовка БД на Pigsty

### 3.1 Создать целевую базу данных

Один проект Cloud = одна БД на Pigsty (например `myapp_prod`).

**Через конфиг Pigsty** (рекомендуется): в `pigsty.yml` в секции `pg_databases` кластера `pg-meta` добавьте:

```yaml
- name: myapp_prod
  comment: "Миграция из Supabase Cloud: проект MyApp"
```

Затем на сервере (или с хоста с Ansible):

```bash
cd ~/pigsty
./pgsql.yml -l pg-meta
```

**Либо через SQL** (разово):

```bash
psql -h 104.223.25.234 -p 5432 -U postgres -d postgres -c "CREATE DATABASE myapp_prod OWNER postgres;"
```

### 3.2 Пользователь для приложения

Если ещё нет пользователя с доступом к этой БД — добавьте его в `pigsty.yml` в `pg_users` и примените плейбук пользователей, либо создайте вручную и выдайте права на БД `myapp_prod`. Строка подключения для приложения будет вида:

- Через PgBouncer: `postgresql://USER:PASSWORD@104.223.25.234:6432/myapp_prod`
- Напрямую к Postgres: `postgresql://USER:PASSWORD@104.223.25.234:5432/myapp_prod`

---

## 4. Экспорт из Supabase Cloud

### 4.0 Выбор способа экспорта

| Ситуация | Рекомендация |
|----------|----------------|
| **Одна БД** | Supabase CLI или pg_dump — по удобству. |
| **Несколько БД** | **Supabase CLI** — один и тот же сценарий для всех проектов (три файла на проект), правка текстовых SQL при ошибках, легко скриптовать цикл по списку проектов. |

### 4.1 Параметры подключения к Cloud

1. В [Dashboard](https://supabase.com/dashboard) проекта: **Project Settings → Database**.
2. При необходимости сбросьте пароль БД.
3. Возьмите **connection string**:
   - **Direct** (предпочтительно для дампа):  
     `postgresql://postgres.[PROJECT-REF]:[PASSWORD]@db.[PROJECT-REF].supabase.com:5432/postgres`
   - **Session pooler**:  
     `postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-<region>.pooler.supabase.com:5432/postgres`

Сохраните строку в переменную (локально, не коммитить):

```bash
export SOURCE_DB_URL="postgresql://postgres.XXXXX:YOUR_PASSWORD@db.XXXXX.supabase.com:5432/postgres"
```

### 4.2 Способ A: экспорт через Supabase CLI (рекомендуется)

Раздельный дамп ролей, схемы и данных — удобно править при конфликтах.

```bash
supabase db dump --db-url "$SOURCE_DB_URL" -f roles.sql --role-only
supabase db dump --db-url "$SOURCE_DB_URL" -f schema.sql
supabase db dump --db-url "$SOURCE_DB_URL" -f data.sql --use-copy --data-only
```

Опционально — история миграций Supabase:

```bash
supabase db dump --db-url "$SOURCE_DB_URL" -f history_schema.sql --schema supabase_migrations
supabase db dump --db-url "$SOURCE_DB_URL" -f history_data.sql --use-copy --data-only --schema supabase_migrations
```

### 4.3 Способ B: экспорт через pg_dump

Один файл — быстрее, но меньше гибкости при восстановлении.

```bash
pg_dump "$SOURCE_DB_URL" \
  --no-owner --no-privileges \
  --format custom --file backup_myapp.dump
```

Чтобы не тащить служебные схемы Cloud (auth, storage, realtime и т.д.), можно исключить их:

```bash
pg_dump "$SOURCE_DB_URL" \
  --no-owner --no-privileges \
  --exclude-schema=graphql_public --exclude-schema=auth --exclude-schema=storage \
  --exclude-schema=realtime --exclude-schema=extensions \
  --format custom --file backup_myapp.dump
```

Список схем/расширений подправьте под свой проект (например, оставить только `public` и нужные вам схемы).

---

## 5. Восстановление на Pigsty

### 5.1 Строка подключения к целевой БД

```bash
export TARGET_DB_URL="postgresql://postgres:ПАРОЛЬ_ПОСТГРЕС@104.223.25.234:5432/myapp_prod"
```

Пароль `postgres` — из конфига Pigsty (`pg_admin_password` или пароль суперпользователя кластера).

### 5.2 Восстановление (способ A — файлы из Supabase CLI)

Порядок важен: сначала роли, потом схема, потом данные.

```bash
psql "$TARGET_DB_URL" --single-transaction --variable ON_ERROR_STOP=1 -f roles.sql
psql "$TARGET_DB_URL" --single-transaction --variable ON_ERROR_STOP=1 -f schema.sql
psql "$TARGET_DB_URL" --single-transaction --variable ON_ERROR_STOP=1 -c 'SET session_replication_role = replica' -f data.sql
```

Если появляются ошибки про `supabase_admin` или отсутствующие роли — отредактируйте `schema.sql`/`roles.sql`: закомментируйте или замените владельца на `postgres`. Кастомным ролям с `login` после восстановления задайте пароли вручную.

**Типовые правки в schema.sql перед восстановлением (для всех проектов можно применять одинаково):**
- Заменить `OWNER TO "supabase_admin"` на `OWNER TO postgres` (или своего владельца).
- Закомментировать или удалить строки с расширениями, которых нет на Pigsty: `pg_graphql`, `supabase_vault`, при необходимости `pgsodium`, `pg_net` (см. §8.2).

Историю миграций (если выгружали) восстановите отдельно:

```bash
psql "$TARGET_DB_URL" --single-transaction --variable ON_ERROR_STOP=1 -f history_schema.sql -f history_data.sql
```

### 5.3 Восстановление (способ B — custom dump)

```bash
pg_restore -h 104.223.25.234 -p 5432 -U postgres -d myapp_prod --no-owner --no-privileges backup_myapp.dump
```

При ошибках (роли, расширения) правим дамп или окружение и повторяем.

---

## 6. После миграции БД

- **Расширения:** в целевой БД на Pigsty включите те же расширения, что были в Cloud (`CREATE EXTENSION IF NOT EXISTS ...`). В конфиге Pigsty для кластера уже могут быть указаны postgis, pgvector и др.
- **Права и RLS:** проверьте политики RLS и права ролей (anon, authenticated, service_role при использовании Supabase API на Pigsty).
- **Realtime:** если использовали Realtime в Cloud, на Pigsty нужен `wal_level = logical` и настройка публикаций; см. [SUPABASE-STUDIO-PIGSTY.md](./SUPABASE-STUDIO-PIGSTY.md) (раздел 3).
- **Storage:** файлы в Supabase Storage дампом БД не переносятся. Объекты нужно копировать отдельно по инструкции [STORAGE-MIGRATION-SUPABASE-TO-PIGSTY.md](./STORAGE-MIGRATION-SUPABASE-TO-PIGSTY.md) или см. [Backup and Restore — Migrate storage objects](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).

---

## 7. Переключение приложений

- **Connection string:** замените в приложениях URL БД на Pigsty:
  - Хост: `104.223.25.234`
  - Порт: `6432` (PgBouncer) для приложений, `5432` для админских задач/миграций
  - БД: `myapp_prod`
  - Пользователь и пароль — из Pigsty (`pg_users` в `pigsty.yml`).
- **Гибрид (Auth в Cloud, данные в Pigsty):** переменные Supabase для авторизации (`NEXT_PUBLIC_SUPABASE_URL`, anon key) не трогаете; чтение/запись данных переводите на свой бэкенд, который подключается к Pigsty. Подробно: [FRONTEND-INTEGRATION.md](./FRONTEND-INTEGRATION.md).
- **Полный self-host:** если поднимаете Supabase (Studio, PostgREST, Auth) на Pigsty через `./docker.yml` и `./app.yml`, настройте их на целевую БД и обновите в приложениях URL и ключи API на ваш инстанс (http://104.223.25.234:8000 и т.д.). См. [INSTALL-SUPABASE-STUDIO.md](./INSTALL-SUPABASE-STUDIO.md) и [SUPABASE-STUDIO-PIGSTY.md](./SUPABASE-STUDIO-PIGSTY.md).

---

## 8. Возможные проблемы при полной миграции

Ниже — типичные проблемы и как их обойти. Подробные фиксы по вашей среде уже есть в [SUPABASE-CONTAINERS-FIX-2026-02.md](./Reports/SUPABASE-CONTAINERS-FIX-2026-02.md) и [STUDIO-CREATE-USER-ERROR.md](./STUDIO-CREATE-USER-ERROR.md).

### 8.1 База данных и дамп

| Проблема | Причина | Что делать |
|----------|---------|------------|
| Ошибки при восстановлении `roles.sql` / `schema.sql` | В дампе указан владелец `supabase_admin` или роли, которых нет на Pigsty | Закомментировать или заменить в дампе `OWNER TO "supabase_admin"` на `postgres`; кастомным ролям с `LOGIN` после импорта задать пароли вручную |
| Разные версии PostgreSQL | В Cloud может быть 15/16, на Pigsty — 17 | Обычно дамп 15/16 восстанавливается в 17; при несовместимости — проверить [release notes](https://www.postgresql.org/docs/release/) и при необходимости временно исключить проблемные объекты |
| Очень большой дамп, таймаут/обрыв | Долгий экспорт или импорт | Экспорт/импорт делать с машины с стабильным доступом к Cloud и Pigsty; для импорта можно увеличить `statement_timeout` в сессии или разбить данные на части |
| Direct connection к Cloud недоступен | IPv6, фаервол или ограничения региона | Использовать **Session pooler** (другой хост в connection string); если не поможет — экспорт с машины в том же регионе/облаке, затем перенос файлов дампа |

### 8.2 Расширения

| Проблема | Причина | Что сделать |
|----------|---------|-------------|
| `CREATE EXTENSION ...` падает при восстановлении | В Pigsty нет расширения или другая версия | Установить расширение в кластере (`pg_extensions` в `pigsty.yml` или `CREATE EXTENSION` от суперпользователя); при импорте можно временно закомментировать строки с расширениями и включить их вручную после |
| pgsodium, pg_graphql, pg_net | Специфичны для Supabase Cloud, в стандартном Postgres их нет | При полном дампе — исключить эти расширения при экспорте (`--exclude-extension=pgsodium` и т.д.) или не восстанавливать объекты, от них зависящие; заменить функциональность своим кодом при необходимости |

### 8.3 Схемы auth, storage, realtime

Если вы переносите **полный дамп** (включая служебные схемы Supabase) и потом поднимаете **Supabase на Pigsty** (Auth, Storage, PostgREST):

| Проблема | Причина | Что делать |
|----------|---------|------------|
| Контейнеры **rest**, **auth**, **storage** в Restarting | Нет ролей `authenticator`, `anon`, `authenticated`, `service_role`, `supabase_storage_admin` или нет прав на схемы | Создать роли и выдать права по скрипту, см. [SUPABASE-CONTAINERS-FIX-2026-02.md](./Reports/SUPABASE-CONTAINERS-FIX-2026-02.md) и `sql/supabase_fix_failing_containers.sql` |
| GoTrue (auth) падает при старте | Миграции GoTrue не совпадают с состоянием схемы (например `20221208132122` — сравнение uuid/text) | Применить патчи миграций и пометить версии в `auth.schema_migrations`; см. отчёт и `sql/supabase_fix_auth_storage_round2.sql`, `sql/supabase_fix_auth_oauth_round3.sql` |
| Кнопка «Create user» в Studio не работает | Auth API недоступен или миграции GoTrue падают | Создать пользователя **supabase_auth_admin**, выдать права на схему `auth`; при падении миграций — обход через SQL (вставка в `auth.users`), см. [STUDIO-CREATE-USER-ERROR.md](./STUDIO-CREATE-USER-ERROR.md) |
| Realtime: контейнер unhealthy (403) или не подключается | Health check через Kong возвращает 403; или не настроен `wal_level = logical` | Для Realtime на Pigsty нужен logical replication; при неиспользовании Realtime контейнер можно отключить (`docker stop` + `restart=no`), см. отчёт |

### 8.4 RLS и роли приложения

| Проблема | Причина | Что делать |
|----------|---------|------------|
| После миграции запросы от приложения возвращают пустые наборы или 403 | RLS включён, а роль `anon`/`authenticated` не совпадает с той, что в Cloud, или JWT не передаётся | Проверить политики RLS и роли в БД; при использовании PostgREST на Pigsty — те же имена ролей и настройка JWT (ключ, claim role); при гибриде (свой API) — права у пользователя БД, от имени которого ходит бэкенд |
| Ошибки вида «permission denied for schema public» | У роли приложения нет USAGE/CREATE на нужных схемах | Выдать `GRANT USAGE ON SCHEMA public TO role_name` и при необходимости права на таблицы |

### 8.5 Storage (файлы)

| Проблема | Причина | Что делать |
|----------|---------|------------|
| Файлы из Supabase Storage не появились на сервере | Дамп БД переносит только метаданные (таблицы storage.objects и т.д.), не сами файлы | Перенести объекты отдельно: скрипт/утилита по API или [Backup and Restore — Migrate storage objects](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore); затем проверить пути и политики доступа на self-hosted Storage |

### 8.6 Studio и внешний Postgres

| Проблема | Причина | Что делать |
|----------|---------|------------|
| Studio не подключается к БД на Pigsty | Часть параметров подключения в Studio захардкожена (localhost:5432) | Пробросить в контейнер `studio` переменные `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`; при необходимости смотреть актуальные issues в репозитории Supabase, см. [SUPABASE-STUDIO-PIGSTY.md](./SUPABASE-STUDIO-PIGSTY.md) (раздел 3.3) |

### 8.7 Сеть и доступ

| Проблема | Причина | Что сделать |
|----------|---------|-------------|
| Подключение к 104.223.25.234:5432 или 6432 не устанавливается | Фаервол (UFW и т.д.) или HBA не разрешают ваш IP | Добавить ваш IP в правила UFW и при необходимости в `pg_hba_rules`/`pgb_hba_rules` в `pigsty.yml`, применить плейбук |
| PgBouncer отказывает в доступе | Пользователь не в пуле или нет прав на БД в `pgb_hba_rules` | Проверить, что пользователь есть в `pg_users` с `pgbouncer: true` и что в `pgb_hba_rules` есть правило для этого пользователя/БД и вашего адреса |

Перед полной миграцией имеет смысл сделать тестовый перенос на копию БД (например `myapp_prod_test`), прогнать восстановление и проверку контейнеров Supabase, затем уже резать прод.

---

## 9. Краткий чеклист (полная миграция)

**Одна БД:**

1. [ ] Выбрать стратегию: гибрид или полная миграция.
2. [ ] Создать целевую БД на Pigsty (`pigsty.yml` или SQL).
3. [ ] Получить connection string из Supabase Cloud (Project Settings → Database).
4. [ ] Экспорт: Supabase CLI (`roles.sql`, `schema.sql`, `data.sql`) или `pg_dump`.
5. [ ] Восстановление в целевую БД на 104.223.25.234.
6. [ ] Проверить расширения, права, RLS.
7. [ ] При необходимости: перенести Storage, настроить Realtime.
8. [ ] Переключить приложения на Pigsty (connection strings и/или API).

**Несколько БД (рекомендуется Supabase CLI — один сценарий на все проекты):**

1. [ ] Создать все целевые БД в `pigsty.yml` (например `gd_lounge_prod`, `project2_prod`, …), применить `./pgsql.yml -l pg-meta`.
2. [ ] Для каждого проекта: получить URL Cloud → экспорт через Supabase CLI в свою папку (`migration_<проект>/` → roles.sql, schema.sql, data.sql).
3. [ ] При необходимости: в каждом schema.sql заменить supabase_admin на postgres, закомментировать расширения Supabase-only.
4. [ ] Для каждого проекта: восстановление в порядке roles → schema → data в соответствующую БД на Pigsty.
5. [ ] Для каждой БД: расширения, права, RLS; при необходимости Storage/Realtime.
6. [ ] Переключить все приложения на свои connection strings к Pigsty.

---

## 10. Связанные документы

| Документ | Содержание |
|----------|------------|
| [SUPABASE-INVENTORY-MIGRATION.md](./SUPABASE-INVENTORY-MIGRATION.md) | Полная инвентаризация перед миграцией: БД, Storage, Auth, add-ons, Realtime, Edge Functions |
| [MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md](./MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md) | Сводка по двум проектам к переносу: GD-lounge и imperial (инвентаризация, команды) |
| [STORAGE-MIGRATION-SUPABASE-TO-PIGSTY.md](./STORAGE-MIGRATION-SUPABASE-TO-PIGSTY.md) | Пошаговый перенос файлов Supabase Cloud Storage на Pigsty (несколько проектов) |
| [SUPABASE-STUDIO-PIGSTY.md](./SUPABASE-STUDIO-PIGSTY.md) | Supabase Studio на Pigsty, внешний Postgres, миграция Cloud (раздел 4), безопасность |
| [INSTALL-SUPABASE-STUDIO.md](./INSTALL-SUPABASE-STUDIO.md) | Установка Supabase через Pigsty (`./docker.yml`, `./app.yml`) |
| [FRONTEND-INTEGRATION.md](./FRONTEND-INTEGRATION.md) | Подключение фронта к БД Pigsty вместо Supabase (API, пример `/api/news`) |
| [PLAN.md](./PLAN.md) | Общий план миграции, гибрид Auth (Cloud) + данные (Pigsty), чеклист по серверу |

Официальная справка Supabase: [Transferring from cloud to self-host](https://supabase.com/docs/guides/troubleshooting/transferring-from-cloud-to-self-host-in-supabase-2oWNvW).
