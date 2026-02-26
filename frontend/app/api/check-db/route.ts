/**
 * API: проверка подключения к произвольной PostgreSQL БД (Supabase, Pigsty и т.д.).
 * POST с телом { host, port, database, user, password } или { connectionString }.
 * Пароль не логируется.
 */

import { NextRequest, NextResponse } from 'next/server';
import { Client } from 'pg';

export async function POST(request: NextRequest) {
  let config: { connectionString?: string; host?: string; port?: number; database?: string; user?: string; password?: string };
  try {
    const body = await request.json();
    if (body.connectionString && typeof body.connectionString === 'string') {
      config = { connectionString: body.connectionString.trim() };
    } else if (
      body.host && body.database && body.user && body.password != null
    ) {
      config = {
        host: String(body.host).trim(),
        port: body.port != null ? Number(body.port) : 5432,
        database: String(body.database).trim(),
        user: String(body.user).trim(),
        password: String(body.password),
      };
    } else {
      return NextResponse.json(
        { ok: false, error: 'Укажите connectionString либо host, database, user, password' },
        { status: 400 }
      );
    }
  } catch {
    return NextResponse.json(
      { ok: false, error: 'Неверный JSON в теле запроса' },
      { status: 400 }
    );
  }

  const client = new Client(config);
  try {
    await client.connect();
    const { rows } = await client.query('SELECT 1 AS ok, current_database() AS db');
    await client.end();
    return NextResponse.json({
      ok: true,
      db: rows[0]?.db ?? 'unknown',
      message: 'Подключение успешно',
    });
  } catch (e) {
    await client.end().catch(() => {});
    return NextResponse.json(
      { ok: false, error: (e as Error).message },
      { status: 200 }
    );
  }
}
