# MinIO (S3) для TD: развёртывание и инструкция для фронтенда

Хранилище файлов тикетов — **MinIO** (S3-совместимое) на сервере Pigsty. Загрузка идёт через ваш API (Next.js/Vercel), который кладёт файл в MinIO и возвращает URL для сохранения в `tickets.file_url`.

---

## Часть 1. Развёртывание MinIO на сервере

### 1.1 Что уже сделано в конфиге

В `pigsty.yml` включена секция **minio**:

- **Хост:** 104.223.25.234
- **Бакет для TD:** `td-tickets`
- **Пользователь S3:** `s3user_td`, политика `td-tickets` (доступ к бакету `td-tickets`)
- **Пароль пользователя:** `TdStorage7xKp2mNqR` (хранить в секретах, не коммитить в репозиторий)
- **Пока без домена:** HTTP по IP (`minio_https: false`) — доступ с Vercel по `http://104.223.25.234:9000`. Когда появится домен — см. раздел **1.4 Когда будет домен (HTTPS)**.

Дополнительно созданы бакеты/пользователи по умолчанию Pigsty: `pgsql`, `meta`, `data` (для бэкапов и др.).

### 1.2 Порядок действий на сервере

Выполнять **на машине с Pigsty** (где лежат плейбуки и `pigsty.yml`).

1. **Скопировать актуальный `pigsty.yml`** на сервер (если правили локально):
   ```bash
   scp pigsty.yml st@104.223.25.234:~/pigsty/pigsty.yml
   ```

2. **Подключиться по SSH:**
   ```bash
   ssh st@104.223.25.234
   cd ~/pigsty
   ```

3. **Развернуть MinIO** (установка и создание бакетов/пользователей):
   ```bash
   ./minio.yml -l minio
   ```
   При необходимости сначала подготовить ноду (если MinIO ставится впервые на этом хосте):
   ```bash
   ./node.yml -l 104.223.25.234
   ./minio.yml -l minio
   ```

4. **Проверить:**
   - API: `curl -s -o /dev/null -w "%{http_code}" http://104.223.25.234:9000/minio/health/live` → ожидается 200.
   - Консоль MinIO: в браузере открыть `http://104.223.25.234:9001`, войти с root-учётными данными (по умолчанию в Pigsty: `minioadmin` / `S3User.MinIO` или из `pigsty.yml`). Убедиться, что бакет `td-tickets` есть.

### 1.3 Сделать бакет td-tickets публичным на чтение (для ссылок в ticket)

Чтобы по `file_url` можно было открывать файл в браузере:

- В консоли MinIO (9001) → Buckets → **td-tickets** → Access Rules (или через Policy) задать **public read** для префикса или всего бакета.
- Либо через mc (MinIO Client): на сервере после `./minio.yml` выполнить:
  ```bash
  mc anonymous set download myminio/td-tickets
  ```
  (если алиас `myminio` указывает на ваш MinIO с учёткой minioadmin).

Тогда публичный URL объекта будет вида:  
`http://104.223.25.234:9000/td-tickets/<key>`.

### 1.4 Когда будет домен (HTTPS)

Когда появится домен, указывающий на сервер (например `minio.example.com` → 104.223.25.234):

1. В `pigsty.yml` в секции **minio** → **vars** выставить `minio_https: true` и при необходимости задать `minio_domain: minio.example.com` (по умолчанию Pigsty использует `sss.pigsty`).
2. Сделать DNS A-запись: домен → IP сервера.
3. На сервере выполнить заново: `./minio.yml -l minio`.
4. В бэкенде (Vercel) сменить `S3_ENDPOINT` и `S3_PUBLIC_URL` на `https://<ваш-домен>:9000` и `https://<ваш-домен>:9000/td-tickets`. Для самоподписанного CA задать `NODE_EXTRA_CA_CERTS` (файл с CA сервера) или доверить сертификат иным способом.

---

## Часть 2. Инструкция для фронтендеров

### 2.1 Схема работы

1. Пользователь выбирает файл в интерфейсе.
2. Фронт отправляет файл на **ваш** API (например `POST /api/upload`).
3. API (Next.js на Vercel) загружает файл в MinIO по S3 API и возвращает **URL** файла.
4. Фронт вызывает API создания тикета (или общий API), передаёт `file_url`; в БД `td` в `tickets` сохраняется строка с этим `file_url`.

Supabase Storage в этом потоке **не используется**.

### 2.2 Переменные окружения (бэкенд / Vercel)

Добавить в проект (Vercel → Settings → Environment Variables или локально `.env`):

| Переменная | Значение | Описание |
|------------|----------|----------|
| `S3_ENDPOINT` | `http://104.223.25.234:9000` | URL MinIO (S3 API). Пока без домена — по IP и HTTP. |
| `S3_BUCKET` | `td-tickets` | Бакет для файлов тикетов. |
| `S3_ACCESS_KEY` | `s3user_td` | Access Key пользователя MinIO для TD. |
| `S3_SECRET_KEY` | `TdStorage7xKp2mNqR` | Secret Key (хранить в секретах, не коммитить). |
| `S3_PUBLIC_URL` | `http://104.223.25.234:9000/td-tickets` | Базовый URL для публичной ссылки на объект. |

Пароль `TdStorage7xKp2mNqR` выдаёт администратор; в репозиторий не класть.

### 2.3 API загрузки файла (бэкенд)

**Endpoint:** `POST /api/upload` (или другой путь по соглашению).

**Вход:** `multipart/form-data`, поле с файлом — например `file`.

**Выход (успех):** JSON с полем `fileUrl` — полный URL для сохранения в `tickets.file_url`:

```json
{ "fileUrl": "http://104.223.25.234:9000/td-tickets/1739123456789-document.pdf" }
```

**Ошибка:** статус 4xx/5xx, тело по формату проекта (например `{ "error": "No file" }`).

Пример реализации (Next.js App Router), если используете AWS SDK v3:

```ts
// app/api/upload/route.ts
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

Зависимость: `npm install @aws-sdk/client-s3`.

### 2.4 Вызов с фронта (загрузка + создание тикета)

Пример: загрузить файл, получить `fileUrl`, отправить его в API создания тикета.

```ts
// Загрузка файла
const formData = new FormData()
formData.append('file', file)

const uploadRes = await fetch('/api/upload', { method: 'POST', body: formData })
if (!uploadRes.ok) throw new Error('Upload failed')
const { fileUrl } = await uploadRes.json()

// Создание тикета (пример)
await fetch('/api/tickets', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ file_url: fileUrl }),
})
```

В БД `td` в таблице `tickets` поле `file_url` должно содержать ровно это значение `fileUrl` (например `http://104.223.25.234:9000/td-tickets/1739123456789-document.pdf`).

### 2.5 Ограничения и безопасность

- Размер и типы файлов при необходимости ограничивать на API (и при желании на фронте).
- Не отдавать `S3_SECRET_KEY` и `S3_ACCESS_KEY` на клиент — загрузка только через ваш бэкенд.
- CORS для MinIO с Vercel обычно не нужен: запросы идут на ваш домен (Vercel), а бэкенд сам ходит в MinIO по IP.

---

## Кратко

- **Сервер:** в `pigsty.yml` включён MinIO, бакет `td-tickets`, пользователь `s3user_td`. Выполнить `./minio.yml -l minio`, при необходимости выставить public read на бакет.
- **Бэкенд:** переменные `S3_*`, endpoint `POST /api/upload`, возврат `{ fileUrl }`, загрузка в MinIO через `@aws-sdk/client-s3`.
- **Фронт:** отправлять файл в `/api/upload`, брать `fileUrl` из ответа и передавать в API создания тикета как `file_url`.
