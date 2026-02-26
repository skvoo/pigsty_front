# Почему в дашборде «Node Instance» не видно n8n и password server

## Проверка по конфигу (Context7 + сервер)

### Как устроен выпадающий список «Node ID»

- Дашборд: **Node Instance** (`~/pigsty/files/grafana/node/node-instance.json` на сервере).
- Переменная **Node ID** (имя `id`) задаётся запросом к Prometheus/VictoriaMetrics:
  ```text
  label_values(node:ins, id)
  ```
- Метрика **node:ins** — это recording rule из VictoriaMetrics (файл правил `~/pigsty/files/victoria/rules/node.yml`). Она строится из **node_uname_info**:
  ```yaml
  - record: node:ins
    expr: |
      sum without (...) (
        label_replace(node_uname_info, "id", "$1", "nodename", "(.+)") OR
        label_replace(node_uname_info, "id", "$1", "instance", "(.+)\\:\\d+") OR
        label_replace(node_uname_info, "id", "$1", "ins", "(.+)")
      )
  ```
- То есть в выпадающий список попадают только те `id`, для которых в VM есть **node_uname_info**. Если по хосту нет скрапа node_exporter → нет node_uname_info → нет node:ins → хоста нет в списке.

### Что на сервере

1. **Цели для n8n и password server есть**  
   Файлы в `/infra/targets/node/`:
   - `104.223.25.234.yml` (Pigsty)
   - `107.175.134.104.yml` (password server)
   - `172.245.64.199.yml` (n8n)  
   В них указаны `targets: …:9100` (node_exporter) и лейблы `ip`, `ins`, `cls: nodes`.

2. **VictoriaMetrics скрапит из этих файлов**  
   В `/infra/prometheus.yml` задано:
   - `job_name: node` с `files: [ /infra/targets/node/*.yml ]`  
   VM использует этот конфиг (`-promscrape.config=/infra/prometheus.yml`) и file SD с интервалом 5s.

3. **Доступ до node_exporter с Pigsty до двух новых серверов — нет**  
   С 104.223.25.234 запросы к `http://172.245.64.199:9100/metrics` и `http://107.175.134.104:9100/metrics` дают таймаут (curl exit 28, http code 000).  
   Значит, VM не может получить метрики с этих хостов, по ним нет **node_uname_info** и нет **node:ins** → в выпадающем списке «Node ID» они не появляются.

## Что сделать

- **Открыть порт 9100 (TCP)** на серверах **172.245.64.199** (n8n) и **107.175.134.104** (password server) для источника **104.223.25.234** (например, в firewalld/ufw/iptables или облачном firewall).
- После этого VM начнёт успешно скрапить node_exporter с обоих хостов, появятся **node_uname_info** и **node:ins**, и в дашборде «Node Instance» в выпадающем списке «Node ID» появятся:
  - по n8n: IP **172.245.64.199**, hostname **racknerd-ffaf464** (и при необходимости ins);
  - по password server: IP **107.175.134.104**, hostname **racknerd-fd7c8e2**.

Дополнительно менять дашборд или переменную не обязательно: запрос `label_values(node:ins, id)` корректен, не хватает только успешного скрапа с новых нод.

---

*Проверено: конфиг дашборда (node-instance.json), правило node:ins (victoria/rules/node.yml), цели в /infra/targets/node/, доступ с 104.223.25.234 до :9100 на 172.245.64.199 и 107.175.134.104.*
