/**
 * API: счётчики записей по таблицам imperial (для теста подключения к imperialdb).
 * Требуется DATABASE_URL_IMPERIAL в окружении.
 */

import { NextResponse } from 'next/server';
import { Pool } from 'pg';

const pool = process.env.DATABASE_URL_IMPERIAL
  ? new Pool({ connectionString: process.env.DATABASE_URL_IMPERIAL })
  : null;

const TABLES = ['news', 'products', 'events', 'orders', 'furniture_items'] as const;

export async function GET() {
  if (!pool) {
    return NextResponse.json(
      { error: 'DATABASE_URL_IMPERIAL not configured' },
      { status: 503 }
    );
  }
  try {
    const counts: Record<string, number> = {};
    for (const table of TABLES) {
      try {
        const { rows } = await pool.query(
          `SELECT COUNT(*)::int AS c FROM public.${table}`
        );
        const raw = rows[0]?.c;
        counts[table] = typeof raw === 'number' ? raw : Number(raw) || 0;
      } catch {
        counts[table] = -1;
      }
    }
    return NextResponse.json({ ok: true, counts });
  } catch (e) {
    console.error(e);
    return NextResponse.json(
      { error: 'Database error', details: String((e as Error).message) },
      { status: 500 }
    );
  }
}
