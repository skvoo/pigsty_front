'use client';

import { useState } from 'react';

type Result = { ok: boolean; db?: string; message?: string; error?: string };

export default function CheckDbPage() {
  const [useUri, setUseUri] = useState(false);
  const [connectionString, setConnectionString] = useState('');
  const [host, setHost] = useState('');
  const [port, setPort] = useState('5432');
  const [database, setDatabase] = useState('postgres');
  const [user, setUser] = useState('');
  const [password, setPassword] = useState('');
  const [result, setResult] = useState<Result | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setResult(null);
    setLoading(true);
    try {
      const body = useUri
        ? { connectionString: connectionString.trim() }
        : {
            host: host.trim(),
            port: port.trim() ? Number(port) : 5432,
            database: database.trim(),
            user: user.trim(),
            password,
          };
      const res = await fetch('/api/check-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      setResult(data);
    } catch (err) {
      setResult({ ok: false, error: (err as Error).message });
    } finally {
      setLoading(false);
    }
  }

  return (
    <main style={{ padding: 24, maxWidth: 520, margin: '0 auto', fontFamily: 'system-ui' }}>
      <h1 style={{ marginBottom: 8 }}>Проверка подключения к БД</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Введите параметры подключения (Supabase, Pigsty, любой PostgreSQL). Пароль не сохраняется и не логируется.
      </p>

      <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <input
            type="checkbox"
            checked={useUri}
            onChange={(e) => setUseUri(e.target.checked)}
          />
          Одна строка (connection URI)
        </label>

        {useUri ? (
          <div>
            <label style={{ display: 'block', marginBottom: 4, fontWeight: 500 }}>Connection string</label>
            <input
              type="password"
              placeholder="postgresql://user:password@host:5432/database"
              value={connectionString}
              onChange={(e) => setConnectionString(e.target.value)}
              style={{ width: '100%', padding: 8, boxSizing: 'border-box' }}
              autoComplete="off"
            />
          </div>
        ) : (
          <>
            <div>
              <label style={{ display: 'block', marginBottom: 4, fontWeight: 500 }}>Host</label>
              <input
                type="text"
                placeholder="aws-1-ap-south-1.pooler.supabase.com или 104.223.25.234"
                value={host}
                onChange={(e) => setHost(e.target.value)}
                style={{ width: '100%', padding: 8, boxSizing: 'border-box' }}
              />
            </div>
            <div style={{ display: 'flex', gap: 12 }}>
              <div style={{ flex: '0 0 80px' }}>
                <label style={{ display: 'block', marginBottom: 4, fontWeight: 500 }}>Port</label>
                <input
                  type="text"
                  value={port}
                  onChange={(e) => setPort(e.target.value)}
                  style={{ width: '100%', padding: 8, boxSizing: 'border-box' }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: 4, fontWeight: 500 }}>Database</label>
                <input
                  type="text"
                  value={database}
                  onChange={(e) => setDatabase(e.target.value)}
                  style={{ width: '100%', padding: 8, boxSizing: 'border-box' }}
                />
              </div>
            </div>
            <div>
              <label style={{ display: 'block', marginBottom: 4, fontWeight: 500 }}>User</label>
              <input
                type="text"
                placeholder="postgres или postgres.REF для Supabase"
                value={user}
                onChange={(e) => setUser(e.target.value)}
                style={{ width: '100%', padding: 8, boxSizing: 'border-box' }}
              />
            </div>
            <div>
              <label style={{ display: 'block', marginBottom: 4, fontWeight: 500 }}>Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                style={{ width: '100%', padding: 8, boxSizing: 'border-box' }}
                autoComplete="off"
              />
            </div>
          </>
        )}

        <button
          type="submit"
          disabled={loading || (useUri ? !connectionString.trim() : !host.trim() || !user.trim() || password === '')}
          style={{ padding: 10, cursor: loading ? 'wait' : 'pointer', fontWeight: 500 }}
        >
          {loading ? 'Проверка…' : 'Проверить подключение'}
        </button>
      </form>

      {result && (
        <div
          style={{
            marginTop: 24,
            padding: 16,
            borderRadius: 8,
            background: result.ok ? '#e8f5e9' : '#ffebee',
            color: result.ok ? '#1b5e20' : '#c62828',
          }}
        >
          {result.ok ? (
            <>✓ {result.message ?? 'Подключение успешно'} (БД: {result.db})</>
          ) : (
            <>✗ Ошибка: {result.error}</>
          )}
        </div>
      )}
    </main>
  );
}
