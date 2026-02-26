# Что открыть на сервере для теста Imperial на Vercel

Чтобы тест (https://ваш-проект.vercel.app/test-imperial) работал: подключение к БД **imperialdb** и загрузка картинок из **MinIO**.

---

## 1. PgBouncer (порт 6432) — доступ к imperialdb

Сейчас в `pgb_hba_rules` разрешён доступ к БД `imperialdb` только изнутри. Чтобы Vercel подключался к imperialdb, нужно правило для внешних IP.

**В репозитории уже добавлено** в `pigsty.yml`:

```yaml
- { user: dbuser_app, db: imperialdb, addr: world, auth: pwd, title: 'Imperial test from Vercel', order: 103 }
```

**На сервере:**

1. Убедиться, что в `~/pigsty/pigsty.yml` есть это правило (если конфиг не копировали с репо — добавить вручную в секцию `pgb_hba_rules`).
2. Применить конфиг и перезагрузить PgBouncer:
   ```bash
   cd ~/pigsty
   ./pgsql.yml -l pg-meta -t pgbouncer
   ```
   или перезапуск сервиса: `sudo systemctl restart pgbouncer` (имя сервиса уточнить: `systemctl list-units | grep -i pgbouncer`).

После этого подключение по строке  
`postgresql://dbuser_app:AppTest7x9Kp2mNqR@104.223.25.234:6432/imperialdb`  
с внешних IP (Vercel) должно работать.

---

## 2. MinIO (порт 9000) — доступ к файлам

Тест подгружает картинки по URL вида `http://104.223.25.234:9000/imperial-news-images/...`. Нужно:

**2.1. Порт 9000 доступен с интернета**

- Если на сервере есть firewall (ufw/iptables), открыть порт 9000 для входящих (или хотя бы для нужных диапазонов).
- Пример (ufw): `sudo ufw allow 9000/tcp && sudo ufw status`.

**2.2. Публичное чтение бакетов**

Чтобы браузер мог загрузить картинки без подписи, на бакетах MinIO нужно разрешить анонимное чтение (download):

- Через консоль MinIO: http://104.223.25.234:9001 → Buckets → выбрать бакет (например `imperial-news-images`) → Access → Policy → установить read (download) для anonymous.
- Или на сервере через mc:
  ```bash
  mc anonymous set download myminio/imperial-news-images
  mc anonymous set download myminio/imperial-product-images
  mc anonymous set download myminio/imperial-event-images
  ```
  (алиас `myminio` должен быть настроен на ваш MinIO.)

Бакеты, которые использует тест: `imperial-news-images`, `imperial-product-images`, `imperial-event-images`.

---

## Краткий чеклист

| Что | Действие |
|-----|----------|
| **6432 / imperialdb** | В `pigsty.yml` есть правило для `dbuser_app` + `imperialdb` + world. Применить плейбук pgbouncer или перезапустить PgBouncer. |
| **9000** | Открыт в firewall (если он включён). |
| **MinIO бакеты** | На imperial-news-images, imperial-product-images, imperial-event-images включено публичное чтение (download). |

После этого тест на Vercel должен показывать и данные из БД, и картинки.

---

## 3. Если «Database error» (500) на Vercel

На странице теста теперь выводится **текст ошибки** из API (поле `details`). По нему можно понять причину.

**Типичные причины и что проверить:**

| Сообщение (примерно) | Что проверить |
|----------------------|----------------|
| `connection refused`, `ECONNREFUSED`, `timeout` | Порт 6432 недоступен с Vercel: фаервол на сервере (ufw/iptables) — открыть 6432 для входящих или для диапазонов Vercel. Убедиться, что PgBouncer слушает на 0.0.0.0:6432. |
| `password authentication failed`, `no pg_hba.conf entry` | PgBouncer не разрешает подключение к imperialdb с внешних IP. На сервере: в `~/pigsty/pigsty.yml` есть правило `db: imperialdb`, `order: 103`; затем **перезагрузить PgBouncer**: `cd ~/pigsty && ./pgsql.yml -l pg-meta -t pgbouncer` (или `sudo systemctl restart pgbouncer`). |
| `database "imperialdb" does not exist` | БД imperialdb не создана на сервере — создать через плейбук или вручную. |
| Пароль с `$` или спецсимволами | В Vercel переменную задавать в кавычках или проверить, что значение не обрезано. |

**Проверка с сервера:** зайти по SSH и выполнить:
`PGPASSWORD=... psql "postgresql://dbuser_app@127.0.0.1:6432/imperialdb" -c "SELECT 1"`  
(пароль из pigsty.yml). Если локально работает, а с Vercel нет — скорее фаервол или pgb_hba.
