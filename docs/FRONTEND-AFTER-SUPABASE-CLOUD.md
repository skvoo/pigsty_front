# Инструкция для фронтенда: что изменить после перехода с Supabase Cloud на Pigsty

Единая точка входа для разработчиков фронта при миграции с Supabase Cloud на Pigsty (БД в gdloungedb/imperialdb, файлы в MinIO). Данные и файлы идут через **ваш бэкенд** (API), а не через Supabase JS SDK к Cloud.

---

## 1. Переменные окружения

### 1.1 Текущее (Supabase Cloud)

| Переменная | Назначение |
|------------|------------|
| `NEXT_PUBLIC_SUPABASE_URL` | URL проекта Supabase (для клиента в браузере). |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY` | Публичный (anon) ключ; запросы к БД и Storage от имени anon, RLS в БД. |
| `SUPABASE_SERVICE_ROLE_KEY` | Секретный ключ для серверных операций (обход RLS, админ). **Только на бэкенде, не светить во фронт.** |

### 1.2 После миграции на Pigsty

| Было | Стало |
|------|--------|
| `NEXT_PUBLIC_SUPABASE_URL` | Для **БД и Storage** не используется (данные и файлы через свой API). Для **Auth (гибрид)** — оставить URL Cloud или заменить на Pigsty Supabase URL при переносе Auth. |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY` | Для БД/Storage не используется. Для Auth — оставить anon key Cloud или заменить на ключ Pigsty. |
| `SUPABASE_SERVICE_ROLE_KEY` | На бэкенде убрать для операций с данными/файлами. Оставить только если нужен для Auth (гибрид). |
| — | **Новые (бэкенд):** `DATABASE_URL_GDLOUNGE`, `DATABASE_URL_IMPERIAL` (строки подключения к Pigsty PgBouncer 6432). При MinIO: `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_PUBLIC_URL` (по проекту/бакету). |

**Важно:** публичные ключи (`NEXT_PUBLIC_*`) **не должны** содержать service_role. Service_role — только в серверных переменных, не коммитить в репозиторий.

Пример для одного проекта (GD-lounge) в Vercel / `.env.local`:

- `DATABASE_URL_GDLOUNGE=postgresql://USER:PASSWORD@104.223.25.234:6432/gdloungedb`
- `S3_ENDPOINT=http://104.223.25.234:9000`
- `S3_BUCKET=gd-lounge-assets`
- `S3_ACCESS_KEY=s3user_gdlounge`
- `S3_SECRET_KEY=...` (из pigsty.yml, в секретах)
- `S3_PUBLIC_URL=http://104.223.25.234:9000/gd-lounge-assets`

---

## 2. Доступ к данным (БД)

### 2.1 Было (Supabase Cloud)

- `createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY)`
- Запросы: `supabase.from('table').select(...)`, `.insert()`, `.update()` и т.д. от имени anon, доступ по RLS в БД.

### 2.2 Стало (Pigsty через свой API)

- Вызовы к вашему API: `fetch('/api/...')` (или отдельный хост бэкенда). Таблицы и поля не меняются; контракт API описывается ниже.
- Пример переключения одной сущности: [FRONTEND-INTEGRATION.md](./FRONTEND-INTEGRATION.md) (новости через `/api/news`).

### 2.3 Типовые замены (GD-lounge и imperial)

| Было (Supabase) | Стало (API) |
|-----------------|-------------|
| `supabase.from('news').select()` (проект GD-lounge) | `fetch('/api/gd/news')` |
| `supabase.from('news').select()` (проект imperial) | `fetch('/api/imperial/news')` |
| `supabase.from('products').select()` (imperial) | `fetch('/api/imperial/products')` |
| `supabase.from('leads').insert(...)` (GD-lounge) | `fetch('/api/gd/leads', { method: 'POST', body: JSON.stringify(...), headers: { 'Content-Type': 'application/json' } })` |
| Аналогично другие таблицы | Добавить соответствующие API routes на бэкенде и вызывать их с фронта. |

Пример для списка новостей (GD-lounge):

```ts
// Было
const { data } = await supabase.from('news').select('*').eq('published', true);

// Стало
const res = await fetch('/api/gd/news');
const data = await res.json();
```

В этом репозитории примеры API: `frontend/app/api/gd/news/route.ts`, `frontend/app/api/imperial/news/route.ts`, `frontend/app/api/imperial/products/route.ts`. Для других таблиц (events, menu_items, gallery, orders и т.д.) нужно добавить свои маршруты по тому же образцу и подключать к `DATABASE_URL_GDLOUNGE` или `DATABASE_URL_IMPERIAL`.

---

## 3. Доступ к файлам (Storage)

### 3.1 Было (Supabase Cloud)

- Загрузка: `supabase.storage.from('bucket').upload(path, file)`, затем `getPublicUrl()` или прямой URL Supabase Storage.
- Отображение: подстановка URL из Storage в `src` / ссылки.

### 3.2 Стало (MinIO через свой API)

- **Загрузка:** только через ваш API (например `POST /api/upload` с FormData, поле `file`). В ответе — `fileUrl` (публичный URL MinIO или прокси). Этот URL сохранять в БД (например в поле `image`, `file_url`, `image_urls`).
- **Отображение:** подставлять этот URL в `src`/ссылки. Supabase Storage на фронте после миграции не использовать.

### 3.3 Формат API загрузки

- **Запрос:** `POST /api/upload`, `multipart/form-data`, поле `file`.
- **Успех:** JSON `{ "fileUrl": "http://104.223.25.234:9000/gd-lounge-assets/1739123456789-image.jpg" }`.
- **Ошибка:** 4xx/5xx, тело вида `{ "error": "No file" }` или `{ "error": "Upload failed", "details": "..." }`.

Пример вызова с фронта (загрузка + сохранение URL в сущности):

```ts
const formData = new FormData();
formData.append('file', file);

const uploadRes = await fetch('/api/upload', { method: 'POST', body: formData });
if (!uploadRes.ok) throw new Error('Upload failed');
const { fileUrl } = await uploadRes.json();

// Дальше: отправить fileUrl в API создания/обновления сущности (новость, продукт и т.д.)
await fetch('/api/gd/news', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ image: fileUrl, ... }),
});
```

Подробнее: [TD-MINIO-DEPLOY-AND-FRONTEND.md](./TD-MINIO-DEPLOY-AND-FRONTEND.md) §2.3–2.4.

---

## 4. Auth (если остаётся в Cloud или переносится позже)

При **гибриде** (Auth в Cloud, данные и файлы на Pigsty):

- Для входа и сессий оставить **Supabase Auth**: `NEXT_PUBLIC_SUPABASE_URL` и anon key Cloud (или Pigsty при переносе Auth).
- Для данных и файлов использовать **только свой API и MinIO**; Supabase клиент для БД/Storage не использовать.

В коде явно разделить: «что остаётся с Supabase» (Auth) и «что переведено на Pigsty» (БД, файлы).

---

## 5. Чеклист для разработчика

- [ ] Удалить или не использовать для данных/файлов: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY` (в части БД/Storage).
- [ ] Добавить на бэкенде: `DATABASE_URL_GDLOUNGE` и/или `DATABASE_URL_IMPERIAL`; при MinIO — переменные `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_PUBLIC_URL`.
- [ ] Заменить вызовы `supabase.from(...)` на `fetch('/api/...')` по списку endpoints (см. §2.3).
- [ ] Заменить загрузку/чтение через `supabase.storage` на вызов API загрузки и использование возвращённого `fileUrl`.
- [ ] Не использовать `SUPABASE_SERVICE_ROLE_KEY` на клиенте; только на сервере и только если нужен для Auth.

---

## 6. Связанные документы

- **[FRONTEND-IMPERIAL-VERCEL-SWITCH.md](./FRONTEND-IMPERIAL-VERCEL-SWITCH.md)** — пошаговая инструкция для Imperial на Vercel: что поменять в переменных и в коде, чтобы переключить подключение на наш сервер (imperialdb + MinIO).
- [TEST-MIGRATION-INVENTORY.md](./TEST-MIGRATION-INVENTORY.md) — инвентаризация сервисов по проектам.
- [MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md](./MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md) — команды миграции БД и сводка по таблицам.
- [STORAGE-MIGRATION-SUPABASE-TO-MINIO.md](./STORAGE-MIGRATION-SUPABASE-TO-MINIO.md) — перенос файлов в MinIO.
- [FRONTEND-INTEGRATION.md](./FRONTEND-INTEGRATION.md) — подключение фронта к БД Pigsty (пример /api/news).
- [VERCEL-TD-INTEGRATION.md](./VERCEL-TD-INTEGRATION.md) — переменные и подключение к Pigsty на Vercel.
- [TD-MINIO-DEPLOY-AND-FRONTEND.md](./TD-MINIO-DEPLOY-AND-FRONTEND.md) — паттерн загрузки в MinIO.
