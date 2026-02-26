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

На странице теста выводится **текст ошибки** из API (поле `details`). По нему можно понять причину.

**Если видите «no authentication method is found»** — PgBouncer на сервере не разрешает подключение к imperialdb с внешних IP. Нужно применить конфиг и перезагрузить PgBouncer:

```bash
ssh st@104.223.25.234
cd ~/pigsty
./pgsql.yml -l pg-meta -t pgbouncer
```

Перед этим убедиться, что в `~/pigsty/pigsty.yml` в секции `pgb_hba_rules` есть правило с `db: imperialdb` (order 103). Если его нет — добавить из репо или вручную, затем снова выполнить плейбук выше.

---

**Типичные причины и что проверить:**

| Сообщение (примерно) | Что проверить |
|----------------------|----------------|
| **`no authentication method is found`** | PgBouncer не применяет правило для imperialdb. На сервере **обязательно перезагрузить PgBouncer**, чтобы подхватить pgb_hba_rules: `cd ~/pigsty && ./pgsql.yml -l pg-meta -t pgbouncer`. Убедиться, что в `~/pigsty/pigsty.yml` есть строка с `db: imperialdb`, `order: 103`. |
| `connection refused`, `ECONNREFUSED`, `timeout` | Порт 6432 недоступен с Vercel: фаервол — открыть 6432; PgBouncer должен слушать на 0.0.0.0:6432. |
| `password authentication failed`, `no pg_hba.conf entry` | То же, что выше: правило для imperialdb в конфиге и **перезапуск PgBouncer**. |
| `database "imperialdb" does not exist` | БД imperialdb не создана на сервере — создать через плейбук или вручную. |
| Пароль с `$` или спецсимволами | В Vercel переменную задавать в кавычках или проверить, что значение не обрезано. |

**Проверка с сервера:** зайти по SSH и выполнить:
`PGPASSWORD=... psql "postgresql://dbuser_app@127.0.0.1:6432/imperialdb" -c "SELECT 1"`  
(пароль из pigsty.yml). Если локально работает, а с Vercel нет — скорее фаервол или pgb_hba.
