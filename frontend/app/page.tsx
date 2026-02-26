'use client';

import { useEffect, useState } from 'react';

type NewsItem = {
  id: string;
  slug: string;
  title_en: string;
  title_ru: string | null;
  excerpt_en: string;
  excerpt_ru: string | null;
  created_at: string;
  tags: string[];
};

type Health = { ok: boolean; db?: string; error?: string; message?: string };

export default function Home() {
  const [health, setHealth] = useState<Health | null>(null);
  const [news, setNews] = useState<NewsItem[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const base = typeof window !== 'undefined' ? '' : '';
    Promise.all([
      fetch(`${base}/api/health`).then((r) => r.json()) as Promise<Health>,
      fetch(`${base}/api/news`).then((r) => {
        if (!r.ok) return r.json().then((e) => ({ error: e.error || e.details || 'Failed' }));
        return r.json();
      }),
    ])
      .then(([h, n]) => {
        setHealth(h);
        if (Array.isArray(n)) setNews(n);
        else if (n && typeof n === 'object' && 'error' in n) setError(String((n as { error?: string }).error));
      })
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <main style={styles.main}>
        <div style={styles.card}>
          <p style={styles.muted}>Проверка подключения к БД app…</p>
        </div>
      </main>
    );
  }

  return (
    <main style={styles.main}>
      <div style={styles.wrapper}>
        <h1 style={styles.title}>Pigsty — тест подключения к БД app</h1>
        <p style={styles.muted}>
          Фронтенд на Vercel → API routes → PostgreSQL (PgBouncer) на Pigsty
        </p>

        <section style={styles.card}>
          <h2 style={styles.h2}>Статус подключения</h2>
          {health?.ok ? (
            <p style={{ color: 'var(--success)' }}>
              ✓ Подключение к БД успешно. База: <strong>{health.db ?? '—'}</strong>
            </p>
          ) : (
            <p style={{ color: 'var(--error)' }}>
              ✗ Ошибка: {health?.error ?? error ?? 'Неизвестная ошибка'}
            </p>
          )}
        </section>

        <section style={styles.card}>
          <h2 style={styles.h2}>Новости из таблицы public.news</h2>
          {error && !health?.ok && (
            <p style={{ color: 'var(--error)' }}>Не удалось загрузить список: {error}</p>
          )}
          {news && news.length === 0 && (
            <p style={styles.muted}>Записей пока нет. Выполните seed: sql/seed_news_test.sql</p>
          )}
          {news && news.length > 0 && (
            <ul style={styles.list}>
              {news.map((item) => (
                <li key={item.id} style={styles.li}>
                  <strong>{item.title_ru || item.title_en}</strong>
                  <span style={styles.muted}> — {item.slug}</span>
                  <br />
                  <small style={styles.muted}>
                    {new Date(item.created_at).toLocaleString('ru')}
                    {item.tags?.length ? ` · ${item.tags.join(', ')}` : ''}
                  </small>
                </li>
              ))}
            </ul>
          )}
        </section>

        <footer style={styles.footer}>
          <a href="/test-imperial">Тест Imperial (imperialdb + MinIO)</a>
          {' · '}
          <a href="/check-db">Проверка подключения к любой БД</a>
          {' · '}
          <a href="https://pigsty.io" target="_blank" rel="noopener noreferrer">
            Pigsty
          </a>
          {' · '}
          Деплой: Vercel
        </footer>
      </div>
    </main>
  );
}

const styles: Record<string, React.CSSProperties> = {
  main: {
    padding: '2rem 1rem',
    maxWidth: 720,
    margin: '0 auto',
  },
  wrapper: {},
  title: {
    fontSize: '1.5rem',
    marginBottom: '0.25rem',
  },
  h2: {
    fontSize: '1.1rem',
    marginTop: 0,
    marginBottom: '0.75rem',
  },
  muted: {
    color: 'var(--muted)',
    fontSize: '0.9rem',
  },
  card: {
    background: 'var(--surface)',
    border: '1px solid var(--border)',
    borderRadius: 8,
    padding: '1.25rem',
    marginBottom: '1rem',
  },
  list: {
    listStyle: 'none',
    padding: 0,
    margin: 0,
  },
  li: {
    padding: '0.5rem 0',
    borderBottom: '1px solid var(--border)',
  },
  footer: {
    marginTop: '2rem',
    color: 'var(--muted)',
    fontSize: '0.85rem',
  },
};
