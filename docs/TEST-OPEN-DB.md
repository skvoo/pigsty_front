# Тест открытой БД app (таблица news)

БД **app** на сервере Pigsty открыта для тестовых подключений: с любого IP можно подключиться по паролю и читать таблицу `public.news`. Ниже — что сделать, если у вас во фронте сейчас Supabase (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY`, anon key) и вы хотите протестировать загрузку новостей из нашей таблицы.

Переменные Supabase **не меняем** — подменяем только источник данных для новостей.

---

## На бэкенде

**1.** В `.env` добавить (для теста можно так и оставить; в прод пароль лучше вынести в секреты):

```
DATABASE_URL=postgresql://dbuser_app:AppTest7x9Kp2mNqR@104.223.25.234:6432/app
```

Файл `.env` в `.gitignore`, в репозиторий не коммитить.

**2.** В проекте бэкенда (там же, где будет endpoint `/api/news`) установить драйвер: `npm install pg`. Во фронте ставить не нужно — к БД подключается только бэкенд.

**3.** Сделать GET-endpoint, например `/api/news`, который подключается по `DATABASE_URL`, выполняет запрос к `public.news` (только `published = true`) и возвращает массив в JSON.

Пример для Next.js — `app/api/news/route.ts`:

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

## Во фронте

В том месте, где сейчас загружаются новости (например `supabase.from('news').select(...)`), временно подставить вызов своего API: `fetch('/api/news')` (или полный URL вашего бэкенда, если он на другом домене). Остальные запросы к Supabase не трогать.

---

## Что в таблице

Таблица `public.news`: поля `id`, `slug`, `title_en`, `title_ru`, `content_en`, `content_ru`, `excerpt_en`, `excerpt_ru`, `image`, `tags`, `published`, `created_at`, `updated_at`. Схема и тестовые данные в репозитории: `sql/app_schema.sql`, `sql/seed_news_test.sql`.

**Репозиторий (тестовый фронт и пример API):** https://github.com/skvoo/pigsty_front  

**Демо на Vercel:** https://pigsty-front.vercel.app/
