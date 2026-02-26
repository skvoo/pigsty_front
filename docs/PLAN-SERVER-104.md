# План использования сервера БД 104.223.25.234

**Сервер:** RackNerd VPS 104.223.25.234  
**Дата сводки:** 15 февраля 2026  
**Цель:** единый план по UI, соединениям, бэкапам, безопасности и развёртыванию инфраструктуры.

**Принцип развёртывания:** всё разворачиваем **со стороны Pigsty**, по официальным инструкциям Pigsty (pigsty.io/docs). Docker, приложения (PgAdmin, Supabase Studio и т.д.) — через плейбуки `./docker.yml`, `./app.yml` и конфиг в `pigsty.yml`. Ручная установка сервисов мимо Pigsty не используется.

---

## 1. Что мы хотим (кратко)

- **БД:** миграция с Supabase Cloud на Pigsty; одна точка данных для приложений.
- **Фронт:** гибрид — Auth (OAuth) в Supabase Cloud, **данные приложения** в Pigsty (БД `app` и др.) через наш бэкенд.
- **UI для админов и разработчиков:** портал Pigsty (Grafana, метрики), при необходимости PgAdmin и/или Supabase Studio.
- **Бэкапы:** локально pgBackRest + вынос копии на сервер 107.175.134.104 по SSH/rsync.
- **Доступ к БД:** сейчас БД `app` открыта для теста (доступ с любого IP). Планируем **DENY ALL** и явный **allowlist** — прописывать только те источники, с которых разрешено подключаться (бэкенды, админские IP).
- **Безопасность:** разворачиваем **в конце**, когда будет понятно, какие порты реально нужны (UFW, HTTPS, SSH root и т.д.).
- **Мониторинг:** Pigsty (Prometheus + Grafana + Alertmanager), оповещения в Email/Telegram при нехватке ресурсов.

---

## 2. Текущее состояние сервера (проверка 15.02.2026)

| Параметр | Значение |
|----------|----------|
| ОС | Ubuntu, ядро 6.8.0-31-generic, x86_64 |
| Хост | racknerd-cd14e40 |
| Диск | 135 GB всего, ~7.6 GB занято, **~121 GB свободно** |
| SSH-пользователь | `st` (passwordless SSH + sudo) |
| Pigsty | `~/pigsty`, конфиг `pigsty.yml` на месте |

### Сервисы

| Сервис | Статус | Порт(ы) |
|--------|--------|---------|
| Patroni (PostgreSQL) | active | 5432, 5433, 5434, 5436, 5438 |
| PgBouncer | active | **6432** (доступен с 0.0.0.0) |
| Nginx | слушает | **80, 443** |
| Grafana | слушает | **3000** |
| etcd | слушает | 2379, 2380 |
| Node/PG exporters, Alertmanager и др. | по конфигу | 9100, 9094, 8008, 8686, 8880 и т.д. |

### Базы и доступ

- **БД `app`:** есть, подключение через PgBouncer (6432) с `dbuser_app` проверено.
- **pg_backup:** cron у пользователя `postgres`: `00 01 * * * /pg/bin/pg-backup full` (ежедневно в 01:00).
- **Репозиторий бэкапов:** `/pg/backup` → симлинк на `/data/backups/pg-meta-17/backup`.

### Безопасность (план — в конце)

Сейчас не включаем: пока нечего защищать, по ходу станет ясно, какие порты нужны. Потом: UFW (allow только нужные порты и IP), HTTPS для портала, отключение SSH root. См. раздел 6 и чеклист в конце.

### Docker

- В конфиге Pigsty: `docker_enabled: true`, приложение pgadmin в `apps`. На сервере при проверке Docker не вызывался от пользователя `st` (возможно, нужен `sudo docker` или группа docker). PgAdmin по плану: `http://104.223.25.234:8885` (admin@pigsty.cc / pigsty) — при необходимости развернуть через `./app.yml`.

---

## 3. UI (веб-интерфейсы)

| UI | URL | Назначение | Документ |
|----|-----|------------|----------|
| **Портал Pigsty (Nginx)** | http://104.223.25.234/ или https://104.223.25.234/ (после включения SSL) | Единая точка входа: Grafana, метрики, логи. Basic Auth: пользователь `admin`, пароль из `nginx_users` в pigsty.yml | SECURITY-PORTAL.md |
| **Grafana** | Через портал (прокси) или напрямую :3000 | Дашборды PostgreSQL, ноды, алерты | SERVER-MONITORING-ALERTING.md |
| **PgAdmin** | http://104.223.25.234:8885 | Управление БД (опционально, через Docker app) | pigsty.yml → apps.pgadmin |
| **Supabase Studio** | http://104.223.25.234:8000 (если развернём) | Создание таблиц, миграции, работа с данными для фронтендеров | SUPABASE-STUDIO-PIGSTY.md |

Итог: основной UI — портал (Nginx) с Basic Auth; после включения HTTPS — доступ по https://104.223.25.234/. Остальные UI (Grafana, PgAdmin, Studio) — по необходимости и с ограничением доступа (UFW, VPN, те же Basic Auth).

---

## 4. Соединения к БД

| Кто | Куда | Строка / параметры |
|-----|------|---------------------|
| **Бэкенд приложения (Next.js, Vercel и т.д.)** | PgBouncer 6432, БД `app` | `postgresql://dbuser_app:ПАРОЛЬ@104.223.25.234:6432/app` (пароль в pigsty.yml → pg_users → dbuser_app) |
| **Админские задачи, миграции** | PostgreSQL 5432, БД `app` (или postgres) | `postgresql://dbuser_app:ПАРОЛЬ@104.223.25.234:5432/app` или postgres (в allowlist — только доверенные IP) |
| **Supabase Studio (вариант B)** | PostgreSQL 5432 с хоста/Docker | POSTGRES_HOST=host.docker.internal, порт 5432, пользователь с правами на БД |

Тестовый пароль `dbuser_app` (только для теста): см. TEST-OPEN-DB.md; в проде — сменить и хранить в секретах.

### Стратегия доступа: DENY ALL + allowlist

- **Сейчас:** БД `app` развёрнута для теста и **доступна с любого IP** (в конфиге `pgb_hba_rules`: `addr: world` для `dbuser_app`/`app`).
- **План:** перейти на **DENY ALL** и явно прописывать, **откуда** можно подключаться:
  - Убрать правило с `addr: world`.
  - Добавить в `pgb_hba_rules` только правила с конкретными адресами/подсетями (IP бэкендов, например Vercel outbound IP или IP вашего сервера приложений; админские IP для 5432/6432).
  - На уровне фаервола (UFW) при включении безопасности: разрешать 6432/5432 только с этих же IP (опционально, для двойной защиты).

Когда будете готовы ввести allowlist — в `pigsty.yml` в секции кластера `pg-meta` заменить текущее правило на список, например:

```yaml
# Было (открыто для теста):
# pgb_hba_rules:
#   - { user: dbuser_app ,db: app ,addr: world ,auth: pwd ,title: 'app user from internet' ,order: 100 }

# Станет (DENY ALL + allowlist):
pgb_hba_rules:
  - { user: dbuser_app ,db: app ,addr: 1.2.3.4/32     ,auth: pwd ,title: 'app backend server 1' ,order: 100 }
  - { user: dbuser_app ,db: app ,addr: 5.6.7.8/32     ,auth: pwd ,title: 'Vercel outbound (пример)' ,order: 101 }
  # добавить остальные доверенные IP/CIDR
  # правило с addr: intra оставить для локального доступа с самого сервера, если нужно
```

После правки применить плейбук PgBouncer (или pgsql), перезапуск pgbouncer подхватит новый HBA. Аналогично для прямого доступа к PostgreSQL (порт 5432): в `pg_hba_rules` указывать только доверенные IP.

---

## 5. План бэкапов

| Уровень | Что | Где | Документ |
|---------|-----|-----|----------|
| **Локально на 104.223.25.234** | pgBackRest full (ежедневно в 01:00) | `/pg/backup` → `/data/backups/pg-meta-17/backup` | pigsty.yml, PLAN.md |
| **Внешняя копия** | Копирование репозитория бэкапов на другой сервер | Сервер **107.175.134.104** (rsync по SSH с 104.223.25.234) | PLAN.md п. 4.5, BACKUP-TO-SERVER-SSH.md (адаптировать под /pg/backup) |

Чеклист по бэкапам:

- [ ] Убедиться, что cron `00 01 * * * /pg/bin/pg-backup full` выполняется и в `/data/backups/pg-meta-17/backup` появляются полные бэкапы.
- [ ] Настроить с 104.223.25.234 SSH-ключ на 107.175.134.104 и cron/скрипт: rsync (или аналог) каталога `/pg/backup` (или соответствующего реального пути) на 107.175.134.104 в выбранный каталог (например `/backup/pigsty-db/current/`).
- [ ] Провести тестовое восстановление из бэкапа.

---

## 6. Безопасность (разворачиваем в конце)

Пока не включаем: станет ясно, какие порты и сервисы реально нужны. Когда понадобится:

- **Доступ к БД:** перейти на **DENY ALL + allowlist** (раздел 4): убрать `addr: world`, прописать в `pgb_hba_rules` и при необходимости в `pg_hba_rules` только доверенные IP (бэкенды, админ).
- **UFW:** включить; разрешать только нужные порты (22, 80, 443 и при необходимости 6432/5432 только с IP из allowlist).
- **Портал:** Basic Auth уже есть; при необходимости HTTPS: `nginx_sslmode: enable` в pigsty.yml, применить `infra.yml -t nginx`. См. SECURITY-PORTAL.md.
- **SSH:** `PermitRootLogin no` в sshd_config после проверки входа под `st`.
- **Секреты:** не коммитить pigsty.yml с паролями в публичный репо; в проде — секреты в переменных/менеджере.

Подробно: docs/SECURITY-PORTAL.md, раздел 4.1 в docs/PLAN.md.

---

## 7. Мониторинг и оповещения

- **Стек:** Prometheus + Grafana + Alertmanager (уже на сервере).
- **Действия:** добавить правила алертов (диск, RAM, CPU), настроить Alertmanager на Email и Telegram. Добавить другие серверы в инвентарь и node_exporter при необходимости.
- Документ: SERVER-MONITORING-ALERTING.md.

---

## 8. Сводный чеклист развёртывания

### Конфигурация и БД

- [ ] Зафиксировать в pigsty.yml retention для pgBackRest при необходимости.
- [ ] БД `app` — тестовая; после перехода на новые БД под проекты **закрыть или удалить** (убрать из приложений, затем из конфига или ограничить доступ). Новые БД создавать под каждый проект (через pigsty.yml или SQL).
- [ ] Когда появятся финальные источники подключений — перейти на **DENY ALL + allowlist**: убрать `addr: world`, прописать в `pgb_hba_rules` только доверенные IP (раздел 4).

### Фронт и гибрид

- [ ] Бэкенд: DATABASE_URL на 104.223.25.234:6432, endpoint типа `/api/news` к БД `app`.
- [ ] Фронт: загрузка новостей через fetch('/api/news'), Auth — без изменений (Supabase).

### Бэкапы

- [ ] Проверить выполнение ежедневного pg-backup и наличие данных в `/pg/backup`.
- [ ] Настроить вынос копии на 107.175.134.104 (rsync по SSH, cron).
- [ ] Тестовое восстановление.

### UI и доп. сервисы

- [ ] Проверить доступ к порталу (http://104.223.25.234) с Basic Auth.
- [ ] При необходимости: развернуть PgAdmin или Supabase Studio **через Pigsty** — `./docker.yml -l app`, затем `./app.yml`; конфиг в `pigsty.yml`. См. [INSTALL-SUPABASE-STUDIO.md](./INSTALL-SUPABASE-STUDIO.md), [SUPABASE-STUDIO-PIGSTY.md](./SUPABASE-STUDIO-PIGSTY.md).

### Мониторинг

- [ ] Настроить правила алертов и Alertmanager (Email/Telegram) по SERVER-MONITORING-ALERTING.md.

### Безопасность (в конце)

- [ ] Собрать список нужных портов и IP для allowlist (бэкенды, админ, портал).
- [ ] DENY ALL + allowlist для БД: заменить в pigsty.yml `addr: world` на правила с конкретными IP, применить плейбук.
- [ ] Включить UFW: разрешить только нужные порты и при необходимости 6432/5432 только с allowlist.
- [ ] **Basic Auth для портала:** при открытии http://104.223.25.234 запрос логина/пароля не появляется; включить/проверить в Nginx (auth_basic, nginx_users в pigsty.yml), применить `infra.yml -t nginx`. См. SECURITY-PORTAL.md.
- [ ] Включить HTTPS для Nginx при необходимости: `nginx_sslmode: enable` → `infra.yml -t nginx`.
- [ ] Отключить SSH root: `PermitRootLogin no`, reload sshd.

---

## 9. Ссылки на документы

| Документ | Содержание |
|----------|------------|
| [PLAN.md](./PLAN.md) | Детальный план миграции, чеклисты, открытые вопросы |
| [SECURITY-PORTAL.md](./SECURITY-PORTAL.md) | HTTPS, UFW, SSH, Basic Auth для портала |
| [FRONTEND-INTEGRATION.md](./FRONTEND-INTEGRATION.md) | Подключение фронта к БД app |
| [TEST-OPEN-DB.md](./TEST-OPEN-DB.md) | Тестовая строка подключения и API для новостей |
| [SUPABASE-STUDIO-PIGSTY.md](./SUPABASE-STUDIO-PIGSTY.md) | Supabase Studio на сервере, миграция из Cloud |
| [SERVER-MONITORING-ALERTING.md](./SERVER-MONITORING-ALERTING.md) | Мониторинг серверов, алерты Email/Telegram |
| [BACKUP-TO-SERVER-SSH.md](./BACKUP-TO-SERVER-SSH.md) | Общая схема rsync/SSH на другой сервер (адаптировать под Pigsty) |

---

После сверки этого плана можно по шагам выполнять чеклист: конфиг и БД, фронт/гибрид, бэкапы, UI, мониторинг; **безопасность (UFW, HTTPS, DENY ALL + allowlist) — в конце**, когда будет понятно, какие порты и источники нужны.
