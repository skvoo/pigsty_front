# План: Pigsty 104.223.25.234 — миграция с Supabase Cloud

> **Примечание:** этот документ описывает состояние на 10.02.2026. Актуальный единый план по серверу (UI, бэкапы, безопасность) — **docs/PLAN-SERVER-104.md** (15.02.2026).

**Дата актуализации:** 10 февраля 2026  
**Сервер:** RackNerd VPS 104.223.25.234  
**Цель:** миграция с Supabase Cloud с минимальными изменениями во фронтенде.

---

## 1. Текущее состояние (аудит)

Проверка выполнена 10.02.2026. Установка недавняя, данных проектов пока нет — только дефолтная конфигурация Pigsty.

### 1.1 Окружение

| Параметр | Значение |
|----------|----------|
| ОС | Ubuntu (ядро 6.8.0-31-generic, x86_64) |
| Ресурсы | 4 vCPU, ~6 GB RAM, 135 GB диск |
| Свободно на диске | ~121 GB |
| Admin-пользователь | `st` (uid 1000), passwordless SSH + sudo ✅ |
| Локаль | en_US.utf8 ✅ |

### 1.2 Pigsty и PostgreSQL

| Параметр | Значение |
|----------|----------|
| Pigsty | каталог `~/pigsty`, конфиг `~/pigsty/pigsty.yml` |
| Версия (из конфига) | v4.0.0 |
| Кластер | `pg-meta` (single primary) |
| PostgreSQL | 17.7 (Ubuntu PGDG) |
| PGDATA | `/data/postgres/pg-meta-17` |
| Базы данных | `postgres`, `meta` (только служебные) |
| Расширения (в конфиге) | postgis, pgvector |

### 1.3 Сервисы и порты

**Работают:** patroni, pgbouncer, etcd, nginx, grafana-server, haproxy, alertmanager, node_exporter, pg_exporter, pgbackrest_exporter, nginx_exporter, blackbox_exporter, vector, vlogs, vmetrics, vmalert, vtraces.

**Порты:** 22 (SSH), 53 (DNS), 80 (HTTP), 443 (HTTPS), 2379/2380 (etcd), 3000 (Grafana), 5432 (PostgreSQL), 5433/5434/5436/5438 (внутренние PG), 6432 (PgBouncer), 8008, 8686, 8880, 9100/9101, 9094 и др.

### 1.4 Конфигурация (по серверу и проекту)

- **Кластер:** `pg-meta`, один хост 104.223.25.234, primary.
- **Пользователи БД:** `dbuser_meta`, `dbuser_view` (оба в PgBouncer).
- **БД:** `meta` (baseline cmdb.sql, схемы pigsty, расширения postgis, vector).
- **PgBouncer:** включён, порт 6432.
- **pgBackRest:** метод `local`, репозиторий `/pg/backup` (каталоги archive, backup присутствуют).
- **Crontab:** `00 01 * * * /pg/bin/pg-backup full`.
- **Nginx:** Basic Auth задан в конфиге (`nginx_users`: admin).
- **MINIO / REDIS / DOCKER:** в конфиге отключены или закомментированы; app (pgadmin) описан, но не проверялось.

### 1.5 Безопасность (расхождения с целевым планом)

Подробный чеклист по защите веб-портала: **docs/SECURITY-PORTAL.md**.

| Пункт | Сейчас | По плану |
|-------|--------|----------|
| UFW | **inactive** | Включить, allowlist для 22/80/443/6432, 5432 только для админских IP |
| SSH root | **PermitRootLogin yes** | Отключить (PermitRootLogin no) |
| SSL для Nginx | Не проверялось | Рекомендуется минимум self-signed для Basic Auth |
| HBA для приложений | В конфиге `addr: intra` (внутренняя сеть) | Ограничить по IP фронтендов при доступе снаружи |

---

## 2. Цели и стратегия

- **Цель:** перенести данные и нагрузку с Supabase Cloud на Pigsty с минимальными изменениями во фронтенде.
- **Стратегия:** **донастройка поверх текущей установки** — переустановка не требуется. Есть только служебная БД `meta`, данных проектов нет. Действия: привести конфиг и безопасность в соответствие с планом, затем добавить БД/роли под миграцию и выполнить перенос.

---

## 3. Открытые вопросы (требуют ответа)

### 3.1 Миграция БД

- **Версия PostgreSQL в Supabase** (15 / 16 / 17). На Pigsty стоит 17 — желательно совпадение или план совместимости дампа.
- **Объём дампа** (ориентировочно в плане было ~40 GB) — для оценки места под импорт и бэкапы.

### 3.2 Доступ к БД

- **IP или подсети фронтендов/бекендов**, которые будут подключаться к БД. Нужны для:
  - allowlist UFW для порта 6432 (PgBouncer);
  - при необходимости — `pgb_hba_rules` / `pg_hba_rules` в `pigsty.yml`.

### 3.3 Бэкапы

- **Место под бэкапы на VPS:** сколько из 121 GB выделить под `/pg/backup` и retention (например, 14 дней full + incremental).
- **Внешняя копия:** **принято — сервер 107.175.134.104** (копирование репозитория `/pg/backup` через rsync по SSH). Настроить cron/скрипт и доступ с 104.223.25.234 на 107.175.134.104.

### 3.4 WebUI и SSL

- **HTTPS для портала Pigsty:** включить как минимум self-signed (рекомендовано для защиты паролей Basic Auth).

### 3.5 Фронтенд и авторизация

- **Используется Supabase OAuth** (логин через провайдеров: Google, GitHub и т.д.).
- **Принято решение (пока): вариант 1 — гибрид.**
  - **Auth (OAuth, пользователи, сессии)** остаётся в Supabase Cloud (те же `NEXT_PUBLIC_SUPABASE_URL` и anon key для авторизации).
  - **Данные приложения** (таблицы, например `public.news`) — в Pigsty (БД `app`, подключение через PgBouncer или свой API).
- **Пока данных нет** — требуется **тестирование** связки: OAuth в облаке + чтение/запись данных в Pigsty. После тестов решение можно пересмотреть (self-host Auth или замена на другой OAuth).

**Текущее подключение фронта к Supabase (не менять для Auth при гибриде):**

```env
NEXT_PUBLIC_SUPABASE_URL=https://byfqfutcuvjjbcovckme.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY=sb_publishable_B6PM-gNxGPvt5guFdugMrQ_nAc1L5rc
# anon key (JWT для PostgREST / RLS)
anon_key=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5ZnFmdXRjdXZqamJjb3Zja21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk3NjE5MjAsImV4cCI6MjA4NTMzNzkyMH0.BWi2hKvtHVzP2yXWUjRYVHIi4DGOst1F_aAIM8ahruc
```

При гибриде эти переменные остаются для авторизации (OAuth). Доступ к данным приложения (таблица `news` и др.) — через бэкенд, подключающийся к Pigsty (см. раздел 5).

---

## Как фронт получает данные сейчас и как будет при гибриде

### Сейчас (всё в Supabase Cloud)

```
Фронт (браузер)
  → Supabase JS: supabase.from('news').select() / .insert() / .update()
  → HTTP-запрос на https://byfqfutcuvjjbcovckme.supabase.co (PostgREST API)
  → PostgREST обращается к БД Supabase
  → ответ JSON обратно на фронт
```

**Итог:** данные фронт получает через **Supabase API** (PostgREST в облаке). Прямого подключения к PostgreSQL из браузера нет.

---

### При гибриде (Auth в Supabase, данные в Pigsty)

**Авторизация** — без изменений: те же `NEXT_PUBLIC_SUPABASE_URL` и anon key, вызовы `supabase.auth.signInWithOAuth()`, `getSession()` и т.д. идут в Supabase Cloud.

**Данные** (таблица `news` и др.) — фронт больше **не** вызывает `supabase.from('news')` для этих данных, потому что тогда запрос снова уйдёт в облако Supabase, а не в Pigsty.

Схема такая:

```
Фронт (браузер)
  → вызов вашего бэкенда: fetch('/api/news') или Server Action getNews()
  → Next.js (или другой бэкенд) на вашем сервере
  → бэкенд подключается к Pigsty по строке postgresql://dbuser_app:...@104.223.25.234:6432/app
  → SQL к таблице public.news, результат в JSON
  → бэкенд отдаёт JSON фронту
```

**Итог:** данные из Pigsty фронт получает **только через ваш бэкенд** (API routes, Server Actions и т.п.), который сам ходит в Pigsty по connection string. В браузере строки к Pigsty нет и не будет.

**Что меняется в коде фронта:** вместо вызовов Supabase client для данных (`supabase.from('news').select()`) — вызовы вашего API (например `fetch('/api/news')`) или серверных функций (Server Actions), которые внутри уже работают с Pigsty.

---

## 4. Чеклист действий

### 4.1 Безопасность (привести в соответствие с планом)

- [ ] Включить UFW, настроить правила:
  - 22 (SSH) — только админские IP или оставить открытым при входе по ключам по решению админа;
  - 80/443 — открыты для WebUI;
  - 6432 (PgBouncer) — только IP фронтендов (allowlist);
  - 5432 (PostgreSQL) — закрыт снаружи или только админские IP.
- [ ] В `sshd_config`: установить `PermitRootLogin no`, перезапустить sshd (после проверки входа под `st`).
- [ ] Включить HTTPS для Nginx (минимум self-signed): параметр `nginx_sslmode: enable` в конфиге, затем применить плейбук (см. **docs/SECURITY-PORTAL.md**).

### 4.2 Конфигурация Pigsty под миграцию

- [ ] Зафиксировать в `pigsty.yml` (и при необходимости синхронизировать с сервером):
  - `pgb_hba_rules` / `pg_hba_rules` с IP фронтендов, если доступ к 6432/5432 с внешних хостов;
  - retention для pgBackRest (например `retention_full: 2`, `retention_diff: 7` или по месту);
  - при наличии домена — записи для портала (g.pigsty, p.pigsty, a.pigsty) или оставить работу по IP.
- [ ] Решить: оставить один кластер `pg-meta` и добавлять БД/роли для проектов или завести отдельный кластер под миграцию (например `pg-core`) — по плану «одна БД = один проект» или отдельный кластер для крупных проектов.

### 4.3 Фронтенд и тестирование гибрида (Auth в Supabase, данные в Pigsty)

- [ ] Проверить работу гибридной схемы: Supabase OAuth (URL + anon key без изменений) + данные из Pigsty (БД `app`, таблица `public.news`). Пока данных нет — тест на создание БД/таблицы и подключение фронта к Pigsty для CRUD.
- [ ] При необходимости: вынести чтение/запись данных в API routes или Server Actions с подключением к Pigsty; Auth-вызовы оставить через Supabase client.

### 4.4 Миграция данных Supabase → Pigsty (когда появятся данные)

- [ ] Экспорт дампа из Supabase (pg_dump / custom format по необходимости).
- [ ] Создание БД и ролей в Pigsty: через `bin/pgsql-user`, `bin/pgsql-db` или соответствующие плейбуки/конфиг в `pigsty.yml`.
- [ ] Восстановление дампа (pg_restore / psql).
- [ ] Проверка приложений (подключение к PgBouncer 6432 или напрямую 5432 для админских задач).
- [ ] Переключение connection strings / DNS на 104.223.25.234 для данных приложения.

### 4.5 Мониторинг и бэкапы

- [ ] Проверить доступ к Grafana через Nginx (http(s)://104.223.25.234 с Basic Auth).
- [ ] Расписание pgBackRest: убедиться, что crontab на ноде выполняет full/incremental по выбранной политике.
- [ ] Настроить вынос копии репозитория `/pg/backup` на сервер бэкапов **107.175.134.104** (rsync по SSH, cron с 104.223.25.234).
- [ ] Провести тестовое восстановление из бэкапа.

### 4.6 Документация и конфиг

- [ ] Хранить актуальный `pigsty.yml` в репозитории проекта (уже есть в корне).
- [ ] Обновлять этот план по мере закрытия вопросов и выполнения пунктов.

---

## 5. БД `app` для проверки фронтенда

Добавлены в `pigsty.yml`:

- **База данных:** `app` (comment: Frontend test / news app).
- **Пользователь:** `dbuser_app`, пароль `AppTest7x9Kp2mNqR`, доступ через PgBouncer, роль `dbrole_readwrite`.
- **Схема:** таблица `public.news` и индексы — в репозитории в файле `sql/app_schema.sql`.

### Как применить на сервере

1. **Скопировать обновлённый конфиг на сервер** (если правите локально):
   ```bash
   scp pigsty.yml st@104.223.25.234:~/pigsty/
   ```
2. **Создать пользователя и БД через Ansible** (на сервере или с машины, откуда крутится Ansible):
   ```bash
   ssh st@104.223.25.234
   cd ~/pigsty
   ansible-playbook -i inventory/pigsty pgsql-user.yml -l pg-meta
   ansible-playbook -i inventory/pigsty pgsql-db.yml -l pg-meta
   ```
   Либо применить весь плейбук PGSQL: `ansible-playbook -i inventory/pigsty pgsql.yml -l pg-meta`.
3. **Создать таблицу и индексы** (один раз после создания БД):
   ```bash
   psql -h 127.0.0.1 -p 5432 -U dbuser_app -d app -f sql/app_schema.sql
   ```
   Или с вашей машины (если открыт 5432): `psql -h 104.223.25.234 -p 5432 -U dbuser_app -d app -f sql/app_schema.sql`.

### Строка подключения для фронтенда

- **Через PgBouncer (рекомендуется для приложения):**  
  `postgresql://dbuser_app:AppTest7x9Kp2mNqR@104.223.25.234:6432/app`  
  (режим пула по умолчанию — transaction.)
- **Напрямую к PostgreSQL (миграции, админка):**  
  `postgresql://dbuser_app:AppTest7x9Kp2mNqR@104.223.25.234:5432/app`

Пароль при необходимости сменить в `pigsty.yml` и перезапустить приложение плейбука пользователей.

---

## 5.1 Тест забора данных фронтом из Pigsty

**Что нужно по шагам:**

1. **Создать БД и пользователя на сервере** (если ещё не сделано):
   - Скопировать актуальный `pigsty.yml` на сервер: `scp pigsty.yml st@104.223.25.234:~/pigsty/`
   - На сервере: `cd ~/pigsty && ansible-playbook -i inventory/pigsty pgsql-user.yml -l pg-meta && ansible-playbook -i inventory/pigsty pgsql-db.yml -l pg-meta`
2. **Создать таблицу** (один раз): выполнить `sql/app_schema.sql` на БД `app` (см. команды выше в разделе 5).
3. **Вставить тестовую запись:** выполнить `sql/seed_news_test.sql` на БД `app`:
   ```bash
   psql -h 104.223.25.234 -p 5432 -U dbuser_app -d app -f sql/seed_news_test.sql
   ```
   Или на сервере: `psql -h 127.0.0.1 -p 5432 -U dbuser_app -d app -f ~/sql/seed_news_test.sql` (предварительно скопировать файл в `~/sql/` на сервере).
4. **В проекте фронта (Next.js):** добавить переменную для бэкенда (без `NEXT_PUBLIC_`, чтобы не светить в браузер):
   ```env
   DATABASE_URL=postgresql://dbuser_app:AppTest7x9Kp2mNqR@104.223.25.234:6432/app
   ```
5. **API-маршрут для выборки новостей** (например `app/api/news/route.ts`):
   - Подключение к БД по `DATABASE_URL` (например через `pg` или `postgres` пакет).
   - `GET` — выполнить `SELECT * FROM public.news WHERE published = true ORDER BY created_at DESC` и вернуть JSON.
6. **На фронте:** вместо `supabase.from('news').select()` вызывать `fetch('/api/news')` (или ваш путь) и отображать результат.

Файл **`sql/seed_news_test.sql`** в репозитории добавляет одну тестовую запись (slug `test-from-pigsty`, заголовки EN/RU). После выполнения шагов 1–3 в таблице будет одна строка для проверки.

---

## 6. Ключевые параметры конфигурации (ориентир)

Для донастройки в `pigsty.yml` (глобальные и кластерные vars):

```yaml
# Уже в конфиге (проверить соответствие на сервере)
admin_ip: 104.223.25.234
ansible_user: st
pg_version: 17
pgbouncer_enabled: true
pgbackrest_method: local
pgbackrest_repo:
  local:
    path: /pg/backup
# retention при необходимости:
#   retention_full: 2
#   retention_diff: 7

nginx_users:
  admin: "<STRONG_PASSWORD>"   # надёжный пароль, хранить в секретах

# SSL для Nginx (рекомендуется)
# nginx_sslmode: enable
# nginx_ssl_mode: self

# HBA для PgBouncer — после получения IP фронтендов
# pgb_hba_rules:
#   - title: allow application servers
#     role: common
#     rules:
#       - host all all <FRONTEND_IP_1>/32 scram-sha-256
#       - host all all <FRONTEND_IP_2>/32 scram-sha-256
```

После изменений конфига применять нужные плейбуки (например `infra.yml`, `pgsql.yml`, или точечные pgsql-user/pgsql-db) с хоста, где есть Ansible и доступ к серверу.

---

## 7. Контакты и ссылки

- Документация Pigsty: https://pigsty.io/docs/
- Single-Node Install: https://pigsty.io/docs/setup/install/
- Репозиторий: https://github.com/Vonng/pigsty

---

*Документ обновляется по мере получения ответов на открытые вопросы и выполнения этапов.*
