# Подключение фронта к БД app (Pigsty)

Краткая инструкция: как перевести загрузку новостей с Supabase на нашу БД, чтобы протестировать и подготовить миграцию.

---

## Зачем это нужно

- **Протестировать без риска** — новости берутся из нашей таблицы, Supabase для остального приложения можно не трогать; при проблемах источник легко вернуть.
- **Подготовить миграцию** — фронт заранее учится ходить в наш API; при переносе данных останется переключить источник.
- **Один источник данных** — новости живут в нашей БД и на нашей инфраструктуре.

---

## Что сделать на бэкенде

**Зачем:** из браузера к PostgreSQL не подключаются — нужен свой API, который читает из БД и отдаёт JSON.

**1.** В `.env` добавить `DATABASE_URL=postgresql://dbuser_app:ПАРОЛЬ@104.223.25.234:6432/app` (пароль — у админа Pigsty). Файл в `.gitignore`, в репо не коммитить. Так бэкенд подключается к нашей БД по этой строке, пароль не попадает в код.

**2.** В проекте бэкенда установить драйвер: `npm install pg` — чтобы Node-сервер мог выполнять запросы к PostgreSQL. Во фронте пакет не нужен.

**3.** Сделать GET-endpoint (например `/api/news`): читать из `public.news` где `published = true`, возвращать массив в JSON. Фронт будет вызывать этот URL вместо Supabase для списка новостей.

**Пример endpoint (Next.js)** — `app/api/news/route.ts`:

```ts
import { NextResponse } from 'next/server';
import { Pool } from 'pg';

const pool = process.env.DATABASE_URL
  ? new Pool({ connectionString: process.env.DATABASE_URL })
  : null;

export async function GET() {
  if (!pool) return NextResponse.json({ error: 'DATABASE_URL not set' }, { status: 503 });
  try {
    const { rows } = await pool.query(
      `SELECT id, slug, title_en, title_ru, excerpt_en, excerpt_ru, image, published, created_at, updated_at, tags
       FROM public.news WHERE published = true ORDER BY created_at DESC`
    );
    return NextResponse.json(rows);
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Database error' }, { status: 500 });
  }
}
```

---

## Что сделать во фронте

**Зачем:** переключить источник данных только для новостей, не ломая остальное приложение.

В месте, где сейчас загружаются новости (например `supabase.from('news').select(...)`), временно заменить на вызов своего API: `fetch('/api/news')` (или URL вашего бэкенда). Переменные Supabase для остального приложения не трогать.

---

## Справка

**Строка подключения:**  
`postgresql://dbuser_app:ПАРОЛЬ@104.223.25.234:6432/app`  
Порт 6432 — PgBouncer; пользователь и пароль — в `pigsty.yml`, секция `pg_users` для `dbuser_app`.

**Таблица** `public.news`: поля `id`, `slug`, `title_en`, `title_ru`, `content_en`, `content_ru`, `excerpt_en`, `excerpt_ru`, `image`, `tags`, `published`, `created_at`, `updated_at`. Схема и сиды: `sql/app_schema.sql`, `sql/seed_news_test.sql`.

Доступ с других IP или отдельного пользователя — согласовать с администратором Pigsty (HBA в `pigsty.yml`).
