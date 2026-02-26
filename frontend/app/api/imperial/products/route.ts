/**
 * API: список продуктов imperial из БД imperialdb (Pigsty).
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
      `SELECT * FROM public.products ORDER BY created_at DESC`
    );
    return NextResponse.json(
      rows.map((r: Record<string, unknown>) => ({
        id: r.id,
        slug: r.slug,
        name: r.name,
        description: r.description,
        category_id: r.category_id,
        created_at: r.created_at,
        updated_at: r.updated_at,
        price: r.price,
        image_urls: r.image_urls ?? r.images ?? r.image ?? null,
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
