# Исправление падающих контейнеров Supabase (15.02.2026)

## Итог

| Контейнер | Было | Стало |
|-----------|------|--------|
| **supabase-rest** (PostgREST) | Restarting (authenticator: auth failed) | **Up, healthy** |
| **supabase-storage** | Restarting (supabase_storage_admin: auth failed, затем permission denied) | **Up, healthy** |
| **supabase-auth** (GoTrue) | Restarting (миграции: uuid=text, factor_type, code_challenge_method) | **Up, healthy** |
| **realtime** | Restarting → затем unhealthy (403) | **Отключён** (остановлен, restart=no) — см. раздел «Отключение Realtime» |

---

## Что сделано

### 1. PostgreSQL: пользователи и роли для Supabase

В БД **app** созданы и настроены:

- **authenticator** (LOGIN) — для PostgREST, пароль как в `POSTGRES_PASSWORD`.
- Роли **anon**, **authenticated**, **service_role** (NOLOGIN), выданы в `authenticator`.
- **supabase_storage_admin** (LOGIN) — для Storage API.
- Схемы **storage**, **_realtime**, **graphql_public** и права на них.
- Права на БД/схему для storage: `GRANT CONNECT/CREATE ON DATABASE app`, владелец схемы storage.

Файл: `sql/supabase_fix_failing_containers.sql`.

### 2. GoTrue: миграции

- Исправлен бэкфилл миграции `20221208132122` (сравнение `id::text = user_id::text`), версия записана в `auth.schema_migrations` и `public.schema_migrations`.
- Для миграции `20240729123726` (MFA): созданы тип **auth.factor_type** (totp, webauthn, phone) и таблицы **auth.mfa_factors**, **auth.mfa_challenges**; миграция помечена выполненной.
- Для миграции `20250804100000` (OAuth): созданы тип **auth.code_challenge_method** и таблица **auth.oauth_clients**; миграция выполнилась сама.

Файлы: `sql/supabase_fix_failing_containers.sql`, `sql/supabase_fix_auth_storage_round2.sql`, `sql/supabase_fix_auth_oauth_round3.sql`.

### 3. Realtime

- Схема **_realtime** создана, права выданы **supabase_admin**, для пользователя задан `search_path = _realtime, public`.
- Контейнер запускается и подключается к Postgres; в логах: "Connected to Postgres database", "Janitor started".
- Health check возвращает **403** — вероятно, эндпоинт `/api/tenants/realtime-dev/health` требует JWT или заголовок tenant и Kong отдаёт 403. На работу Realtime это может не влиять; при необходимости поправить health в Kong или отключить/изменить проверку в docker-compose.

---

## Как повторить (на сервере)

```bash
# Все SQL от postgres на БД app
sudo -u postgres psql -d app -f /tmp/supabase_fix_failing_containers.sql
sudo -u postgres psql -d app -f /tmp/supabase_fix_auth_storage_round2.sql
sudo -u postgres psql -d app -f /tmp/supabase_fix_auth_oauth_round3.sql

# Перезапуск контейнеров
docker restart supabase-rest supabase-storage supabase-auth realtime-dev.supabase-realtime
```

Скрипты из репозитория перед применением скопировать на сервер (например в `/tmp/`).

---

## Пароли

Пользователи **authenticator** и **supabase_storage_admin** созданы с паролем из переменной **POSTGRES_PASSWORD** в конфиге Supabase (в pigsty.yml для приложения supabase: `SupaAdmin7mN2pQ4r`). При смене пароля в конфиге нужно обновить пароль и в PostgreSQL:

```sql
ALTER ROLE authenticator PASSWORD 'новый_пароль';
ALTER ROLE supabase_storage_admin PASSWORD 'новый_пароль';
```

---

## Отключение Realtime

Realtime отключён (контейнер остановлен, автозапуск выключен), т.к. не используется, а health check давал 403.

**На сервере было выполнено:**
```bash
docker stop realtime-dev.supabase-realtime
docker update --restart=no realtime-dev.supabase-realtime
```

**Включить снова при необходимости:**
```bash
docker update --restart=unless-stopped realtime-dev.supabase-realtime
docker start realtime-dev.supabase-realtime
```

После повторного запуска `./app.yml -l supabase` контейнер может снова появиться с политикой restart из шаблона Pigsty — тогда при необходимости снова выполнить `docker update --restart=no` и `docker stop`.
