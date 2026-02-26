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
      `SELECT id, title_en, title_ru, excerpt_en, excerpt_ru, image, start_date, end_date, created_at, updated_at
       FROM public.events
       ORDER BY start_date DESC NULLS LAST, created_at DESC
       LIMIT 50`
    );
    return NextResponse.json(rows);
  } catch (e) {
    console.error(e);
    return NextResponse.json(
      { error: 'Database error', details: String((e as Error).message) },
      { status: 500 }
    );
  }
}
