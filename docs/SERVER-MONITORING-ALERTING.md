# Мониторинг серверов и оповещения (Pigsty + Grafana)

**Цель:** контроль ресурсов 3+ серверов, оповещения в Email и Telegram при нехватке CPU/RAM/диска.

---

## 1. Можно ли использовать Pigsty/Grafana для контроля серверов?

**Да.** В Pigsty уже есть всё необходимое:

| Компонент | Назначение |
|-----------|------------|
| **Prometheus** | Сбор метрик (в т.ч. с node_exporter по каждому серверу) |
| **Grafana** | Дашборды и визуализация (уже дашборды по нодам) |
| **Alertmanager** | Обработка алертов и отправка в Email / Telegram |
| **Node Exporter** | Метрики ОС: CPU, RAM, диск, сеть (уже на нодах Pigsty) |

На сервере с Pigsty (104.223.25.234) это уже развёрнуто. Остаётся:
- добавить остальные серверы в мониторинг (node_exporter + регистрация в Prometheus);
- настроить правила алертов (когда «ресурсы заканчиваются»);
- настроить Alertmanager на Email и Telegram.

---

## 2. Добавление остальных серверов в мониторинг

Чтобы Prometheus и Grafana видели все 3+ сервера, каждый сервер должен:
- быть в Ansible-инвентаре Pigsty;
- иметь установленный **node_exporter** и быть зарегистрирован в Prometheus.

### 2.1 Добавить хосты в `pigsty.yml`

В секции `all.children` добавьте группу нод только для мониторинга (без PostgreSQL), например:

```yaml
# Дополнительные серверы только для мониторинга (без PGSQL)
monitored_nodes:
  hosts:
    SERVER_2_IP: { node_seq: 2 }   # второй сервер
    SERVER_3_IP: { node_seq: 3 }   # третий сервер
  vars:
    node_exporter_enabled: true
    node_register_enabled: true
```

Либо добавьте эти IP в существующую группу **infra** (если они должны быть «инфра-нодами» с тем же набором пакетов):

```yaml
infra:
  hosts:
    104.223.25.234: { infra_seq: 1 }
    SERVER_2_IP:    { infra_seq: 2 }
    SERVER_3_IP:    { infra_seq: 3 }
```

Важно: на всех хостах должен быть настроен **passwordless SSH** с машины, с которой вы запускаете Ansible (как для 104.223.25.234).

### 2.2 Установка node_exporter и регистрация в Prometheus

С хоста, где лежит Pigsty (каталог с `pigsty.yml`, `ansible.cfg`, плейбуки):

```bash
# Только node_exporter + регистрация в Prometheus (без полной ноды)
./node.yml -l monitored_nodes -t node_exporter,node_register

# Если добавили хосты в infra:
./node.yml -l infra -t node_exporter,node_register
```

После этого перезапустите Prometheus (или дождитесь перезагрузки конфига) и в Grafana появятся метрики по всем нодам (дашборды Node встроены в Pigsty).

---

## 3. Правила алертов: когда «ресурсы заканчиваются»

Нужно описать условия в **Prometheus** (alerting rules). В Pigsty конфиг правил обычно генерируется/подключается из каталога инсталляции (например `~/pigsty` на сервере). Ищем файлы вида `rules/*.yml` или параметры в `group_vars`/шаблонах Prometheus.

Типичные правила (можно добавить в свой файл правил или в существующий):

```yaml
groups:
  - name: node_resources
    rules:
      # Диск заполнен более чем на 85%
      - alert: NodeDiskSpaceCritical
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 5m
        labels: { severity: critical }
        annotations:
          summary: "Мало места на диске ({{ $labels.instance }})"
          description: "Свободно меньше 15% на {{ $labels.instance }}"

      # RAM: свободной памяти мало
      - alert: NodeMemoryCritical
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels: { severity: critical }
        annotations:
          summary: "Высокое использование RAM ({{ $labels.instance }})"
          description: "Использование памяти > 90% на {{ $labels.instance }}"

      # CPU: высокая загрузка
      - alert: NodeCPUHigh
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
        for: 10m
        labels: { severity: warning }
        annotations:
          summary: "Высокая загрузка CPU ({{ $labels.instance }})"
```

Где именно подмешивать эти правила, зависит от версии Pigsty:
- в каталоге установки Pigsty на сервере ищите `templates` или `files` для Prometheus rules;
- либо задаётся через переменные (например `prometheus_rules` / `prometheus_alert_rules`), если такие есть в документации Pigsty v4.

После добавления правил — перезагрузка конфига Prometheus или рестарт сервиса.

---

## 4. Оповещения: Email и Telegram (Alertmanager)

Alertmanager в Pigsty уже запущен (порт 9093). Нужно настроить его конфиг: **receivers** (куда слать) и **routes** (какие алерты куда направлять).

Конфиг обычно лежит на сервере Pigsty, например:
- `/etc/alertmanager/alertmanager.yml` или
- в каталоге развёртывания Pigsty (шаблон `alertmanager.yml.j2` и т.п.).

### 4.1 Пример `alertmanager.yml` (Email + Telegram)

```yaml
global:
  # Для email (подставьте свои данные)
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@yourdomain.com'
  smtp_auth_username: 'alerts@yourdomain.com'
  smtp_auth_password: 'your-app-password'
  smtp_require_tls: true

receivers:
  - name: email
    email_configs:
      - to: 'admin@yourdomain.com'
        send_resolved: true

  - name: telegram
    telegram_configs:
      - api_url: 'https://api.telegram.org'
        bot_token: 'YOUR_BOT_TOKEN'
        chat_id: 'YOUR_CHAT_ID'   # строка, для групп: "-1001234567890"
        send_resolved: true
        parse_mode: 'HTML'
        message: |
          {{ range .Alerts }}
          [{{ .Status | toUpper }}] {{ .Annotations.summary }}
          {{ .Annotations.description }}
          {{ end }}

route:
  receiver: email
  group_by: ['alertname', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - match_re:
        severity: critical
      receiver: telegram
      continue: true
    - receiver: email
```

Важно:
- **Telegram:** создайте бота через [@BotFather](https://t.me/BotFather), возьмите `bot_token`. `chat_id` — ID чата (или группы); для групп часто вида `-100xxxxxxxxxx`, обязательно **в кавычках** (строка).
- **Email (Gmail):** используйте «Пароль приложения», не обычный пароль.

После изменения конфига — перезапуск Alertmanager. В Pigsty это может быть через systemd: `systemctl restart alertmanager` (имя сервиса уточните на хосте: `systemctl list-units | grep alert`).

### 4.2 Где править конфиг в Pigsty

Если Pigsty управляет Alertmanager через Ansible:
- в репозитории Pigsty ищите шаблон `alertmanager.yml` (или переменные типа `alertmanager_config`);
- задайте свой конфиг через переменные или скопируйте отредактированный `alertmanager.yml` в нужное место и перезапустите сервис вручную (если не переопределяете шаблон).

---

## 5. Альтернативы

| Вариант | Плюсы | Минусы |
|---------|--------|--------|
| **Только Pigsty (Grafana + Prometheus + Alertmanager)** | Уже стоит, один стек, дашборды по нодам есть | Нужно добавить ноды, правила и конфиг Alertmanager |
| **Grafana Alerting** | Удобные алерты прямо из дашбордов, уведомления (в т.ч. Telegram) | Дублирует Alertmanager; для сложной маршрутизации Prometheus+Alertmanager гибче |
| **Отдельный Uptime Kuma / Netdata** | Простая установка, свои оповещения | Отдельный сервис и интерфейс, метрики не в одном месте с Pigsty |

Рекомендация: **использовать текущий стек Pigsty** (Prometheus + Alertmanager для алертов, Grafana для обзора). Этого достаточно для контроля 3+ серверов и оповещений в Email и Telegram при нехватке ресурсов.

---

## 6. Краткий чеклист

1. Добавить IP остальных серверов в `pigsty.yml` (группа `monitored_nodes` или `infra`).
2. Запустить `./node.yml -l <группа> -t node_exporter,node_register` с машины с Pigsty.
3. Добавить правила алертов Prometheus (диск, RAM, CPU) в конфиг правил, используемый Pigsty.
4. Настроить `alertmanager.yml`: SMTP (email) и `telegram_configs` (Telegram), перезапустить Alertmanager.
5. Проверить: в Grafana — метрики по всем нодам; тестовый алерт или отключение диска — приход сообщения в Email/Telegram.

---

*Документ подготовлен под конфигурацию Pigsty на 104.223.25.234 (см. docs/PLAN.md). Пути к конфигам на сервере могут отличаться в зависимости от способа установки Pigsty (пакет/исходники).*
