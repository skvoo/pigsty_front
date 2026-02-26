/**
 * API: список событий imperial из БД imperialdb (Pigsty).
 * Требуется DATABASE_URL_IMPERIAL в окружении.
 */

import { NextResponse } from 'next/server';
import { Pool } from 'pg';

const pool = process.env.DATABASE_URL_IMPERIAL
  ? new Pool({ connectionString: process.env.DATABASE_URL_IMPERIAL })
  : null;

export async function GET() {
  if (!pool) {
    return NextResponse.json(
      { error: 'DATABASE_URL_IMPERIAL not configured' },
      { status: 503 }
    );
  }
  try {
    const { rows } = await pool.query(
      `SELECT * FROM public.events ORDER BY created_at DESC NULLS LAST, id DESC LIMIT 50`
    );
    return NextResponse.json(
      rows.map((r: Record<string, unknown>) => ({
        id: r.id,
        image: r.image ?? r.image_url ?? r.images,
        start_date: r.start_date ?? r.date ?? r.event_date ?? r.start_at ?? null,
        end_date: r.end_date ?? r.end_at ?? null,
        created_at: r.created_at,
        updated_at: r.updated_at,
        title_en: r.title ?? r.title_en ?? r.title_ru,
        title_ru: r.title ?? r.title_ru ?? r.title_en,
      }))
    );
  } catch (e) {
    console.error(e);
    return NextResponse.json(
      { error: 'Database error', details: String((e as Error).message) },
      { status: 500 }
    );
  }
}
