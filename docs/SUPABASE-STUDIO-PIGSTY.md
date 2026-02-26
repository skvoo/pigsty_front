# Supabase Studio на сервере БД (Pigsty) 104.223.25.234

**Цель:** развернуть Supabase Studio на том же сервере, где уже работает Pigsty, чтобы фронтендеры могли **создавать новые БД и таблицы** и **мигрировать базы из Supabase Cloud** в единый кластер Pigsty.

**Принцип:** развёртывание **только через Pigsty** — по [официальной инструкции Pigsty](https://pigsty.io/docs/app/supabase/). Используем плейбуки `./docker.yml` и `./app.yml`, конфиг в `pigsty.yml`. Ручная установка (git clone + docker compose без Pigsty) не применяется. Краткий пошаговый план: [INSTALL-SUPABASE-STUDIO.md](./INSTALL-SUPABASE-STUDIO.md).

---

## 0. Штатный способ Pigsty (единственный используемый путь)

**Pigsty предусматривает установку Supabase (в т.ч. Studio) через свои плейбуки** — это встроенный сценарий, ему и следуем.

- При первичной установке под Supabase: шаблон конфига **supabase** — `./configure -c supabase`, затем правка `pigsty.yml` (домен, пароли, ключи).
- После деплоя Pigsty: **`./docker.yml`** (модуль Docker), затем **`./app.yml`** — поднимаются безстатусные компоненты Supabase в Docker (Studio, Kong, PostgREST, Auth и т.д.), БД — в кластере Pigsty.
- Studio по умолчанию на порту **8000** (логин/пароль из конфига; обязательно сменить).

Официальная документация: **[Enterprise Self-Hosted Supabase | Pigsty](https://pigsty.io/docs/app/supabase/)**. Ниже — детали и варианты для уже работающего инвентаря (добавление Supabase к pg-meta, миграция из Cloud); ручные варианты (A/B) приведены только как справочник.

---

## 1. Рекомендуемый вариант: одна БД на Pigsty + новые БД + миграция из Supabase Cloud

Подходит, если нужно:
- **создавать новые базы данных** (для новых проектов или команд);
- **мигрировать существующие БД из Supabase Cloud** (дамп → восстановление на Pigsty);
- один кластер PostgreSQL (pg-meta), один стек Supabase (Studio + API) для работы с этими БД.

Идея: кластер Pigsty — единственный источник данных. Новые БД добавляются в него (через конфиг Pigsty или SQL). Проекты из Supabase Cloud переносятся дампом в новые БД на том же кластере. Supabase (Docker) подключается к Pigsty как к внешнему Postgres; Studio и REST API работают с выбранной БД.

Дальше в документе:
- **п. 1.1** — как создавать новые БД на Pigsty;
- **п. 1.2** — развёртывание Supabase с внешним Postgres (Pigsty) — детали в разделе 3;
- **п. 1.3** — пошаговая миграция БД из Supabase Cloud.

### 1.1 Создание новых БД на Pigsty

Новые базы можно заводить двумя способами.

**Способ 1: через конфиг Pigsty** (рекомендуется для постоянных БД)

В `pigsty.yml` в секции `pg_databases` кластера `pg-meta` добавьте базу:

```yaml
pg_databases:
  - name: meta
    # ... как сейчас
  - name: app
    comment: "Frontend test / news app"
  # Новые БД для фронтенд-проектов или миграций:
  - name: project_x
    comment: "Проект X (миграция из Supabase Cloud)"
  - name: project_y
    comment: "Новая БД для проекта Y"
```

После изменения выполните на сервере: `./pgsql.yml` (или полный `./deploy.yml` по необходимости), чтобы БД были созданы.

**Способ 2: через SQL** (для разовых или временных БД)

Подключитесь к кластеру (на сервере 104.223.25.234):

```bash
psql -h 127.0.0.1 -p 5432 -U postgres -d postgres -c "CREATE DATABASE project_z OWNER postgres;"
```

Либо через PgBouncer (порт 6432) с пользователем с правом создания БД. Для миграций из Supabase Cloud обычно создают отдельную БД под каждый переносимый проект.

### 1.2 Развёртывание Supabase с внешним Postgres (Pigsty)

Чтобы Studio и API работали с БД на Pigsty, разворачиваем Supabase в Docker, **без** контейнера своей БД — подключаемся к кластеру pg-meta. Пошагово это описано в **разделе 3** (вариант B): подготовка пользователя/пароля, при необходимости миграции схем Supabase, настройка `.env` и `docker-compose.yml` (POSTGRES_HOST, extra_hosts, отключение контейнера `db`), обход проблемы Studio с внешним Postgres.

После настройки в Studio можно переключать контекст на нужную БД (если интерфейс это поддерживает) или подключаться к разным БД через отдельные инстансы/конфигурации; технически все БД живут в одном кластере Pigsty.

### 1.3 Миграция БД из Supabase Cloud

Пошагово: экспорт из Cloud → создание БД на Pigsty → восстановление. Детали в **разделе 4** ниже.

---

## 2. Вариант A: Supabase со своим Postgres (справочник, не наш путь)

*Мы разворачиваем только через Pigsty (./docker.yml, ./app.yml). Вариант ниже — для справки, если когда-то понадобится изолированный стек без Pigsty.*

Если миграция из Supabase Cloud не нужна и достаточно изолированной БД «в контейнере», можно развернуть полный стек Supabase с встроенным Postgres вручную. Тогда будут две отдельные точки данных: Pigsty (meta, app) и Supabase (своя БД). Создавать новые таблицы/схемы можно в Studio; создание отдельных БД — ограничено (обычно одна БД на проект Supabase).

Все команды выполняются **на сервере 104.223.25.234** (под пользователем с правами на Docker).

### 2.1 Требования

- Docker и Docker Compose (на сервере уже включён Docker через Pigsty: `docker_enabled: true`, при необходимости прогнать `./docker.yml`).
- Порты: **8000** (API/Studio) — должен быть свободен или проброшен через фаервол.

### 2.2 Установка

```bash
# Каталог для проекта (например рядом с Pigsty или в /opt)
sudo mkdir -p /opt/supabase-project && cd /opt/supabase-project

# Клонировать репозиторий Supabase (только docker)
git clone --depth 1 https://github.com/supabase/supabase
cp -rf supabase/docker/* .
cp supabase/docker/.env.example .env
rm -rf supabase
```

### 2.3 Настройка секретов в `.env`

**Обязательно сменить** (не оставлять значения из примера):

1. **Пароль БД**
   - `POSTGRES_PASSWORD` — надёжный пароль для ролей `postgres` / `supabase_admin` (только буквы и цифры, без спецсимволов в connection string).

2. **Ключи API и JWT**
   - Сгенерировать: https://supabase.com/docs/guides/self-hosting/docker#generate-and-configure-api-keys  
   - Вписать в `.env`: `SERVICE_ROLE_KEY`, `ANON_KEY`, `JWT_SECRET`.

3. **Остальные ключи** (сгенерировать и подставить):
   - `LOGFLARE_PRIVATE_ACCESS_TOKEN`, `LOGFLARE_PUBLIC_ACCESS_TOKEN` (например: `openssl rand -base64 24`)
   - `PG_META_CRYPTO_KEY`, `VAULT_ENC_KEY`, `SECRET_KEY_BASE` — по инструкции в [документации](https://supabase.com/docs/guides/self-hosting/docker#configure-other-keys-and-important-urls).

4. **URL и доступ к Studio**
   - `SITE_URL` = `http://104.223.25.234:8000` (или ваш домен, если будете проксировать).
   - `API_EXTERNAL_URL`, `SUPABASE_PUBLIC_URL` — те же базовые URL (порт 8000).
   - **Пароль входа в Studio:** `DASHBOARD_PASSWORD` — обязательно сменить (только буквы/цифры, без спецсимволов).
   - По желанию: `DASHBOARD_USERNAME` (по умолчанию логин для Studio).

### 2.4 Запуск

```bash
cd /opt/supabase-project
docker compose pull
docker compose up -d
```

Через 1–2 минуты проверка: `docker compose ps` — все сервисы в статусе `Up (healthy)`.

### 2.5 Доступ для фронтендеров

- **URL:** `http://104.223.25.234:8000`
- **Логин/пароль:** значения `DASHBOARD_USERNAME` и `DASHBOARD_PASSWORD` из `.env`

В Studio доступны: Table Editor (создание/редактирование таблиц), SQL Editor, управление БД. Фронтендеры могут создавать свои таблицы и при необходимости использовать REST API по тому же адресу (порт 8000).

### 2.6 Интеграция с порталом Pigsty (опционально)

Если используется инфраструктурный портал (nginx в Pigsty), можно добавить endpoint для Studio в `pigsty.yml`:

```yaml
# В vars.infra_portal добавить, например:
supabase_studio: { domain: studio.pigsty, endpoint: "${admin_ip}:8000" }
```

И при необходимости ограничить доступ (VPN, basic auth, firewall) — по аналогии с `docs/SECURITY-PORTAL.md` и настройками для pgadmin.

---

## 3. Вариант B: Supabase с внешним PostgreSQL (Pigsty)

Используется **один** кластер Pigsty (pg-meta) как БД для Supabase. Подходит, если нужна единая точка данных и вы готовы пройти настройку и возможные обходные пути.

### 3.1 Подготовка БД на Pigsty

1. **Пользователь для Supabase**  
   В Pigsty завести отдельного пользователя с правами суперпользователя или CREATEDB, CREATEROLE (например `supabase_admin`) и задать пароль. Либо использовать существующего админского пользователя (например `dbuser_meta`), если политика безопасности допускает.

2. **Расширения и миграции**  
   Supabase ожидает в БД свои схемы и расширения. Нужно вручную выполнить миграции из репозитория Supabase:
   - https://github.com/supabase/supabase/tree/master/docker/volumes/db/init  
   Выполнять скрипты по порядку на целевую БД (например `postgres` или отдельную `supabase`) на кластере pg-meta.  
   Внимание: часть миграций рассчитана на «чистый» Postgres; при использовании существующей БД возможны конфликты имён (схемы, роли). Рекомендуется тест на копии или отдельной БД.

3. **Logical replication**  
   Для Realtime нужен `wal_level = logical` и слот репликации. В Pigsty это настраивается через `pg_conf` (например `shared_preload_libraries`, `wal_level`). При отсутствии Realtime этот шаг можно отложить.

### 3.2 Конфигурация Docker

В `.env` указать подключение к Postgres Pigsty:

```bash
POSTGRES_HOST=host.docker.internal   # или 172.17.0.1 / IP хоста в Docker-сети
POSTGRES_PORT=5432                   # прямой доступ к Postgres (не PgBouncer)
POSTGRES_USER=supabase_admin         # или dbuser_meta
POSTGRES_PASSWORD=<пароль>
POSTGRES_DB=postgres                 # или отдельная БД supabase
```

В `docker-compose.yml`:

- У сервисов, которые подключаются к БД, **убрать** `depends_on: db` (контейнер `db` не используем).
- Добавить во все эти сервисы:
  ```yaml
  extra_hosts:
    - "host.docker.internal:host-gateway"
  ```
- **Контейнер `db`** можно закомментировать или удалить из compose.

### 3.3 Известная проблема: Studio и внешний Postgres

У Supabase Studio есть ограничение: часть параметров подключения к БД захардкожена (localhost, порт 5432), а не читается из `POSTGRES_*`. Из-за этого Studio может не подключиться к внешней БД.

**Обходной путь:**

- Пробросить в контейнер `studio` переменные окружения: `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` (в `docker-compose.yml` в секции `studio.environment`).
- Если после этого Studio всё ещё не подключается — в репозитории Supabase есть открытые issues (например [#7628](https://github.com/supabase/supabase/issues/7628)); может потребоваться локальный патч или ожидание фикса.

Для варианта B обязательно проверять актуальную документацию и changelog:  
https://github.com/supabase/supabase/blob/master/docker/CHANGELOG.md

---

## 4. Миграция БД из Supabase Cloud на Pigsty

Цель: перенести данные и схему из проекта Supabase Cloud в новую БД на кластере Pigsty (104.223.25.234). Ниже два способа экспорта; восстановление всегда в БД на Pigsty.

### 4.1 Подготовка на стороне Supabase Cloud

1. В [Dashboard](https://supabase.com/dashboard) проекта: **Project Settings → Database** — сбросьте пароль БД, если не знаете текущий.
2. Возьмите **connection string**:
   - **Session pooler:** `postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-<region>.pooler.supabase.com:5432/postgres`
   - **Direct:** `postgresql://postgres.[PROJECT-REF]:[PASSWORD]@db.[PROJECT-REF].supabase.com:5432/postgres`  
   Для дампа предпочтительнее direct, если доступен (IPv4/VPN).

Подставьте свой пароль вместо `[PASSWORD]` и сохраните строку как `SOURCE_DB_URL` (локально не коммитить).

### 4.2 Способ 1: экспорт через Supabase CLI (рекомендуется)

Раздельный дамп ролей, схемы и данных — удобно для правок при восстановлении.

**Установка CLI:** https://supabase.com/docs/guides/local-development/cli/getting-started

**Экспорт (на своей машине или на сервере):**

```bash
export SOURCE_DB_URL="postgresql://postgres.[REF]:[PASSWORD]@db.[REF].supabase.com:5432/postgres"

supabase db dump --db-url "$SOURCE_DB_URL" -f roles.sql --role-only
supabase db dump --db-url "$SOURCE_DB_URL" -f schema.sql
supabase db dump --db-url "$SOURCE_DB_URL" -f data.sql --use-copy --data-only
```

Опционально — история миграций (если используете Supabase Migrations):

```bash
supabase db dump --db-url "$SOURCE_DB_URL" -f history_schema.sql --schema supabase_migrations
supabase db dump --db-url "$SOURCE_DB_URL" -f history_data.sql --use-copy --data-only --schema supabase_migrations
```

**Создание БД на Pigsty** (на сервере 104.223.25.234 или с машины с доступом к кластеру):

```bash
# Прямое подключение к Postgres (порт 5432) или через PgBouncer (6432) с пользователем с правом CREATEDB
psql -h 104.223.25.234 -p 5432 -U postgres -d postgres -c "CREATE DATABASE project_cloud_migrated OWNER postgres;"
```

Строка подключения к новой БД на Pigsty (для восстановления):

```bash
export TARGET_DB_URL="postgresql://postgres:ВАШ_ПАРОЛЬ@104.223.25.234:5432/project_cloud_migrated"
```

**Восстановление** (порядок важен):

```bash
psql --single-transaction --variable ON_ERROR_STOP=1 \
  --file roles.sql \
  --file schema.sql \
  --command 'SET session_replication_role = replica' \
  --file data.sql \
  --dbname "$TARGET_DB_URL"
```

Если при восстановлении появляются ошибки про `supabase_admin`, отредактируйте `schema.sql`: закомментируйте строки с `ALTER ... OWNER TO "supabase_admin"` или замените владельца на `postgres`. Кастомные роли с `login` после восстановления нужно будет задать пароли вручную.

Историю миграций (если выгружали) восстанавливайте отдельно:

```bash
psql --single-transaction --variable ON_ERROR_STOP=1 \
  --file history_schema.sql --file history_data.sql --dbname "$TARGET_DB_URL"
```

### 4.3 Способ 2: экспорт через pg_dump

Один файл дампа — быстрее, но меньше гибкости при восстановлении.

**Экспорт** (с машины с доступом к Supabase Cloud):

```bash
pg_dump "$SOURCE_DB_URL" \
  --no-owner --no-privileges \
  --format custom --file backup_project.dump
```

Чтобы не тащить лишние схемы Cloud (auth, storage, realtime, graphql и т.д.), можно исключить их:

```bash
pg_dump "$SOURCE_DB_URL" \
  --no-owner --no-privileges \
  --exclude-schema=graphql_public --exclude-schema=auth --exclude-schema=storage \
  --exclude-schema=realtime --exclude-schema=extensions --exclude-extension=pgsodium \
  --exclude-extension=pg_graphql \
  --format custom --file backup_project.dump
```

Список схем и расширений подправьте под свой проект (например, оставить только `public` и нужные вам схемы).

**Создание БД на Pigsty** — как в п. 4.2.

**Восстановление:**

```bash
pg_restore -h 104.223.25.234 -p 5432 -U postgres -d project_cloud_migrated --no-owner --no-privileges backup_project.dump
```

При ошибках (роли, расширения) исправляйте дамп или окружение и повторяйте; при использовании `--format custom` можно восстанавливать выборочно.

### 4.4 После миграции

- **Расширения:** в целевой БД на Pigsty включите те же расширения, что были в Cloud (PostgreSQL → Extensions в Studio или `CREATE EXTENSION ...`).
- **Realtime:** если в Cloud использовался Realtime, на Pigsty нужен `wal_level = logical` и настройка публикаций; см. раздел 3.
- **Storage:** файлы в Storage в Cloud не переносятся дампом БД. Объекты нужно копировать отдельно (скрипты/API), см. [Backup and Restore using the CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore) (Migrate storage objects).
- **Приложения:** после миграции переключите connection string приложений на новую БД на Pigsty (хост 104.223.25.234, порт 5432 или 6432, БД `project_cloud_migrated` и т.п.).

Официальная справка по переносу Cloud → self-hosted: [Transferring from cloud to self-host](https://supabase.com/docs/guides/troubleshooting/transferring-from-cloud-to-self-host-in-supabase-2oWNvW).

---

## 5. Безопасность и доступ

- **Пароль Studio:** всегда менять `DASHBOARD_PASSWORD` (и при необходимости `DASHBOARD_USERNAME`).
- **Сеть:** ограничить доступ к порту 8000 фаерволом (только офис/VPN или доверенные IP), либо выдать доступ только через портал Pigsty с аутентификацией.
- **Секреты:** `.env` не коммитить в репозиторий; на проде предпочтительно использовать secrets manager (Vault, Doppler и т.п.), как в [документации Supabase](https://supabase.com/docs/guides/self-hosting/docker#managing-your-secrets).

---

## 6. Полезные ссылки

- [Enterprise Self-Hosted Supabase | Pigsty](https://pigsty.io/docs/app/supabase/) — штатная установка Supabase через Pigsty (Docker + app.yml)
- [Self-Hosting Supabase (Docker)](https://supabase.com/docs/guides/self-hosting/docker)
- [Self-Hosting — обзор](https://supabase.com/docs/guides/self-hosting)
- [Transferring from cloud to self-host](https://supabase.com/docs/guides/troubleshooting/transferring-from-cloud-to-self-host-in-supabase-2oWNvW) — перенос с Supabase Cloud
- [Backup and Restore using the CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore) — дамп/восстановление через Supabase CLI
- [Подключение фронта к БД app (Pigsty)](./FRONTEND-INTEGRATION.md) — использование существующей БД `app` с сервера
- [Мониторинг и оповещения](./SERVER-MONITORING-ALERTING.md) — мониторинг сервера 104.223.25.234
