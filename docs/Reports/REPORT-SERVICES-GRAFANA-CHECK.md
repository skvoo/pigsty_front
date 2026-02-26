# Проверка сервисов и Grafana на 104.223.25.234

**Дата проверки:** 23.02.2026

## 1. Системные сервисы (systemd)

Все ключевые сервисы Pigsty в состоянии **active**, failed-юнитов нет.

| Сервис | Статус |
|--------|--------|
| alertmanager | active |
| etcd | active |
| grafana-server | active |
| haproxy | active |
| minio | active |
| nginx | active |
| nginx_exporter | active |
| node_exporter | active |
| patroni | active |
| pg_exporter | active |
| pgbackrest_exporter | active |
| pgbouncer | active |
| pgbouncer_exporter | active |
| vector | active |
| vmalert | active |
| vmetrics | active |

## 2. Порты (слушают)

| Порт | Назначение |
|------|------------|
| 80, 443 | Nginx |
| 3000 | Grafana |
| 5432 | PostgreSQL |
| 6432 | PgBouncer |
| 8000 | Supabase Studio |
| 8008 | Patroni (внутр.) |
| 8428 | VictoriaMetrics |
| 8880 | VMAlert |
| 9000, 9001 | MinIO API / Console |
| 9059 | Alertmanager |
| 9100 | node_exporter |
| 9113 | nginx_exporter |
| 9115 | blackbox_exporter |
| 9428 | VictoriaLogs |
| 2379 | etcd |

## 3. Цели скрапа VictoriaMetrics (up = 1)

Все **23 цели** в состоянии up.

| Job | Цели (instance) |
|-----|------------------|
| etcd | 104.223.25.234:2379 |
| infra | vtraces, grafana, vmetrics, vmalert, alertmanager, nginx, blackbox, vlogs |
| minio | 104.223.25.234:9000 |
| node | pg-meta-1 (9100, 9101, 9323, 9598), 107.175.134.104:9100, 172.245.64.199:9100 |
| pgsql | pg-meta-1 (8008, 9630, 9631, 9854) |
| ping | 104.223.25.234, 107.175.134.104, 172.245.64.199 |

## 4. Grafana

- **Health:** OK (database ok, version 12.3.1)
- **HTTP:** 200 на `/api/health`

### Источники данных (datasources)

| Имя | Тип | Назначение |
|-----|-----|------------|
| Metrics | Prometheus | default, VM 8428 |
| Logs | VictoriaLogs | 9428 |
| Meta | PostgreSQL | meta, dbuser_view |
| pg-meta-1.* | PostgreSQL | postgres, meta, app, td (dbuser_monitor) |
| vmetrics-1 | Prometheus | VM по IP |
| vlogs-1 | VictoriaLogs | логи по IP |
| vtraces-1 | Jaeger | трейсы |
| Traces | Jaeger | 10428 |
| Static | Business Input | статика |

## 5. Итог

- Сервисы: все работают, отказов нет.
- Скрап: все 23 цели отдают метрики (up=1).
- Grafana: доступна, источники данных настроены, дашборды (PGSQL, Node, MinIO, Infra, etc.) должны отображать данные.

При необходимости дашборды: **Dashboards** → поиск по PGSQL, Node, MinIO Overview, Infra.
