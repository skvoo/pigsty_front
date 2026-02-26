# Безопасное добавление monitored_nodes (n8n, password server)

Цель: подключить 172.245.64.199 (n8n) и 107.175.134.104 (password server) к мониторингу Pigsty **без перезаписи лишнего** на этих серверах.

---

## Текущий статус

| Хост | Доступ | Мониторинг |
|------|--------|------------|
| **107.175.134.104** (password server) | С Pigsty по ключу **root** | ✅ node_exporter установлен, зарегистрирован в VictoriaMetrics |
| **172.245.64.199** (n8n) | С Pigsty по ключу не заходит (нужен пароль) | ❌ Нужно один раз добавить ключ Pigsty — см. ниже |

В инвентаре на 104.223.25.234 для 107.175.134.104 задано `ansible_user: root`. Для n8n после добавления ключа можно оставить пользователя по умолчанию (st) или задать того, под кем заходите (например root).

---

## Только n8n (172.245.64.199): вход по паролю

Чтобы Pigsty мог подключаться к n8n без пароля, зайдите на **172.245.64.199** по паролю (из своей машины или консоли) и выполните **один раз** (под тем пользователем, под которым будет заходить Ansible — обычно `st` или `root`):

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0uoXtcFb6GHGJPpX8W1ZkyACgIDhYnWNmo1Qdpr34DzWVEYM4zwz6O62vegRwzJWvFOyawlzuFhNueiA9wX3jrA+tBI+8EBw427ghLzXqXgnITirZKdSSZooLrEyz1VSz4r029qItRH8cf6b0jbkWByW2LBY9SpUobeHy3lAFvWPwJeIBfKSIdXpwJJZDmVt6OdHi9DgJXMCiHiMqI2y6dGJpxCO6psIQ1hhBBbP0u8SZNdLm1QCTfSMQ1NVvONg8yndb6O8augwpMyivMLp4b7YUU8VbY1q5nMVk6Q+boReCCCYmdv7X1bpLAhHBJsYTvobPIxhUSJ+goHXV+F6j st@racknerd-cd14e40' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Если на n8n заходите под **root**, в `pigsty.yml` на сервере для этого хоста добавьте `ansible_user: root` (как для 107.175.134.104). Затем с **104.223.25.234**:

```bash
cd ~/pigsty && ansible 172.245.64.199 -m ping
./node.yml -l 172.245.64.199 -t node_exporter,node_register
```

---

## Что будет затронуто (только при тегах `node_exporter,node_register`)

- **Устанавливается/обновляется:** пакет `node_exporter`, systemd-юнит для него, возможно зависимости.
- **Создаётся/обновляется:** конфиг node_exporter (порт 9100), unit файл.
- **На стороне Pigsty (104.223.25.234):** в каталог targets Prometheus добавляются файлы с целями для этих двух хостов (node_exporter:9100). Никаких изменений на самих 172.245.64.199 и 107.175.134.104 кроме node_exporter.

**Чего мы не делаем:** не ставим PostgreSQL, не трогаем repo, не меняем пользователей, не трогаем n8n/password-server приложения. Группа `monitored_nodes` в pigsty.yml настроена только на node_exporter и регистрацию в Prometheus.

---

## Где выполнять команды

Команды ниже нужно выполнять **на машине, где есть доступ к Pigsty**: либо на самом сервере 104.223.25.234 (в каталоге с установленным Pigsty, где лежат `node.yml`, `ansible.cfg`, инвентарь), либо с рабочей станции, где настроен Ansible и инвентарь указывает на этот pigsty.yml.

Скопируйте `pigsty.yml` из этого репозитория в каталог Pigsty на сервере (если конфиг храните в репо), затем выполняйте шаги там.

---

## Шаг 0: Проверка инвентаря

Убедитесь, что в инвентаре Ansible используется ваш pigsty.yml и в нём есть группа `monitored_nodes`:

```bash
cd ~/pigsty   # или каталог, где лежат node.yml и ansible

# Проверить, что Ansible видит хосты
ansible monitored_nodes -m ping
```

Ожидаемый вывод по обоим хостам: `"pong"` и `"changed": false`. Если есть ошибки (SSH, ключи, sudo) — сначала настройте доступ.

---

## Шаг 1: Сверка окружения (ничего не меняем)

Соберите факты о серверах, чтобы убедиться, что это те самые хосты и посмотреть, что уже установлено:

```bash
# Кратко: ОС и hostname
ansible monitored_nodes -m setup -a "filter=ansible_distribution*" --output yaml

# Есть ли уже node_exporter (systemd или процесс)
ansible monitored_nodes -m shell -a "systemctl is-active node_exporter 2>/dev/null || echo 'not-found'" -b
ansible monitored_nodes -m shell -a "which node_exporter 2>/dev/null; dpkg -l 2>/dev/null | grep -i node_exporter || rpm -q node_exporter 2>/dev/null || true" -b
```

По выводу можно убедиться: правильные ли это сервера (n8n / password server), и не установлен ли уже node_exporter.

---

## Шаг 2: Режим проверки (dry-run) — ничего не записываем

Запустите плейбук **только в режиме проверки** — Ansible покажет, что бы изменил, но не будет применять изменения:

```bash
./node.yml -l monitored_nodes -t node_exporter,node_register --check --diff
```

- `--check` — не выполнять реальные изменения (где модули это поддерживают).
- `--diff` — показывать диффы файлов.

Просмотрите вывод: какие пакеты будут установлены, какие файлы созданы/изменены. Если видите что-то лишнее (не связанное с node_exporter или регистрацией в Prometheus) — остановитесь и напишите, что именно.

---

## Шаг 3: Применение (после сверки)

Если шаги 0–2 прошли нормально и в выводе нет ничего, что трогает n8n/password-server приложения или критичные настройки:

```bash
./node.yml -l monitored_nodes -t node_exporter,node_register
```

После успешного выполнения на обоих серверах будет запущен node_exporter (порт 9100), а на 104.223.25.234 в Prometheus появятся цели для этих хостов. В Grafana можно проверить дашборды по Node.

---

## Если что-то пошло не так

- **Ошибки SSH/sudo:** проверьте ключи и `sudo` без пароля для пользователя, под которым Ansible подключается к 172.245.64.199 и 107.175.134.104.
- **Лишние изменения в выводе --check:** не запускайте шаг 3; опишите, какие задачи/файлы вызывают сомнения — можно сузить теги или ограничить плейбук.
- **На сервере уже свой node_exporter:** возможен конфликт портов или unit-имени. Тогда перед повторным запуском можно в `pigsty.yml` для этих хостов задать другой порт, например: `node_exporter_port: 9101` в vars группы `monitored_nodes`.

---

---

## Как увидеть серверы в Grafana

После успешного запуска `./node.yml -l monitored_nodes -t node_exporter,node_register` метрики с n8n и password server начнёт собирать Prometheus (VictoriaMetrics) на 104.223.25.234. В Grafana они появятся как новые **instance** (по IP или hostname).

1. **Откройте Grafana**  
   - URL: `http://104.223.25.234:3000` (или через Nginx/портал, если настроен).  
   - Логин/пароль — из конфига Pigsty (`grafana_admin_password` в pigsty.yml).

2. **Дашборды по нодам (Node)**  
   - В меню слева: **Dashboards** → поиск по словам **Node** или **Host**.  
   - В Pigsty обычно есть дашборды вроде «Node Overview» / «Node Exporter» — откройте любой, где используются метрики `node_*`.

3. **Выбор сервера**  
   - В верхней части дашборда часто есть переменная **instance** или **host**.  
   - В выпадающем списке появятся все цели node_exporter: сам 104.223.25.234, 172.245.64.199, 107.175.134.104.  
   - Выберите нужный instance — графики (CPU, память, диск, сеть) перестроятся по выбранному серверу.

4. **Проверка в Explore**  
   - **Explore** (иконка компаса) → выберите источник данных **Prometheus** (или **VictoriaMetrics**).  
   - Запрос, например: `node_memory_MemAvailable_bytes{instance=~"172.245.64.199|107.175.134.104"}` — доступная память по двум новым хостам.

5. **Если instance — IP**  
   - В списке instance будут отображаться как `172.245.64.199:9100`, `107.175.134.104:9100` (IP + порт node_exporter). Это нормально; по ним и выбирайте нужный сервер.

---

*Инвентарь: `pigsty.yml` на сервере 104.223.25.234, группа `monitored_nodes`: 172.245.64.199 (n8n), 107.175.134.104 (password server).*
