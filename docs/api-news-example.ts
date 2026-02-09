/**
 * Пример API-маршрута Next.js App Router для забора новостей из Pigsty.
 * Скопировать в проект фронта, например: app/api/news/route.ts
 *
 * Зависимости: npm i pg
 * Переменная окружения: DATABASE_URL=postgresql://dbuser_app:...@104.223.25.234:6432/app
 */

import { NextResponse } from 'next/server';
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export async function GET() {
  try {
    const { rows } = await pool.query(
      `SELECT id, slug, title_en, title_ru, excerpt_en, excerpt_ru, image, published, created_at, updated_at, tags
       FROM public.news
       WHERE published = true
       ORDER BY created_at DESC`
    );
    return NextResponse.json(rows);
  } catch (e) {
    console.error(e);
    return NextResponse.json(
      { error: 'Database error' },
      { status: 500 }
    );
  }
}
