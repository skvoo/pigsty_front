# Тестовый фронтенд — подключение к БД app (Pigsty)

Проверка коннекта к PostgreSQL (база `app`) через API и деплой на Vercel.

## Локальный запуск

```bash
cd frontend
cp .env.example .env.local
# Отредактировать .env.local: указать DATABASE_URL (см. ниже)
npm install
npm run dev
```

Откройте [http://localhost:3000](http://localhost:3000). Страница покажет статус подключения и список новостей из `public.news`.

## DATABASE_URL

Формат (хост/порт из вашего `pigsty.yml`):

```
postgresql://dbuser_app:ПАРОЛЬ@104.223.25.234:6432/app
```

- Порт **6432** — PgBouncer (рекомендуется для приложений).
- Пароль `dbuser_app` задаётся в `pigsty.yml` (переменная `pg_users`).

## Деплой на Vercel

1. Залейте репозиторий в GitHub (или подключите существующий).
2. [vercel.com](https://vercel.com) → **Add New Project** → импортируйте репозиторий.
3. **Root Directory**: укажите `frontend` (или деплойте из папки `frontend` отдельным репо).
4. **Environment Variables**:
   - `DATABASE_URL` = `postgresql://dbuser_app:ПАРОЛЬ@104.223.25.234:6432/app`
5. **Deploy**.

Важно: с Vercel серверы ходят в интернет с динамических IP. Чтобы PostgreSQL принимал подключения, в конфиге Pigsty (pg_hba или файрвол) нужно разрешить доступ с любых IP для пользователя `dbuser_app` к порту 6432 (или 5432), либо использовать Vercel IP allowlist, если ваш провайдер его даёт.

## Структура

- `app/page.tsx` — главная страница, запрашивает `/api/health` и `/api/news`.
- `app/api/health/route.ts` — проверка подключения к БД (ping).
- `app/api/news/route.ts` — список записей из `public.news`.

Схема и тестовые данные: в корне проекта см. `sql/app_schema.sql` и `sql/seed_news_test.sql`.
