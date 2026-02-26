'use client';

import { useEffect, useState } from 'react';

const STORAGE_BASE =
  (typeof process !== 'undefined' && process.env?.NEXT_PUBLIC_IMPERIAL_STORAGE_BASE) ||
  'http://104.223.25.234:9000';

function imageUrl(bucket: string, path: string | null | undefined): string | null {
  if (!path || typeof path !== 'string') return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  const clean = path.replace(/^\/+/, '');
  return `${STORAGE_BASE}/${bucket}/${clean}`;
}

type Stats = { ok: boolean; counts?: Record<string, number>; error?: string };
type NewsItem = {
  id: string;
  slug: string;
  title_en: string;
  title_ru: string | null;
  excerpt_en: string | null;
  image: string | null;
  created_at: string;
};
type ProductItem = {
  id: string;
  slug: string;
  name: string;
  price: number | null;
  image_urls: string[] | string | null;
  created_at: string;
};
type EventItem = {
  id: string;
  title_en: string | null;
  title_ru: string | null;
  image: string | null;
  start_date: string | null;
  created_at: string;
};

export default function TestImperialPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [news, setNews] = useState<NewsItem[] | null>(null);
  const [products, setProducts] = useState<ProductItem[] | null>(null);
  const [events, setEvents] = useState<EventItem[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [errors, setErrors] = useState<Record<string, string>>({});

  useEffect(() => {
    const base = '';
    Promise.all([
      fetch(`${base}/api/imperial/stats`).then((r) => r.json()) as Promise<Stats>,
      fetch(`${base}/api/imperial/news`).then((r) => (r.ok ? r.json() : r.json().then((e) => ({ __error: (e && (e.details || e.error)) || 'Failed' })))),
      fetch(`${base}/api/imperial/products`).then((r) => (r.ok ? r.json() : r.json().then((e) => ({ __error: (e && (e.details || e.error)) || 'Failed' })))),
      fetch(`${base}/api/imperial/events`).then((r) => (r.ok ? r.json() : r.json().then((e) => ({ __error: (e && (e.details || e.error)) || 'Failed' })))),
    ])
      .then(([s, n, p, e]) => {
        setStats(s);
        if (Array.isArray(n)) setNews(n);
        else if (n && typeof n === 'object' && '__error' in n) setErrors((prev) => ({ ...prev, news: String((n as { __error?: string }).__error) }));
        if (Array.isArray(p)) setProducts(p);
        else if (p && typeof p === 'object' && '__error' in p) setErrors((prev) => ({ ...prev, products: String((p as { __error?: string }).__error) }));
        if (Array.isArray(e)) setEvents(e);
        else if (e && typeof e === 'object' && '__error' in e) setErrors((prev) => ({ ...prev, events: String((e as { __error?: string }).__error) }));
      })
      .catch((err) => setErrors((prev) => ({ ...prev, global: err.message })))
      .finally(() => setLoading(false));
  }, []);

  const productImageUrls = (image_urls: ProductItem['image_urls']): string[] => {
    if (!image_urls) return [];
    if (Array.isArray(image_urls)) return image_urls;
    if (typeof image_urls === 'string') {
      try {
        const parsed = JSON.parse(image_urls);
        return Array.isArray(parsed) ? parsed : [image_urls];
      } catch {
        return [image_urls];
      }
    }
    return [];
  };

  if (loading) {
    return (
      <main style={styles.main}>
        <div style={styles.card}>
          <p style={styles.muted}>Загрузка… проверка подключения к imperialdb и MinIO.</p>
        </div>
      </main>
    );
  }

  return (
    <main style={styles.main}>
      <div style={styles.wrapper}>
        <h1 style={styles.title}>Тест: Imperial → imperialdb + MinIO</h1>
        <p style={styles.muted}>
          Vercel → API routes → PostgreSQL (imperialdb) на 104.223.25.234:6432 · Файлы с MinIO
        </p>

        <section style={styles.card}>
          <h2 style={styles.h2}>Подключение к БД</h2>
          {stats?.ok ? (
            <p style={{ color: 'var(--success)' }}>
              ✓ DATABASE_URL_IMPERIAL настроен. Записей в таблицах:
            </p>
          ) : (
            <p style={{ color: 'var(--error)' }}>
              ✗ Ошибка: {stats?.error ?? errors.global ?? 'DATABASE_URL_IMPERIAL не задан в Vercel'}
            </p>
          )}
          {stats?.counts && (
            <ul style={styles.countList}>
              {Object.entries(stats.counts).map(([table, count]) => (
                <li key={table}>
                  <strong>{table}</strong>: {count >= 0 ? count : '—'}
                </li>
              ))}
            </ul>
          )}
        </section>

        <section style={styles.card}>
          <h2 style={styles.h2}>Новости (public.news)</h2>
          {errors.news && <p style={{ color: 'var(--error)' }}>{errors.news}</p>}
          {news && news.length === 0 && <p style={styles.muted}>Записей нет.</p>}
          {news && news.length > 0 && (
            <div style={styles.grid}>
              {news.slice(0, 6).map((item) => {
                const src = imageUrl('imperial-news-images', item.image);
                return (
                  <div key={item.id} style={styles.tile}>
                    {src && (
                      <img src={src} alt="" style={styles.thumb} referrerPolicy="no-referrer" />
                    )}
                    <div>
                      <strong>{item.title_ru || item.title_en}</strong>
                      <br />
                      <small style={styles.muted}>
                        {new Date(item.created_at).toLocaleString('ru')}
                      </small>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>

        <section style={styles.card}>
          <h2 style={styles.h2}>Продукты (public.products)</h2>
          {errors.products && <p style={{ color: 'var(--error)' }}>{errors.products}</p>}
          {products && products.length === 0 && <p style={styles.muted}>Записей нет.</p>}
          {products && products.length > 0 && (
            <div style={styles.grid}>
              {products.slice(0, 6).map((item) => {
                const urls = productImageUrls(item.image_urls);
                const firstUrl = urls[0]
                  ? imageUrl('imperial-product-images', urls[0])
                  : null;
                return (
                  <div key={item.id} style={styles.tile}>
                    {firstUrl && (
                      <img src={firstUrl} alt="" style={styles.thumb} referrerPolicy="no-referrer" />
                    )}
                    <div>
                      <strong>{item.name}</strong>
                      {item.price != null && (
                        <>
                          <br />
                          <small>{item.price}</small>
                        </>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>

        <section style={styles.card}>
          <h2 style={styles.h2}>События (public.events)</h2>
          {errors.events && <p style={{ color: 'var(--error)' }}>{errors.events}</p>}
          {events && events.length === 0 && <p style={styles.muted}>Записей нет.</p>}
          {events && events.length > 0 && (
            <div style={styles.grid}>
              {events.slice(0, 6).map((item) => {
                const src = imageUrl('imperial-event-images', item.image);
                return (
                  <div key={item.id} style={styles.tile}>
                    {src && (
                      <img src={src} alt="" style={styles.thumb} referrerPolicy="no-referrer" />
                    )}
                    <div>
                      <strong>{item.title_ru || item.title_en || item.id}</strong>
                      {item.start_date && (
                        <>
                          <br />
                          <small style={styles.muted}>
                            {new Date(item.start_date).toLocaleDateString('ru')}
                          </small>
                        </>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>

        <footer style={styles.footer}>
          <a href="/">Главная</a>
          {' · '}
          Деплой: Vercel · БД: imperialdb · Файлы: MinIO
        </footer>
      </div>
    </main>
  );
}

const styles: Record<string, React.CSSProperties> = {
  main: {
    padding: '2rem 1rem',
    maxWidth: 900,
    margin: '0 auto',
  },
  wrapper: {},
  title: { fontSize: '1.5rem', marginBottom: '0.25rem' },
  h2: { fontSize: '1.1rem', marginTop: 0, marginBottom: '0.75rem' },
  card: {
    background: 'var(--surface)',
    border: '1px solid var(--border)',
    borderRadius: 8,
    padding: '1rem 1.25rem',
    marginBottom: '1rem',
  },
  muted: { color: 'var(--muted)', fontSize: '0.9rem' },
  countList: { margin: '0.5rem 0 0', paddingLeft: '1.25rem' },
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))',
    gap: '1rem',
  },
  tile: {
    border: '1px solid var(--border)',
    borderRadius: 6,
    overflow: 'hidden',
    fontSize: '0.9rem',
  },
  thumb: {
    width: '100%',
    height: 100,
    objectFit: 'cover',
    display: 'block',
    background: 'var(--border)',
  },
  footer: { marginTop: '2rem', fontSize: '0.85rem', color: 'var(--muted)' },
};
