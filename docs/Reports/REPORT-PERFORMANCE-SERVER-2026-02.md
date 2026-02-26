# Отчёт: настройки и производительность сервера Pigsty (104.223.25.234)

**Дата проверки:** 15 февраля 2026 (повторная проверка ~09:50 UTC)  
**Способ проверки:** подключение по SSH (пользователь `st`), сбор данных с хоста.

---

## 1. Ресурсы сервера

| Параметр | Значение |
|----------|----------|
| **Хост** | racknerd-cd14e40 |
| **ОС** | Linux 6.8.0-31-generic (Ubuntu), x86_64 |
| **Uptime** | 15 дней 21 ч 35 мин |
| **CPU** | 4 ядра, Intel Xeon E5-2699 v4 @ 2.20 GHz |
| **RAM** | 5.8 GiB всего |
| **Диск /** | 135 GB всего, **14 GB занято**, **115 GB свободно** (~11% использовано) |
| **Swap** | 3.0 GiB (использовано ~20 MiB) |

**Вывод по ресурсам:** Объёма RAM и диска достаточно для текущего набора сервисов. Запас по диску большой; по памяти — умеренный (used ~3.3 GiB, available ~2.5 GiB после стабилизации контейнеров Supabase).

---

## 2. Загрузка системы

| Метрика | Значение (повторная проверка) |
|---------|------------------------------|
| Load average (1 / 5 / 15 мин) | **0.77** / **1.38** / **1.87** |

Нагрузка снизилась по сравнению с первой проверкой (1.24 / 2.34 / 2.36). При 4 ядрах текущие значения указывают на умеренную загрузку; пики дают Logflare, VictoriaMetrics, Docker и приложения Supabase.

---

## 3. Настройки Pigsty и ключевых компонентов

### 3.1 Конфигурация

| Элемент | Значение / статус |
|---------|-------------------|
| **Конфиг** | `~/pigsty/pigsty.yml` на сервере |
| **Версия Pigsty** | v4.0.0 (из конфига) |
| **Кластер PGSQL** | pg-meta, один узел, роль primary (104.223.25.234) |
| **Инфра** | Один узел infra (104.223.25.234), repo_enabled: false |
| **ETCD** | Один узел, кластер etcd |
| **Node tune** | oltp (глобально в конфиге) |
| **Pg conf** | oltp.yml |

Содержимое `pigsty.yml` на сервере совпадает с репозиторием по ключевым параметрам (хосты, pg_users, pg_databases, pgb_hba_rules, pg_crontab, инфра, etcd, приложения). Расхождения только в комментариях/подписи правил PgBouncer (см. [REPORT-CHECK-2026-02.md](REPORT-CHECK-2026-02.md)).

### 3.2 PostgreSQL (Patroni)

| Параметр | Значение |
|----------|----------|
| **Версия** | 17.7 (Ubuntu 17.7-3.pgdg24.04+1) |
| **shared_buffers** | 1482 MB |
| **work_mem** | 64 MB |
| **max_connections** | 500 |
| **effective_cache_size** | 4444 MB |
| **maintenance_work_mem** | 371 MB |

Настройки соответствуют профилю OLTP для данной машины (около 6 GB RAM).

### 3.3 Бэкапы

- **Cron (postgres):** `00 01 * * * /pg/bin/pg-backup full` — ежедневный полный бэкап в 01:00.
- Репозиторий: локальный (pgBackRest), путь по конфигу — `/pg/backup`.

### 3.4 Сервисы systemd (ключевые)

Все перечисленные сервисы в состоянии **active (running)**:

| Сервис | Назначение |
|--------|------------|
| patroni.service | PostgreSQL (HA) |
| pgbouncer.service | Пул соединений (порт 6432) |
| nginx.service | Портал, прокси (80, 443) |
| grafana-server.service | Дашборды (3000) |
| etcd.service | Кластер etcd (2379, 2380) |
| alertmanager.service | Оповещения |
| node_exporter.service | Метрики ОС (9100) |
| pg_exporter.service, pgbouncer_exporter.service | Метрики PG/PgBouncer |
| vmetrics.service | VictoriaMetrics (8428) |
| vmalert.service | Правила алертов |
| vlogs.service | VictoriaLogs (9428) |
| vector.service | Сбор логов |
| docker.service | Контейнеры (PgAdmin, Supabase) |

Всего на сервере в состоянии running — около 40 юнитов (включая системные).

---

## 4. Производительность: нагрузка от запущенных сервисов

### 4.1 Использование RAM (топ процессов, повторная проверка)

| Процесс | % MEM | Примерно RSS | Назначение |
|---------|-------|--------------|------------|
| **logflare** (beam.smp) | 10.3% | ~629 MB | Supabase Logflare (аналитика) |
| **victoria-metrics** | 5.6% | ~345 MB | Хранение метрик (Prometheus-совместимый API) |
| **next-server** (Supabase Studio) | 3.7% | ~229 MB | Supabase Studio (Next.js) |
| **realtime** (beam.smp) | 3.6% | ~223 MB | Supabase Realtime (Elixir) |
| **gunicorn (PgAdmin)** | 3.3% + 1.8% | ~204 + 111 MB | PgAdmin (два воркера) |
| **GoTrue** (node) | 2.6% | ~161 MB | Supabase Auth |
| **grafana-server** | 2.3% | ~143 MB | Grafana |
| **postgres** (основной + checkpointer) | 2.3% + 1.7% | ~141 + 104 MB | PostgreSQL |
| **node (Supabase)** | 2.1% | ~130 MB | Edge Functions (Node) |
| **victoria-logs** | 1.9% | ~119 MB | Логи |
| **dockerd** | 1.9% | ~119 MB | Docker daemon |
| **nginx** (воркеры ×4) | ~1.6% × 4 | ~99 MB каждый | Nginx |

Ориентировочно перечисленные процессы дают порядка **~3+ GB** RSS. Текущее использование **~3.3 GB used**, **~2.5 GB available**. После стабилизации Supabase-контейнеров (rest, storage, auth) нагрузка по CPU снизилась; по памяти запас умеренный — при росте нагрузки стоит следить за RAM.

### 4.2 Сеть (слушающие порты)

Основные порты:

| Порт | Служба / приложение |
|------|----------------------|
| 22 | SSH |
| 53 | dnsmasq (Pigsty), systemd-resolved |
| 80, 443 | Nginx (портал) |
| 3000 | Grafana |
| 4000 | Logflare (Supabase) |
| 5432–5438 | PostgreSQL (Patroni: 5432, 5433, 5434, 5436, 5438) |
| 6432 | PgBouncer (доступ с 0.0.0.0) |
| 8000 | Kong (Supabase API) |
| 8428 | VictoriaMetrics |
| 8885 | PgAdmin (Docker) |
| 9094 | Alertmanager |
| 9100 | Node exporter |
| 9428 | VictoriaLogs |

Остальные порты (8686, 8008, 8880, 9115, 9113, 9059, 9323, 9598, 9630, 9631, 9854 и т.д.) относятся к экспортерам, внутренним сервисам Pigsty и Supabase.

### 4.3 Docker-контейнеры (Supabase + PgAdmin)

| Контейнер | Статус (повторная проверка) | Примечание |
|-----------|-----------------------------|------------|
| pgadmin | Up | PgAdmin 4, порт 8885 |
| supabase-kong | Up (healthy) | API Gateway |
| supabase-storage | **Up (healthy)** | Исправлено (пользователь и права в PG) |
| supabase-rest (PostgREST) | **Up** | Исправлено (роль authenticator в PG) |
| supabase-meta | Up (healthy) | Метаданные |
| realtime-dev.supabase-realtime | Up (unhealthy) | Работает; health check возвращает 403 (Kong/JWT) |
| supabase-edge-functions | Up | Edge Runtime |
| supabase-studio | Up (healthy) | Studio (Next.js) |
| supabase-auth (GoTrue) | **Up (healthy)** | Исправлено (миграции auth в PG) |
| supabase-imgproxy | Up (healthy) | Изображения |
| supabase-vector | Up (healthy) | Логи/вектор |
| supabase-analytics (logflare) | Up (healthy) | Аналитика |

После исправлений (см. [SUPABASE-CONTAINERS-FIX-2026-02.md](SUPABASE-CONTAINERS-FIX-2026-02.md)) контейнеры **supabase-rest**, **supabase-storage** и **supabase-auth** работают стабильно. **Realtime** запущен, но health check помечен как unhealthy из‑за 403 на эндпоинте проверки.

---

## 5. Сводка: производительность против сервисов

| Критерий | Оценка (повторная проверка) | Комментарий |
|----------|----------------------------|-------------|
| **CPU** | Умеренная | Load 0.77 / 1.38 / 1.87 на 4 ядра; после исправления контейнеров нагрузка снизилась. |
| **RAM** | В пределах нормы | ~3.3 GB used, ~2.5 GB available; крупнейшие потребители — Logflare, VictoriaMetrics, Studio, Realtime, PgAdmin, GoTrue, PostgreSQL. Запас есть, мониторинг желателен. |
| **Диск** | Запас большой | 11% использовано (14 GB из 135 GB). Место для бэкапов и логов достаточное. |
| **Сервисы Pigsty** | Работают | Patroni, PgBouncer, Nginx, Grafana, etcd, экспортеры, VictoriaMetrics, Alertmanager — active. |
| **Приложения** | Почти все работают | PgAdmin и Supabase: Kong, Studio, meta, storage, rest, auth, edge, imgproxy, vector, logflare — **healthy** или Up; realtime — Up, health 403. |

---

## 6. Рекомендации

1. **Supabase:** Контейнеры rest, storage и auth исправлены (см. [SUPABASE-CONTAINERS-FIX-2026-02.md](SUPABASE-CONTAINERS-FIX-2026-02.md)). Опционально: разобрать 403 на health check Realtime (Kong/JWT) при необходимости.
2. **Мониторинг:** Использовать уже настроенный стек (Grafana, VictoriaMetrics, алерты) и при необходимости добавить правила на высокую загрузку CPU/RAM и мало свободного места (см. [SERVER-MONITORING-ALERTING.md](../SERVER-MONITORING-ALERTING.md)).
3. **Конфиг:** При желании полного совпадения с репо — скопировать актуальный `pigsty.yml` из репозитория в `~/pigsty/pigsty.yml` на сервере (см. [REPORT-CHECK-2026-02.md](REPORT-CHECK-2026-02.md)).
4. **Безопасность:** По плану ([PLAN-SERVER-104.md](../PLAN-SERVER-104.md)) — позже ограничить доступ к PgBouncer (allowlist вместо world), включить Basic Auth/HTTPS для портала, при необходимости UFW.

---

*Отчёт составлен по данным, собранным с 104.223.25.234 по SSH (пользователь `st`). Обновлён при повторной проверке 15.02.2026.*
