# Runbook: восстановление Patroni и PostgreSQL на сервере Pigsty

**Сервер:** 104.223.25.234  
**Когда использовать:** Patroni в статусе `active`, но подключение к Postgres даёт `FATAL: the database system is shutting down` или узел в роли Replica / состоянии `starting`.

---

## Причина

По выводу `patronictl list` узел **pg-meta-1** может быть в роли **Replica**, состояние **starting**, тег **clonefrom: true**. Кластер развёрнут как реплика (ожидается primary для клонирования). В одноподной конфигурации primary нет, поэтому узел бесконечно остаётся в «starting» и не принимает подключения.

Либо Patroni/Postgres могли упасть по другой причине (OOM, диск, перезагрузка) — ниже шаги и диагностика.

---

## 1. Диагностика (на сервере по SSH)

Подключиться: `ssh st@104.223.25.234` (или ваш пользователь с sudo).

### 1.1 Статус сервисов

```bash
sudo systemctl status patroni
```

Ожидается: `active (running)`. Если `inactive` или `failed` — см. раздел 3.

### 1.2 Состояние кластера Patroni

```bash
sudo -iu postgres patronictl -c /pg/bin/patroni.yml list
```

Интерпретация:

| Роль     | Состояние  | Действие |
|----------|------------|----------|
| Leader   | running    | Всё ок, Postgres должен принимать подключения |
| Replica  | starting   | Узел ждёт primary для клонирования → нужен **перевод в primary** (раздел 2) |
| Replica  | running    | Нормально для реплики; на single-node так быть не должно |
| -        | (пусто/ошибка) | Проверить etcd и логи Patroni |

### 1.3 Проверка подключения к Postgres

```bash
sudo -iu postgres psql -h 127.0.0.1 -p 5432 -d postgres -c 'SELECT version();'
```

Если ошибка `FATAL: the database system is shutting down` или таймаут — Postgres не в рабочем состоянии, нужны шаги из раздела 2 или 3.

### 1.4 Проверка признака standby

```bash
ls -la /pg/data/standby.signal 2>/dev/null && echo "Present: instance is standby" || echo "No standby.signal"
```

Если файл есть и узел должен быть единственным primary — его нужно убрать при переводе в primary (раздел 2).

---

## 2. Перевод единственного узла в primary (Replica → Leader)

Выполнять **только на single-node** кластере pg-meta, когда узел застрял в роли Replica / starting.

### 2.1 Остановить Patroni

```bash
sudo systemctl stop patroni
```

Дождаться полной остановки (проверить: `sudo systemctl status patroni` → inactive).

### 2.2 Перевести данные Postgres в режим primary

Каталог данных в Pigsty: `/pg/data`. Один из вариантов:

**Вариант A — удалить standby.signal (рекомендуется):**

```bash
sudo -u postgres rm -f /pg/data/standby.signal
```

**Вариант B — promote через pg_ctl:**

```bash
sudo -u postgres /usr/lib/postgresql/17/bin/pg_ctl promote -D /pg/data
```

(Путь к `pg_ctl` может отличаться: проверьте `which pg_ctl` от пользователя `postgres` или `ls /usr/lib/postgresql/*/bin/pg_ctl`.)

### 2.3 Запустить Patroni

```bash
sudo systemctl start patroni
```

### 2.4 Проверить

```bash
# Через 5–10 секунд
sudo -iu postgres patronictl -c /pg/bin/patroni.yml list
```

Ожидается: роль **Leader**, состояние **running**.

```bash
sudo -iu postgres psql -h 127.0.0.1 -p 5432 -d postgres -c 'SELECT version();'
```

Должна вернуться строка с версией PostgreSQL.

---

## 3. Если Patroni не запускается или падает

### 3.1 Логи

```bash
sudo journalctl -u patroni -n 100 --no-pager
```

Искать ошибки: etcd, конфиг, права на `/pg/data`, нехватка памяти.

### 3.2 Зависимости: etcd

Patroni использует etcd для DCS. Проверить:

```bash
sudo systemctl status etcd
```

Если etcd не запущен — сначала поднять etcd, затем Patroni.

### 3.3 Запуск только Postgres (без Patroni), если нужно срочно

Только для экстренного доступа к данным:

```bash
sudo systemctl stop patroni
sudo -u postgres rm -f /pg/data/standby.signal
sudo -u postgres /usr/lib/postgresql/17/bin/pg_ctl start -D /pg/data -l /tmp/pg.log
```

После проверки доступа к БД лучше снова перейти на управление через Patroni: остановить pg_ctl, запустить `sudo systemctl start patroni`.

---

## 4. После восстановления Postgres

- Создать недостающие БД (например, для миграции):

  ```bash
  cd ~/pigsty
  ./pgsql-db.yml -l pg-meta -e dbname=gdloungedb
  ./pgsql-db.yml -l pg-meta -e dbname=imperialdb
  ```

  Либо скрипт: `sudo -u postgres bash -s < scripts/ensure_migration_dbs.sh` (скопировать скрипт на сервер при необходимости).

- Проверить PgBouncer: `ss -tuln | grep 6432` и подключение через порт 6432.

---

## Связанные документы

- [REPORT-PIGSTY-CHECK-2026-02-24.md](Reports/REPORT-PIGSTY-CHECK-2026-02-24.md) — описание проблемы «Replica / starting».
- [MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md](MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md) — создание БД и миграция.
- [PLAN-SERVER-104.md](PLAN-SERVER-104.md) — план сервера и сервисов.
