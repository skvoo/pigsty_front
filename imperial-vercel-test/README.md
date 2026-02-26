# Imperial test (Vercel)

Минимальное Next.js-приложение для проверки подключения к **imperialdb** (PostgreSQL на Pigsty) и отображения файлов из **MinIO** при деплое на Vercel.

## Что внутри

- Страница **`/test-imperial`** — запросы к API `/api/imperial/stats`, `/api/imperial/news`, `/api/imperial/products`, `/api/imperial/events`; отображение записей и картинок из MinIO.
- API routes подключаются к БД по переменной `DATABASE_URL_IMPERIAL`.

## Локальный запуск

```bash
cp .env.example .env.local
# Заполнить DATABASE_URL_IMPERIAL в .env.local
npm install
npm run dev
```

Открыть http://localhost:3000/test-imperial

## Деплой на Vercel

1. Импортировать репозиторий в Vercel.
2. В **Settings → Environment Variables** добавить:
   - `DATABASE_URL_IMPERIAL` = `postgresql://USER:PASSWORD@104.223.25.234:6432/imperialdb`
   - (по желанию) `NEXT_PUBLIC_IMPERIAL_STORAGE_BASE` = `http://104.223.25.234:9000`
3. Деплой. Открыть `https://<проект>.vercel.app/test-imperial`.

Подробная инструкция для фронтенда: [docs/FRONTEND-IMPERIAL-VERCEL-SWITCH.md](docs/FRONTEND-IMPERIAL-VERCEL-SWITCH.md).
