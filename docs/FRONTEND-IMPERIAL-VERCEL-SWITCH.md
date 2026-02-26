# Imperial: переключение с Supabase Cloud на наш сервер (Vercel)

Инструкция для фронтенда: что изменить в проекте **Imperial**, чтобы данные и файлы шли с нашего сервера (Pigsty: БД **imperialdb**, файлы в **MinIO**), а не с Supabase Cloud. Деплой — **Vercel**.

---

## 1. Как сейчас (Supabase Cloud)

- **БД:** фронт или API обращается к Supabase через клиент: `createClient(NEXT_PUBLIC_SUPABASE_URL, anon_key)`, запросы `supabase.from('news')`, `supabase.from('products')` и т.д. Данные в проекте Imperial на Supabase Cloud.
- **Файлы (Storage):** загрузка и отображение через `supabase.storage.from('event-images')`, `supabase.storage.from('product-images')` и т.д., URL от Supabase.
- **Переменные в Vercel:** как правило `NEXT_PUBLIC_SUPABASE_URL` (URL проекта Imperial), `NEXT_PUBLIC_SUPABASE_ANON_KEY` (или аналогичное имя), при необходимости `SUPABASE_SERVICE_ROLE_KEY` на бэкенде.

---

## 2. Что будет после переключения

- **БД:** данные читаются/пишутся в БД **imperialdb** на сервере **104.223.25.234** через **ваш API** (Next.js API routes). Прямых обращений из браузера к Supabase/Postgres нет — только вызовы `fetch('/api/imperial/...')`.
- **Файлы:** хранятся в **MinIO** на том же сервере. Загрузка — через ваш API (например `POST /api/upload`), отображение — по URL вида `http://104.223.25.234:9000/<bucket>/<path>`.

---

## 3. Изменения в Vercel (Environment Variables)

В **Vercel** → проект Imperial → **Settings** → **Environment Variables**:

### 3.1 Убрать или не использовать для данных/файлов Imperial

| Переменная | Действие |
|------------|----------|
| `NEXT_PUBLIC_SUPABASE_URL` (проект Imperial) | Для БД и Storage Imperial больше не использовать. Оставить только если нужен Supabase Auth. |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` (Imperial) | То же — не использовать для БД/Storage. |
| `SUPABASE_SERVICE_ROLE_KEY` (Imperial) | Убрать с бэкенда для операций с данными/файлами Imperial (или оставить только для Auth, если остаётся в Cloud). |

### 3.2 Добавить (обязательно для Imperial на Pigsty)

| Переменная | Значение | Где взять |
|------------|----------|-----------|
| `DATABASE_URL_IMPERIAL` | `postgresql://USER:PASSWORD@104.223.25.234:6432/imperialdb` | USER и PASSWORD выдаёт администратор сервера (пользователь с доступом к БД `imperialdb` через PgBouncer, порт 6432). Не коммитить в репозиторий. |

Пример (подставьте выданные логин и пароль):

```env
DATABASE_URL_IMPERIAL=postgresql://dbuser_app:AppTest7x9Kp2mNqR@104.223.25.234:6432/imperialdb
```

**Важно:** на сервере в конфиге PgBouncer (`pgb_hba_rules`) должно быть разрешено подключение к БД `imperialdb` с внешних IP (Vercel). Сейчас по умолчанию открыт только доступ к БД `app`. Если при деплое будет ошибка подключения — администратору нужно в `pigsty.yml` в секции `pgb_hba_rules` добавить правило, например: `{ user: dbuser_app, db: imperialdb, addr: world, auth: pwd, title: 'Imperial from Vercel', order: 103 }`, затем применить конфиг и перезапустить PgBouncer.

### 3.3 Добавить для загрузки/отображения файлов (MinIO)

Если в Imperial есть загрузка изображений (события, новости, продукты, мебель, сайт) — нужны переменные для MinIO. Можно задать один набор для одного бакета или несколько (по бакетам). Пример для **одного** бакета (например продуктов):

| Переменная | Значение |
|------------|----------|
| `S3_ENDPOINT` | `http://104.223.25.234:9000` |
| `S3_BUCKET` | `imperial-product-images` (или другой бакет: `imperial-event-images`, `imperial-news-images`, `imperial-site-images`, `imperial-furniture-images`) |
| `S3_ACCESS_KEY` | `s3user_imperial_pr` (для product-images; для других бакетов: `s3user_imperial_ev`, `s3user_imperial_nw`, `s3user_imperial_si`, `s3user_imperial_fu`) |
| `S3_SECRET_KEY` | Пароль MinIO для этого пользователя (выдаёт администратор; в конфиге сервера: `ImperialStorage7xKp2mNqR` для imperial-пользователей). Не коммитить. |
| `S3_PUBLIC_URL` | `http://104.223.25.234:9000/imperial-product-images` (базовый URL для публичных ссылок на файлы в этом бакете) |

Если приложение загружает в несколько бакетов (events, news, products и т.д.), на бэкенде можно завести несколько наборов переменных (например `S3_BUCKET_EVENTS`, `S3_ACCESS_KEY_EVENTS` и т.п.) или передавать бакет в API загрузки.

После добавления/изменения переменных в Vercel сделать **Redeploy** (Production/Preview), чтобы функции получили новые значения.

---

## 4. Изменения в коде

### 4.1 Запросы к данным (БД)

Вместо вызовов Supabase к таблицам Imperial — вызывать ваш API, который ходит в `imperialdb` по `DATABASE_URL_IMPERIAL`.

| Было (Supabase) | Стало |
|-----------------|--------|
| `supabase.from('news').select(...)` | `fetch('/api/imperial/news')` → ответ JSON |
| `supabase.from('products').select(...)` | `fetch('/api/imperial/products')` |
| `supabase.from('events').select(...)` | Добавить API route `GET /api/imperial/events` и вызывать `fetch('/api/imperial/events')` |
| Аналогично другие таблицы (menu_items, gallery, orders и т.д.) | Добавить соответствующие API routes и вызывать их с фронта |

Пример для новостей:

```ts
// Было
const { data } = await supabase.from('news').select('*').eq('published', true);

// Стало
const res = await fetch('/api/imperial/news');
if (!res.ok) throw new Error('Failed to load news');
const data = await res.json();
```

Пример для продуктов:

```ts
// Было
const { data } = await supabase.from('products').select('*');

// Стало
const res = await fetch('/api/imperial/products');
if (!res.ok) throw new Error('Failed to load products');
const data = await res.json();
```

API routes на бэкенде должны использовать `process.env.DATABASE_URL_IMPERIAL` и подключаться к Postgres (например через `pg`). Примеры в этом репозитории: `frontend/app/api/imperial/news/route.ts`, `frontend/app/api/imperial/products/route.ts`. Для других таблиц — добавить маршруты по тому же образцу.

### 4.2 Файлы (Storage → MinIO)

- **Отображение:** сейчас в БД хранятся URL или пути к файлам в Supabase Storage. После миграции файлы лежат в MinIO; в БД уже могут быть пути/имена без домена. На фронте нужно формировать публичный URL так: базовый URL бакета + путь из БД. Например: `http://104.223.25.234:9000/imperial-product-images/` + значение поля `image_url` или путь из БД. Либо бэкенд отдаёт в API уже полный URL — тогда на фронте просто подставлять его в `src`/ссылки.
- **Загрузка:** убрать вызовы `supabase.storage.from('...').upload(...)`. Вместо них — отправка файла на ваш API (например `POST /api/upload` с `FormData`, поле `file`), в теле запроса или query можно передать бакет (например `product-images`). Ответ API — JSON с полем `fileUrl` (готовый URL в MinIO). Этот URL сохранять в БД при создании/редактировании сущности (продукт, новость, событие и т.д.).

Пример загрузки с фронта:

```ts
const formData = new FormData();
formData.append('file', file);

const res = await fetch('/api/upload?bucket=imperial-product-images', { method: 'POST', body: formData });
if (!res.ok) throw new Error('Upload failed');
const { fileUrl } = await res.json();
// fileUrl использовать при сохранении продукта/новости и т.д.
```

---

## 5. Тест на Vercel после настройки

В этом репозитории есть страница **`/test-imperial`**, которая проверяет подключение к imperialdb и отображение файлов из MinIO:

- Запросы к API: `/api/imperial/stats`, `/api/imperial/news`, `/api/imperial/products`, `/api/imperial/events`.
- На странице отображаются: статус БД, счётчики по таблицам, по несколько записей из news/products/events с картинками (URL собираются из MinIO: `http://104.223.25.234:9000/<bucket>/<path>`).

**Что нужно в Vercel:** задать `DATABASE_URL_IMPERIAL`. Для картинок базовый URL по умолчанию `http://104.223.25.234:9000`; при необходимости задать `NEXT_PUBLIC_IMPERIAL_STORAGE_BASE`.

После деплоя откройте `https://<ваш-проект>.vercel.app/test-imperial` и убедитесь, что данные и изображения подгружаются.

---

## 6. Чеклист для фронтенда

- [ ] В Vercel: добавить `DATABASE_URL_IMPERIAL` (строка подключения к 104.223.25.234:6432/imperialdb).
- [ ] В Vercel: при необходимости добавить переменные MinIO (`S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_PUBLIC_URL`).
- [ ] В Vercel: убрать или перестать использовать для данных/файлов Imperial переменные Supabase (URL, anon key, service_role).
- [ ] В коде: заменить все обращения к данным Imperial через `supabase.from(...)` на `fetch('/api/imperial/...')` (и при необходимости добавить недостающие API routes).
- [ ] В коде: заменить загрузку через `supabase.storage` на вызов вашего API загрузки; отображение — по URL из ответа API или по сформированному URL MinIO.
- [ ] Сделать Redeploy в Vercel и проверить: список новостей, продуктов, событий; отображение изображений; загрузку новых файлов.

---

## 7. Связанные документы

- [FRONTEND-AFTER-SUPABASE-CLOUD.md](./FRONTEND-AFTER-SUPABASE-CLOUD.md) — общая инструкция по переходу с Supabase Cloud на Pigsty (GD-lounge и imperial).
- [VERCEL-TD-INTEGRATION.md](./VERCEL-TD-INTEGRATION.md) — пример настройки переменных и подключения к Pigsty на Vercel (для БД TD).
- [STORAGE-MIGRATION-SUPABASE-TO-MINIO.md](./STORAGE-MIGRATION-SUPABASE-TO-MINIO.md) — соответствие бакетов Imperial в MinIO (event-images, product-images и т.д.).
