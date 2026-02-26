# Замена Supabase Storage на хранилище Pigsty — фронтенд TD

Как переключить загрузку файлов (тикеты) с Supabase Cloud Storage на хранилище на сервере Pigsty. Два варианта: **Supabase Storage на Pigsty** (минимальные правки) и **MinIO (S3)** (свой API загрузки).

---

## Вариант 1: Self-hosted Supabase Storage на Pigsty (проще всего)

На сервере уже поднят Supabase с контейнером **Storage** (Kong на порту 8000). API тот же — меняются только URL и ключи.

### На фронте (Vercel / Next.js)

1. **Переменные окружения** вместо Supabase Cloud задайте инстанс на Pigsty:

   | Переменная | Было (Cloud) | Стало (Pigsty) |
   |------------|-------------|----------------|
   | `NEXT_PUBLIC_SUPABASE_URL` | `https://xxxx.supabase.co` | `http://104.223.25.234:8000` |
   | `NEXT_PUBLIC_SUPABASE_ANON_KEY` | ключ из Dashboard | ключ из конфига Supabase на Pigsty (JWT в `pigsty.yml` → приложение supabase) |
   | `SUPABASE_SERVICE_ROLE_KEY` (если используется на бэке) | service_role из Cloud | service_role того же инстанса на Pigsty |

   Ключи берутся из конфига приложения Supabase в `pigsty.yml` на сервере (переменные контейнеров Kong/GoTrue/Storage) или из Studio.

2. **Код не менять** — `createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY)` и вызовы `supabase.storage.from('bucket').upload(...)` остаются. Клиент будет ходить на `http://104.223.25.234:8000`.

3. **CORS и доступ:** если фронт на другом домене (например Vercel), на Kong/Storage на Pigsty должен быть разрешён origin вашего фронта. При необходимости настраивается в конфиге Supabase (Kong/nginx) на сервере.

4. **Бакет для тикетов:** на Pigsty в том же инстансе Supabase создайте бакет (например `tickets`), если его ещё нет — через Studio (http://104.223.25.234:8000) → Storage, либо через API. Политики RLS для Storage задайте так же, как планировали для Cloud.

5. **Формирование `file_url`:** после `upload()` используйте `getPublicUrl()` или собранный URL в формате вашего self-hosted (например `http://104.223.25.234:8000/storage/v1/object/public/tickets/...`) и это значение пишите в `tickets.file_url` в БД `td`.

**Итого:** замена только в env (URL + anon/service key). Код работы с Supabase Storage тот же.

---

## Вариант 2: MinIO (S3) на Pigsty — свой API загрузки ✅ (выбран)

MinIO включён в `pigsty.yml`, бакет `td-tickets`, пользователь `s3user_td`. **Полная инструкция:** [TD-MINIO-DEPLOY-AND-FRONTEND.md](./TD-MINIO-DEPLOY-AND-FRONTEND.md) — развёртывание на сервере и инструкция для фронтенда.

### 2.1 Включение MinIO на Pigsty (кратко)

- В `pigsty.yml` раскомментировать секцию `minio`, задать хост (например 104.223.25.234), создать пользователя с политикой на бакет для TD (например бакет `td-tickets`).
- Выполнить плейбук MinIO. Получить endpoint (пока HTTP по IP, например `http://104.223.25.234:9000`) и пару access_key/secret_key для приложения.

### 2.2 Бэкенд: API-маршрут загрузки (Next.js на Vercel)

- Установить S3-клиент: `npm install @aws-sdk/client-s3` (MinIO совместим с S3 API).
- Добавить env в Vercel:
  - `S3_ENDPOINT=http://104.223.25.234:9000` (или https, если настроен)
  - `S3_BUCKET=td-tickets`
  - `S3_ACCESS_KEY=...`
  - `S3_SECRET_KEY=...`
  - `S3_PUBLIC_URL=http://104.223.25.234:9000/td-tickets` (или публичный URL бакета для формирования ссылок)

Пример API route (например `app/api/upload/route.ts`):

```ts
import { NextRequest, NextResponse } from 'next/server'
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3'

const s3 = new S3Client({
  region: 'us-east-1',
  endpoint: process.env.S3_ENDPOINT,
  forcePathStyle: true,
  credentials: {
    accessKeyId: process.env.S3_ACCESS_KEY!,
    secretAccessKey: process.env.S3_SECRET_KEY!,
  },
})
const BUCKET = process.env.S3_BUCKET!
const PUBLIC_BASE = process.env.S3_PUBLIC_URL!

export async function POST(req: NextRequest) {
  const formData = await req.formData()
  const file = formData.get('file') as File
  if (!file) return NextResponse.json({ error: 'No file' }, { status: 400 })

  const key = `${Date.now()}-${file.name.replace(/[^a-zA-Z0-9.-]/g, '_')}`

  await s3.send(
    new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      Body: Buffer.from(await file.arrayBuffer()),
      ContentType: file.type,
    })
  )

  const fileUrl = `${PUBLIC_BASE}/${key}`
  return NextResponse.json({ fileUrl })
}
```

Публичный доступ к объектам в MinIO настраивается политикой бакета (public read). Тогда `fileUrl` можно сразу отдавать клиенту и писать в `tickets.file_url`.

### 2.3 Фронтенд: убрать Supabase Storage, вызывать свой API

- Вместо вызова `supabase.storage.from('tickets').upload(...)`:
  - Отправлять файл на `POST /api/upload` (FormData с полем `file`).
  - В ответе брать `fileUrl` и сохранять его в БД `td` в `tickets.file_url` (через ваш API, который делает `INSERT` в `td` с `user_id` и `file_url`).

Пример вызова с фронта:

```ts
const formData = new FormData()
formData.append('file', file)

const res = await fetch('/api/upload', { method: 'POST', body: formData })
const { fileUrl } = await res.json()
// затем вызвать API создания тикета с fileUrl
await fetch('/api/tickets', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ file_url: fileUrl }),
})
```

**Итого:** Supabase Storage на фронте не используется; загрузка — только через ваш API, который пишет в MinIO и возвращает URL для сохранения в `tickets.file_url`.

---

## Сравнение

| Критерий | Вариант 1: Supabase Storage на Pigsty | Вариант 2: MinIO |
|----------|---------------------------------------|------------------|
| Изменения на фронте | Только env (URL + ключи) | Заменить вызовы Storage на вызов своего API загрузки |
| Инфраструктура | Уже есть (Supabase на Pigsty) | Нужно включить и настроить MinIO в pigsty.yml |
| API | Тот же Supabase JS SDK | Свой endpoint + S3 SDK на бэке |
| БД storage | Нужна схема `storage` в БД, с которой связан Supabase (например `app`) | Не нужна; в TD только `tickets.file_url` |

Для быстрого перехода без смены кода — **Вариант 1**. Если хотите полностью уйти от Supabase и хранить файлы только в MinIO — **Вариант 2**.
