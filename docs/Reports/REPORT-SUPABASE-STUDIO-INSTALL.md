# Отчёт: установка Supabase Studio через Pigsty (15.02.2026)

## Что сделано

### 1. Конфиг pigsty.yml (репо и сервер)

- В **pg_users** добавлен пользователь **supabase_admin** (пароль `SupaAdmin7mN2pQ4r`), роли dbrole_admin, superuser, createdb, createrole.
- В **pg_hba_rules** добавлено правило для сети Docker: `172.17.0.0/16`, auth pwd (для доступа контейнеров Supabase к PostgreSQL).
- В **pg_databases** добавлена БД **supabase** (comment: Supabase Studio analytics).
- Добавлена группа **supabase** с хостом 104.223.25.234, `app: supabase`, секция **apps.supabase** с conf:
  - POSTGRES_HOST/PORT/DB/PASSWORD (подключение к кластеру Pigsty),
  - JWT_SECRET, ANON_KEY, SERVICE_ROLE_KEY, PG_META_CRYPTO_KEY,
  - DASHBOARD_USERNAME/PASSWORD (supabase / pigsty),
  - LOGFLARE_*, SITE_URL, API_EXTERNAL_URL, SUPABASE_PUBLIC_URL = http://104.223.25.234:8000.
- В **infra_portal** добавлен endpoint **supa** (порт 8000, websocket: true).

Файл скопирован на сервер: `~/pigsty/pigsty.yml`.

### 2. PostgreSQL

- Выполнены плейбуки: **pgsql_user** (создан supabase_admin), **pgsql_hba** (правило для 172.17.0.0/16).
- Вручную созданы (т.к. в момент первого запуска app их ещё не было в конфиге):
  - БД **supabase** (OWNER supabase_admin),
  - схема **_analytics** в БД supabase (для Logflare).

### 3. Docker

- Выполнен **./docker.yml -l supabase**: установлены Docker и docker-compose-plugin, пользователи st и dba добавлены в группу docker, сервис запущен.

### 4. Приложение Supabase

- Выполнен **./app.yml -l supabase**: разложены файлы в /opt/supabase, сгенерирован .env из conf, запущен `make` (docker compose pull/up).
- Плейбук завершился с **rc 2** (make failed) из‑за того, что контейнер **analytics** (Logflare) падал: не было БД **supabase** и схемы **_analytics**.
- После создания БД и схемы контейнер analytics перезапущен, стал **healthy**.
- Выполнен **docker compose up -d** в /opt/supabase: подняты все сервисы.

### 5. Состояние сервисов

- **Порт 8000** слушает (Kong API gateway).
- Контейнеры: **imgproxy**, **vector**, **analytics** — healthy; **kong**, **studio**, **meta**, **storage**, **realtime**, **edge-functions** — Up; **rest** (PostgREST) и **auth** (GoTrue) могут перезапускаться, т.к. в БД **postgres** нет схем Supabase (auth, realtime и т.д.). Для работы только **Studio** (просмотр/управление БД) этого достаточно.

---

## Доступ к Studio

- **URL:** http://104.223.25.234:8000  
- **Логин:** supabase  
- **Пароль:** pigsty  

Рекомендуется сменить пароль в конфиге (DASHBOARD_PASSWORD) и переприменить app или вручную поправить /opt/supabase/.env и перезапустить контейнер kong/studio.

---

## Команды для повторного запуска (на сервере)

```bash
cd ~/pigsty
./docker.yml -l supabase    # если нужно переустановить Docker
./app.yml -l supabase       # развернуть/обновить приложение

# или вручную в /opt/supabase:
sudo docker compose up -d
sudo docker compose down && sudo docker compose up -d  # перезапуск
```

---

## Замечания

- Для полной работы Auth и PostgREST нужна БД **postgres** (или отдельная БД) с применёнными миграциями Supabase (схемы auth, realtime, storage и т.д.). Сейчас используется только БД **postgres** без этих схем, поэтому rest/auth могут быть неработоспособны. Studio и просмотр метаданных БД при этом доступны.
- БД **supabase** и схема **_analytics** добавлены в pigsty.yml; при следующем применении **pgsql_db** они будут создаваться плейбуком. На уже работающем кластере они уже созданы вручную.
