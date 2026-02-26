# Создание Telegram-бота и канала для алертов Pigsty

После настройки в канал будут приходить **критичные алерты по всем серверам**: Pigsty (104.223.25.234), n8n (172.245.64.199), password server (107.175.134.104) — NodeDown, диск, PostgresDown и т.д.

---

## Шаг 1: Создать бота

1. В Telegram откройте **@BotFather**.
2. Отправьте команду: `/newbot`.
3. Введите **имя** бота (например: `Pigsty Alerts`).
4. Введите **username** бота (должен заканчиваться на `bot`, например: `YourPigstyAlertsBot`).
5. BotFather пришлёт **токен** вида `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`.  
   **Сохраните его** — это `REPLACE_BOT_TOKEN` (никому не передавайте).

---

## Шаг 2: Создать канал

1. В Telegram: **Меню** → **Создать канал** (или **New Channel**).
2. Введите название (например: **Alerts** или **Pigsty Alerts**).
3. Укажите описание при желании, тип канала — **Публичный** или **Приватный**.
4. Канал создан.

---

## Шаг 3: Добавить бота в канал и узнать chat_id

1. Откройте **канал** → **Изменить канал** → **Администраторы** → **Добавить администратора**.
2. Найдите вашего бота по username и добавьте его.
3. Выдайте право **Публикация сообщений** (остальные можно отключить).
4. **Узнать chat_id канала:**
   - Отправьте в канал **любое сообщение** (можно от имени бота или от себя).
   - В браузере откройте (подставьте свой токен бота):
     ```
     https://api.telegram.org/bot<ВАШ_ТОКЕН>/getUpdates
     ```
   - В JSON найдите `"chat":{"id":-100xxxxxxxxxx,...}`.  
     **chat_id канала** — это число `-100xxxxxxxxxx` (отрицательное).  
     Пример: `-1001234567890`.
5. **Важно:** в конфиге Alertmanager `chat_id` для канала задаётся **числом без кавычек**, например: `-1003847875300`. Со строкой в кавычках конфиг не загрузится (ошибка unmarshal).

---

## Шаг 4: Прописать конфиг на Pigsty

На **вашем компьютере** (где лежит репозиторий pigsty):

1. Откройте файл **`alertmanager-telegram.yml`** в корне проекта.
2. Замените:
   - `REPLACE_BOT_TOKEN` → токен от BotFather (в кавычках).
   - `REPLACE_CHAT_ID` → chat_id канала в кавычках, например `"-1001234567890"`.
3. Скопируйте файл на сервер и подмените конфиг:
   ```bash
   scp alertmanager-telegram.yml st@104.223.25.234:~/
   ssh st@104.223.25.234 "sudo cp ~/alertmanager-telegram.yml /etc/alertmanager.yml && sudo systemctl reload alertmanager"
   ```
4. Проверка: `ssh st@104.223.25.234 "systemctl status alertmanager"` — должен быть `active (running)`.

Если Alertmanager не перезагружается — проверьте синтаксис:  
`sudo amtool check-config /etc/alertmanager.yml` (если установлен) или посмотрите `journalctl -u alertmanager -n 20`.

---

## Сигналы по серверам

| Сервер | Что покрыто |
|--------|-------------|
| **104.223.25.234** (Pigsty) | NodeDown, диск, память, PostgresDown, PgbouncerDown, PatroniDown и др. |
| **172.245.64.199** (n8n) | NodeDown, диск, память (node_exporter) |
| **107.175.134.104** (password server) | NodeDown, диск, память (node_exporter) |

В канал уходят алерты с **level="0"** (CRIT). При срабатывании в сообщении будет указан instance (IP или hostname), так что будет видно, с какого сервера алерт.

---

## Как протестировать

**Способ 1: тестовый алерт через API (ничего не ломаем)**

На сервере Pigsty (или с него по SSH):

```bash
curl -s -X POST -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"TestAlert","level":"0","severity":"CRIT"},"annotations":{"summary":"Test notification","description":"Telegram delivery check"}}]' \
  http://127.0.0.1:9059/api/v2/alerts
```

Либо скопировать на сервер файл `test-alert.json` из репозитория и выполнить:

```bash
curl -s -X POST -H 'Content-Type: application/json' -d @test-alert.json http://127.0.0.1:9059/api/v2/alerts
```

Через несколько секунд в канал **Sharcon Alerts** должно прийти сообщение.

**Способ 2: реальный алерт**

Временно остановить node_exporter на любой ноде (например n8n): `sudo systemctl stop node_exporter` — через 1–2 минуты сработает NodeDown и придёт уведомление. Затем запустить снова: `sudo systemctl start node_exporter`.
