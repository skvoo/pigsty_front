# Установка Supabase Studio через Pigsty

**Принцип:** всё разворачиваем **только через Pigsty**, по [официальной инструкции Pigsty](https://pigsty.io/docs/app/supabase/). Ручная установка (git clone, docker compose отдельно) не используется.

---

## Официальный путь Pigsty

По документации Pigsty:

1. **Подготовка:** сервер в инвентаре, конфиг в `pigsty.yml`.
2. **Docker:** модуль Docker ставится плейбуком: `./docker.yml`.
3. **Supabase:** приложение Supabase (Studio и др.) поднимается плейбуком: `./app.yml`.

Конфигурация приложения задаётся в `pigsty.yml` (секция `apps.supabase` и переменные в `conf`). Studio по умолчанию на порту **8000**, логин/пароль — из конфига (по шаблону: `supabase` / `pigsty`, **обязательно сменить**).

---

## Два сценария

### Сценарий 1: Установка «с нуля» под Supabase

Если разворачиваете Pigsty на чистом сервере именно под Supabase:

- Использовать шаблон конфига: **`./configure -c supabase`** (в каталоге Pigsty).
- Отредактировать сгенерированный `pigsty.yml`: домен, IP (`admin_ip`), пароли, ключи (JWT_SECRET, ANON_KEY, SERVICE_ROLE_KEY и т.д.) — см. [Checklist](https://pigsty.io/docs/app/supabase/) и шаблон `conf/supabase.yml` на сервере.
- Выполнить: `./deploy.yml` → `./docker.yml` → `./app.yml`.

Подробно: https://pigsty.io/docs/app/supabase/

### Сценарий 2: Добавить Supabase к уже работающему Pigsty (104.223.25.234)

У нас уже развёрнут Pigsty (кластер pg-meta, БД meta и app, приложение pgadmin). Нужно **добавить** Supabase и не ломать текущий конфиг.

1. **Docker:** с хоста, где есть Ansible и каталог Pigsty, выполнить:
   ```bash
   ./docker.yml -l app
   ```
   Так Pigsty установит модуль Docker на хост(а) группы `app` (104.223.25.234).

2. **Конфиг Supabase в `pigsty.yml`:**  
   Взять из шаблона Pigsty определение приложения Supabase и параметры подключения к БД. На сервере шаблон лежит в `~/pigsty/conf/supabase.yml`. Нужно:
   - добавить в наший `pigsty.yml` группу (или использовать существующую `app`) с `app: supabase` и секцией `apps.supabase` и `conf` (POSTGRES_HOST, POSTGRES_PORT, POSTGRES_PASSWORD, JWT_SECRET, DASHBOARD_* и т.д.);
   - для работы Studio с нашим кластером — указать `POSTGRES_HOST: 104.223.25.234` (или внутренний IP ноды), порт до primary (например 5432 или 5436 по документации Pigsty), пароль пользователя, который есть в кластере (при добавлении Supabase к существующему кластеру может понадобиться завести пользователей/БД по шаблону supabase — см. `conf/supabase.yml`, секции `pg_users` / `pg_databases`).

3. **Применить приложение:**
   ```bash
   ./app.yml -l app
   ```
   (или та группа, где у вас прописан хост 104.223.25.234 с `app: supabase`.)

4. **Проверка:** открыть http://104.223.25.234:8000 — должен открыться Studio (логин/пароль из `DASHBOARD_USERNAME` / `DASHBOARD_PASSWORD` в конфиге).

Детали по пользователям и БД для Supabase в существующем кластере и по шаблону конфига — в [SUPABASE-STUDIO-PIGSTY.md](./SUPABASE-STUDIO-PIGSTY.md) (раздел про развёртывание с внешним Postgres и использование шаблона Pigsty).

---

## Что не делаем

- Не ставим Docker вручную (apt/скрипт) — только через **`./docker.yml`**.
- Не клонируем репозиторий Supabase и не запускаем `docker compose` вручную — только через **`./app.yml`** и конфиг в `pigsty.yml`.

Все изменения конфигурации — в `pigsty.yml`, все развёртывания — плейбуками Pigsty. После выполнения шагов имеет смысл оформить **отчёт**: какие команды выполнили, что изменили в конфиге, результат проверки (Studio открывается, подключается к нужной БД).
