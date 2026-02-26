# Бэкап сервера 172.245.64.199 на другой сервер по SSH

> **Важно:** этот документ про сервер **172.245.64.199** (n8n / racknerd-ffaf464), не про Pigsty 104.223.25.234. Для выноса бэкапов с 104 см. docs/PLAN-SERVER-104.md (§ бэкапы).

Сервер-источник: **racknerd-ffaf464** (172.245.64.199), AlmaLinux 8.9, ~69 ГБ данных.  
Бэкап-сервер: **107.175.134.104** (~108 ГБ свободно).

## Текущая конфигурация (актуально)

| Параметр | Значение |
|----------|----------|
| Режим | Ежедневный rsync, одна копия |
| Время запуска | **05:00** каждый день (cron) |
| Путь на бэкап-сервере | `/backup/racknerd/current/` |
| Лог на racknerd | `/var/log/rsync-backup.log` |
| Пример crontab | см. ниже в разделе «Cron» |

Проверка cron на racknerd: `crontab -l`

---

## Настройка ежедневного rsync (пошагово)

Используется **одна** копия на бэкап-сервере (`/backup/racknerd/current/`), которая каждый день обновляется. Объём ~65 ГБ.

### Шаг 1. На бэкап-сервере (107.175.134.104)

Зайдите по SSH на **107.175.134.104** и выполните:

```bash
# Каталог для приёма бэкапов (одна копия — current)
mkdir -p /backup/racknerd/current
# Права (если будет отдельный пользователь — поправьте)
chmod 700 /backup/racknerd
```

Дальше нужно принять SSH-ключ с сервера racknerd (см. шаг 3): после того как скопируете ключ с racknerd, добавьте его на бэкап-сервер в `~/.ssh/authorized_keys` пользователя `root`.

### Шаг 2. На сервере-источнике (racknerd, 172.245.64.199)

Зайдите по SSH на **172.245.64.199** и выполните по порядку.

**2.0. Установить rsync (если ещё не установлен):**

```bash
dnf install -y rsync
```

Если появляется ошибка репозитория netdata (404), отключите его и установите так:

```bash
dnf install -y rsync --disablerepo=netdata --disablerepo=netdata-repoconfig
# или отключить все репозитории netdata:
dnf install -y rsync --disablerepo='netdata*'
```

Чтобы netdata не мешал в будущем, можно отключить его репозитории:  
`for f in /etc/yum.repos.d/netdata*.repo; do [ -f "$f" ] && mv "$f" "$f.bak"; done`

**2.1. Ключ для входа на бэкап-сервер без пароля (обязательно для cron):**

```bash
test -f ~/.ssh/id_rsa || ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub
```

Скопируйте вывод одной строки (начинается с `ssh-rsa ...`). На бэкап-сервере **107.175.134.104** выполните (вставьте свою строку вместо `PASTE_PUBLIC_KEY`):

```bash
mkdir -p ~/.ssh
echo "PASTE_PUBLIC_KEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**2.2. Проверка входа без пароля (с racknerd):**

```bash
ssh root@107.175.134.104 "echo OK"
```

Должно вывести `OK` без запроса пароля.

**2.3. Первый полный rsync (займёт время, ~69 ГБ):**

```bash
BACKUP_SERVER="107.175.134.104"
BACKUP_USER="root"
BACKUP_PATH="/backup/racknerd/current"

rsync -avz -e ssh \
  --exclude='/dev' --exclude='/proc' --exclude='/sys' \
  --exclude='/tmp' --exclude='/run' --exclude='/var/cache' --exclude='/var/tmp' \
  --exclude='/backup' \
  --exclude='*.sock' \
  / \
  "${BACKUP_USER}@${BACKUP_SERVER}:${BACKUP_PATH}/"
```

Можно запустить с `--progress` для отображения прогресса: добавьте `--progress` после `rsync -avz`.

**2.4. Cron для ежедневного бэкапа (в 05:00, с логом):**

```bash
EDITOR=nano crontab -e
```

Добавьте строку (одна строка, без переноса):

```
0 5 * * * /usr/bin/rsync -az -e ssh --exclude='/dev' --exclude='/proc' --exclude='/sys' --exclude='/tmp' --exclude='/run' --exclude='/var/cache' --exclude='/var/tmp' --exclude='/backup' --exclude='*.sock' / root@107.175.134.104:/backup/racknerd/current/ >> /var/log/rsync-backup.log 2>&1
```

Сохраните (Ctrl+O, Enter) и выйдите (Ctrl+X). Лог на racknerd: `/var/log/rsync-backup.log`.

**Проверить задание:** `crontab -l`

### Шаг 3. Проверка после первого бэкапа

На бэкап-сервере **107.175.134.104**:

```bash
ls -la /backup/racknerd/current/
df -h /
```

Должны появиться каталоги `etc`, `root`, `home`, `var`, `usr` и т.д., занятое место вырастет примерно на 65 ГБ.

---

## Что нужно перед запуском (общая схема)

- **IP или hostname** бэкап-сервера
- **Пользователь** на бэкап-сервере (например `root` или `backup`)
- **Каталог** на бэкап-сервере для приёма бэкапов (например `/backup/racknerd`)

На бэкап-сервере один раз создайте каталог (подставьте свой путь):
```bash
mkdir -p /backup/racknerd
```

С сервера **racknerd** должно быть возможно подключение по SSH к бэкап-серверу (по ключу или по паролю).

---

## Вариант 1: rsync (рекомендуется)

Удобно для регулярных бэкапов: можно запускать по cron, передаются только изменения.

**На сервере racknerd (172.245.64.199)** выполните, подставив свои значения:

```bash
# Замените BACKUP_SERVER и USER на IP/хост и пользователя бэкап-сервера
BACKUP_SERVER="IP_ИЛИ_ХОСТ_БЭКАП_СЕРВЕРА"
BACKUP_USER="root"
BACKUP_PATH="/backup/racknerd"

# Полный бэкап важных каталогов (без /dev, /proc, временных и кэшей)
rsync -avz --progress -e ssh \
  --exclude='/dev' \
  --exclude='/proc' \
  --exclude='/sys' \
  --exclude='/tmp' \
  --exclude='/run' \
  --exclude='/var/cache' \
  --exclude='/var/tmp' \
  --exclude='*.sock' \
  /etc /root /home /var/www /var/lib/docker/volumes \
  "${BACKUP_USER}@${BACKUP_SERVER}:${BACKUP_PATH}/full-$(date +%Y%m%d)/"
```

Если нужно бэкапить весь корень `/`:

```bash
rsync -avz --progress -e ssh \
  --exclude='/dev' --exclude='/proc' --exclude='/sys' \
  --exclude='/tmp' --exclude='/run' --exclude='/var/cache' --exclude='/var/tmp' \
  --exclude='/backup' \
  / \
  "${BACKUP_USER}@${BACKUP_SERVER}:${BACKUP_PATH}/full-$(date +%Y%m%d)/"
```

При первом запуске запросит пароль от бэкап-сервера (если не настроен ключ).

---

## Вариант 2: tar-архив по SSH

Один сжатый файл на бэкап-сервере. Удобно для «снимка на дату».

**На сервере racknerd** (подставьте BACKUP_SERVER и BACKUP_USER):

```bash
BACKUP_SERVER="IP_ИЛИ_ХОСТ_БЭКАП_СЕРВЕРА"
BACKUP_USER="root"
BACKUP_PATH="/backup/racknerd"

tar czf - \
  --exclude='/var/cache' --exclude='/var/tmp' --exclude='/tmp' \
  /etc /root /home /var/www /var/lib/docker/volumes 2>/dev/null \
  | ssh "${BACKUP_USER}@${BACKUP_SERVER}" "cat > ${BACKUP_PATH}/racknerd-ffaf464-$(date +%Y%m%d).tar.gz"
```

Или бэкап всего корня (дольше, больше объём):

```bash
tar czf - \
  --exclude='/dev' --exclude='/proc' --exclude='/sys' \
  --exclude='/tmp' --exclude='/run' --exclude='/var/cache' --exclude='/var/tmp' \
  --exclude='/backup' \
  / 2>/dev/null \
  | ssh "${BACKUP_USER}@${BACKUP_SERVER}" "cat > ${BACKUP_PATH}/racknerd-full-$(date +%Y%m%d).tar.gz"
```

---

## SSH по ключу (без пароля)

Чтобы не вводить пароль при каждом бэкапе (и для cron):

**На сервере racknerd** один раз:

```bash
# Сгенерировать ключ (если ещё нет)
test -f ~/.ssh/id_rsa || ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

# Показать публичный ключ — его нужно добавить на бэкап-сервер
cat ~/.ssh/id_rsa.pub
```

На **бэкап-сервере** добавьте эту строку в `~/.ssh/authorized_keys` пользователя, под которым делается бэкап.

Проверка с racknerd:
```bash
ssh BACKUP_USER@BACKUP_SERVER "echo OK"
```

---

## Проверка после бэкапа

На бэкап-сервере **107.175.134.104** (текущая схема — одна копия `current`):

```bash
ls -la /backup/racknerd/current/
df -h /
```

На racknerd — просмотр лога последнего запуска:

```bash
tail -50 /var/log/rsync-backup.log
```

---

## Восстановление из бэкапа

Восстанавливать можно на тот же сервер (после сбоя) или на новый сервер (миграция). Команды выполняются **на том сервере, куда восстанавливаем** (целевой хост должен иметь SSH-доступ к бэкап-серверу или архив можно предварительно скопировать на него).

Подставьте свои: `BACKUP_SERVER`, `BACKUP_USER`, `BACKUP_PATH`, дату снимка `YYYYMMDD`.

### Восстановление из rsync-бэкапа

На **целевом сервере** (тот, куда восстанавливаем) — тянем данные с бэкап-сервера **в корень** `/`.

**Ежедневная копия (одна папка `current` на 107.175.134.104):**

```bash
BACKUP_SERVER="107.175.134.104"
BACKUP_USER="root"
BACKUP_PATH="/backup/racknerd/current"

# Восстановить весь корень из current
rsync -avz -e ssh "${BACKUP_USER}@${BACKUP_SERVER}:${BACKUP_PATH}/" /
```

**Если использовали снимки по датам (full-YYYYMMDD):**

```bash
BACKUP_SERVER="IP_БЭКАП_СЕРВЕРА"
BACKUP_USER="root"
BACKUP_PATH="/backup/racknerd"
DATE="20250212"

rsync -avz -e ssh "${BACKUP_USER}@${BACKUP_SERVER}:${BACKUP_PATH}/full-${DATE}/" /
```

После восстановления проверьте права и перезапустите сервисы (nginx, docker, БД и т.д.).

### Восстановление из tar-архива

**Способ 1 — потоком по SSH** (архив не сохраняется на диск целевого сервера):

На **целевом сервере**:

```bash
BACKUP_SERVER="IP_БЭКАП_СЕРВЕРА"
BACKUP_USER="root"
BACKUP_PATH="/backup/racknerd"
ARCHIVE="racknerd-ffaf464-20250212.tar.gz"   # или racknerd-full-20250212.tar.gz

ssh "${BACKUP_USER}@${BACKUP_SERVER}" "cat ${BACKUP_PATH}/${ARCHIVE}" | tar xzf - -C /
```

**Способ 2 — сначала скачать архив, потом распаковать:**

На целевом сервере:
```bash
scp "${BACKUP_USER}@${BACKUP_SERVER}:${BACKUP_PATH}/racknerd-ffaf464-20250212.tar.gz" /tmp/
tar xzf /tmp/racknerd-ffaf464-20250212.tar.gz -C /
rm /tmp/racknerd-ffaf464-20250212.tar.gz
```

Распаковка в `/` перезапишет существующие файлы в `/etc`, `/root`, `/home` и т.д. Делайте это на чистой системе или убедитесь, что нужные сервисы остановлены.

### После восстановления

- Проверить права: `chown -R` при необходимости (например, пользователи приложений, docker).
- Перезапустить сервисы: `systemctl restart nginx` (или аналог), перезапуск контейнеров Docker при необходимости.
- Если восстанавливали только часть каталогов — проверить конфиги и пути в приложениях и БД.
