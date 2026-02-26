# Ошибка «Failed to create user: API error» в Supabase Studio

## Причина

Кнопка **Create user** в Studio (Authentication → Users) вызывает **Auth API** (сервис GoTrue). Ответ «API error happened while trying to communicate with the server» означает, что запрос к этому API не проходит: контейнер **auth** может быть недоступен, перезапускается или не настроен на вашу БД.

В текущей схеме развёртывания Studio подключена к БД **app** на Pigsty, а контейнеры Supabase (в т.ч. GoTrue) берут параметры из `/opt/supabase/.env`. В шаблоне Pigsty GoTrue подключается с пользователем **supabase_auth_admin** и паролем из `POSTGRES_PASSWORD`. Если этого пользователя нет в PostgreSQL или у него нет прав на схему `auth`, контейнер auth падает/перезапускается и кнопка «Create user» не работает.

## Исправление: включить Auth API (кнопка «Create user»)

Чтобы кнопка **Create user** в Studio заработала, нужно создать в кластере пользователя **supabase_auth_admin** (его ожидает GoTrue) и выдать ему права на схему **auth** в БД **app**.

### Шаг 1. Конфиг уже обновлён (в репо)

В **pigsty.yml** в `pg_users` добавлен пользователь:

- **supabase_auth_admin**, пароль тот же, что у supabase_admin: `SupaAdmin7mN2pQ4r` (как в `POSTGRES_PASSWORD` в конфиге приложения).

### Шаг 2. Применить на сервере

**2.1.** Скопировать обновлённый `pigsty.yml` на сервер (если правили локально):

```bash
scp pigsty.yml st@104.223.25.234:~/pigsty/
```

**2.2.** Создать пользователя PostgreSQL (из каталога pigsty на сервере):

```bash
ssh st@104.223.25.234
cd ~/pigsty
./pgsql_user.yml -l pg-meta
```

**2.3.** Выдать права на схему auth в БД **app** (один раз). Скопировать `sql/supabase_auth_grant_auth_admin.sql` на сервер и выполнить:

```bash
# с вашей машины
scp sql/supabase_auth_grant_auth_admin.sql st@104.223.25.234:~/pigsty/

# на сервере
PGPASSWORD=SupaAdmin7mN2pQ4r psql -h 127.0.0.1 -p 5432 -U supabase_admin -d app -f ~/pigsty/supabase_auth_grant_auth_admin.sql
```

**2.4.** Перезапустить контейнер auth (на сервере):

```bash
cd /opt/supabase && sudo docker compose restart auth
```

При необходимости перезапустить все сервисы: `sudo docker compose restart`.

После шагов 2.1–2.4 контейнер **auth** подключается к БД, но при старте GoTrue запускает свои миграции. Одна из них (`20221208132122_backfill_email_last_sign_in_at`) несовместима с нашей схемой (сравнение `uuid` и `text` в `auth.identities`), из‑за неё контейнер перезапускается. Пока эта миграция не обойдена (например, патчем в образе или монтированием исправленного файла), кнопка **Create user** в UI может не заработать. Ниже — надёжный обход через SQL.

## Обходной путь: создать пользователя через SQL

Можно добавить пользователя напрямую в `auth.users`. Пароль нужно хранить в виде bcrypt-хеша (функции `crypt` и `gen_salt('bf')` из расширения **pgcrypto**).

### 1. На сервере (рекомендуется)

```bash
# В каталоге с SQL (или скопируйте auth_user_create_example.sql на сервер)
PGPASSWORD=SupaAdmin7mN2pQ4r psql -h 127.0.0.1 -p 5432 -U supabase_admin -d app -f auth_user_create_example.sql
```

Перед запуском отредактируйте `auth_user_create_example.sql`: подставьте нужные **email** и **пароль** в строках с `user@example.com` и `YourSecurePassword`. Если таблица `auth.instances` пуста, сначала выполните:

```sql
INSERT INTO auth.instances (id) VALUES (gen_random_uuid());
```

затем снова выполните INSERT в `auth.users` (в примере `instance_id` берётся из `auth.instances`).

### 2. Через Studio

- **SQL Editor:** откройте базу **app**, вставьте тот же SQL (с подставленным email и паролем, с `CREATE EXTENSION IF NOT EXISTS pgcrypto;` и при необходимости INSERT в `auth.instances`), выполните.
- **Table Editor:** можно вручную вставить строку в `auth.users`, но поле `encrypted_password` должно быть заполнено bcrypt-хешем. Проще использовать SQL выше.

После вставки пользователь появится в разделе **Authentication → Users** (обновите страницу).

## Проверка Auth API (если нужна кнопка «Create user»)

Чтобы кнопка в Studio работала, должен стабильно работать контейнер GoTrue и он должен подключаться к БД **app** (где есть схема `auth`).

На сервере:

```bash
cd /opt/supabase
sudo docker compose ps
sudo docker compose logs auth --tail 100
```

Проверьте:

1. Контейнер **auth** в состоянии **Up** (не перезапускается в цикле).
2. В логах нет ошибок подключения к БД. Если GoTrue настроен на свою внутреннюю БД (например `db` в compose), а не на хост Pigsty и БД **app**, то схема `auth` там отсутствует и сервис может падать.
3. В `.env` в `/opt/supabase` заданы переменные подключения к вашему Postgres: хост (104.223.25.234 или имя сервиса), порт, БД **app**, пользователь и пароль. В стандартном self-hosted Supabase для GoTrue часто используется переменная вроде `GOTRUE_DB_DATABASE_URL` или общие `POSTGRES_*`. Нужно, чтобы в итоге GoTrue подключался к БД **app** на Pigsty, где уже применены `supabase_auth_schema_*.sql`.

Если конфиг Supabase (compose/env) не передаёт в контейнер **auth** подключение к БД **app** на 104.223.25.234, его нужно добавить или изменить и перезапустить контейнеры. Точные имена переменных смотрите в документации Supabase Self-Hosting и в шаблоне приложения Pigsty для **supabase** (файлы в `/opt/pigsty` или там, откуда разворачивается `app.yml -l supabase`).

## Кратко

| Задача | Решение |
|--------|--------|
| Создать пользователя сейчас | SQL: `sql/auth_user_create_example.sql` (подставить email и пароль), выполнить в БД **app**. |
| Чтобы работала кнопка «Create user» | Нужен пользователь **supabase_auth_admin** и владение схемой auth (см. раздел «Исправление»). Контейнер auth пока падает на миграции GoTrue (uuid vs text) — для создания пользователей используйте SQL (раздел выше). |
