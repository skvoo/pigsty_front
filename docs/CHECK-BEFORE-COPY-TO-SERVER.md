# Проверка перед копированием конфига на сервер

Перед выполнением `scp pigsty.yml st@104.223.25.234:~/pigsty/` или применением плейбуков — убедиться, что не затираем важные отличия на сервере.

---

## 1. Что проверить на сервере

Подключиться: `ssh st@104.223.25.234`

### 1.1 Наличие и размер конфига

```bash
ls -la ~/pigsty/pigsty.yml
wc -l ~/pigsty/pigsty.yml
```

### 1.2 Критичные секции (сравнить с репо)

**Базы данных (pg_databases):**

```bash
sed -n '/pg_databases:/,/pg_hba_rules/p' ~/pigsty/pigsty.yml | head -35
```

Убедиться: список БД (meta, app, supabase, td, gdloungedb, imperialdb и т.д.) и комментарии соответствуют ожидаемым.

**Правила доступа (pg_hba_rules, pgb_hba_rules):**

```bash
sed -n '/pg_hba_rules:/,/pg_crontab/p' ~/pigsty/pigsty.yml
```

Проверить: нет ли правил, добавленных только на сервере (другие IP, пользователи).

**MinIO (бакеты и пользователи):**

```bash
sed -n '/# MINIO/,/minio_users:/p' ~/pigsty/pigsty.yml
sed -n '/minio_users:/,/^    [a-z]/p' ~/pigsty/pigsty.yml | head -25
```

**Глобальные переменные (пароли, admin_ip, nginx):**

```bash
grep -E 'admin_ip|pg_admin_password|nginx_users|minio_secret' ~/pigsty/pigsty.yml
```

Убедиться: пароли и IP не перезаписываются случайно другими значениями из репо.

### 1.3 Контрольная сумма (опционально)

```bash
md5sum ~/pigsty/pigsty.yml
```

Локально (PowerShell):  
`(Get-FileHash -Path .\pigsty.yml -Algorithm MD5).Hash`

Если суммы **совпадают** — файл на сервере уже совпадает с репо, копировать не нужно.

---

## 2. Если на сервере есть свои правки

- **Не перезаписывать** весь файл: скопировать конфиг в резервную копию на сервере (`cp ~/pigsty/pigsty.yml ~/pigsty/pigsty.yml.bak.$(date +%Y%m%d)`), затем вручную перенести нужные фрагменты из репо (например, только секцию `minio` или только `pg_databases`).
- Либо скопировать репо-файл под другим именем (`pigsty.yml.new`), сравнить `diff ~/pigsty/pigsty.yml ~/pigsty/pigsty.yml.new` и вручную смержить отличия.

---

## 3. Результат проверки 24.02.2026

| Проверка | Результат |
|----------|------------|
| pigsty.yml на сервере | 319 строк, 18937 байт |
| pg_databases | meta, app, supabase, td, gdloungedb, imperialdb — как в репо |
| pg_hba_rules, pgb_hba_rules | Совпадают с репо (Docker, intra, dbuser_app, void, tdadmin) |
| minio_buckets / minio_users | Совпадают (в т.ч. gd-lounge-assets, imperial-*) |
| MD5 сервер vs репо | Совпадают (611ed0d88c75b349303b297ef2166658) |

**Вывод:** конфиг на сервере и в репо идентичны. Копирование не требуется; при изменении репо — повторить проверку (diff или MD5) перед следующим `scp`.

---

## 4. После успешной проверки: применить MinIO

Если проверка пройдена и конфиг совпадает, на сервере нужно применить плейбук MinIO (создаст бакеты и пользователей для GD-lounge и imperial):

**Вариант А — по SSH вручную:**

```bash
ssh st@104.223.25.234
cd ~/pigsty && ./minio.yml -l minio
```

**Вариант Б — скрипт с локальной машины:**

```powershell
scp scripts/apply_minio_on_server.sh st@104.223.25.234:~/
ssh st@104.223.25.234 "chmod +x ~/apply_minio_on_server.sh && ~/apply_minio_on_server.sh"
```

После выполнения проверить: консоль MinIO (http://104.223.25.234:9001) — должны быть бакеты `gd-lounge-assets`, `imperial-*`. Дальше: перенос файлов Storage по [STORAGE-MIGRATION-SUPABASE-TO-MINIO.md](./STORAGE-MIGRATION-SUPABASE-TO-MINIO.md).
