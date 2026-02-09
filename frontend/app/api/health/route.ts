/**
 * API: проверка подключения к БД app (ping).
 */

import { NextResponse } from 'next/server';
import { Pool } from 'pg';

export async function GET() {
  const conn = process.env.DATABASE_URL;
  if (!conn) {
    return NextResponse.json(
      { ok: false, error: 'DATABASE_URL not set' },
      { status: 503 }
    );
  }
  const pool = new Pool({ connectionString: conn });
  try {
    const { rows } = await pool.query('SELECT 1 as ping, current_database() as db');
    await pool.end();
    return NextResponse.json({
      ok: true,
      db: rows[0]?.db ?? 'unknown',
      message: 'Connected to app database',
    });
  } catch (e) {
    await pool.end().catch(() => {});
    return NextResponse.json(
      { ok: false, error: (e as Error).message },
      { status: 500 }
    );
  }
}
