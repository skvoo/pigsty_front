/**
 * Same as frontend/lib/imperial-storage-url.ts — keep in sync.
 */

const DEFAULT_S3_BASE = 'https://db.sharconai.com/s3';

function getS3Base(): string {
  const b =
    process.env.IMPERIAL_S3_PUBLIC_BASE ||
    process.env.NEXT_PUBLIC_IMPERIAL_STORAGE_BASE ||
    DEFAULT_S3_BASE;
  return b.replace(/\/+$/, '');
}

const SUPABASE_TO_MINIO_BUCKET: Record<string, string> = {
  'product-images': 'imperial-product-images',
  'event-images': 'imperial-event-images',
  'news-images': 'imperial-news-images',
  'furniture-images': 'imperial-furniture-images',
  'site-images': 'imperial-site-images',
};

export function rewriteImperialMediaUrl(
  url: string | null | undefined
): string | null {
  if (url == null || url === '') return null;
  const u = String(url).trim();
  const base = getS3Base();

  if (/^https?:\/\//i.test(u)) {
    if (u.startsWith(`${base}/`) || u === base) return u;

    const m = u.match(
      /\/storage\/v1\/object\/public\/([^/]+)\/([^?#]+)/i
    );
    if (m) {
      const supaBucket = m[1];
      const key = decodeURIComponent(m[2]);
      const minioBucket = SUPABASE_TO_MINIO_BUCKET[supaBucket];
      if (minioBucket) {
        const encodedKey = key
          .split('/')
          .map((seg) => encodeURIComponent(seg))
          .join('/');
        return `${base}/${minioBucket}/${encodedKey}`;
      }
    }
    if (/supabase\.co/i.test(u)) {
      const m2 = u.match(/\/storage\/v1\/object\/public\/([^/]+)\/([^?#]+)/i);
      if (m2) {
        const supaBucket = m2[1];
        const key = decodeURIComponent(m2[2]);
        const minioBucket = SUPABASE_TO_MINIO_BUCKET[supaBucket] ?? `imperial-${supaBucket}`;
        const encodedKey = key.split('/').map((seg) => encodeURIComponent(seg)).join('/');
        return `${base}/${minioBucket}/${encodedKey}`;
      }
    }
    return u;
  }

  return u;
}

function rewriteProductImageEntry(x: unknown): unknown {
  if (x && typeof x === 'object' && typeof (x as { url?: unknown }).url === 'string') {
    const o = x as Record<string, unknown>;
    const nu = rewriteImperialMediaUrl(o.url as string);
    if (nu != null && nu !== o.url) return { ...o, url: nu };
    return x;
  }
  if (typeof x === 'string') {
    return rewriteImperialMediaUrl(x) ?? x;
  }
  return x;
}

export function rewriteImperialProductImages(
  raw: unknown
): string[] | unknown[] | string | null {
  if (raw == null) return null;

  if (Array.isArray(raw)) {
    return raw.map((x) => rewriteProductImageEntry(x));
  }

  if (typeof raw === 'string') {
    const t = raw.trim();
    if (!t) return null;
    try {
      const j = JSON.parse(t) as unknown;
      if (Array.isArray(j)) {
        return j.map((x) => rewriteProductImageEntry(x));
      }
    } catch {
      /* not JSON */
    }
    return rewriteImperialMediaUrl(t) ?? t;
  }

  return null;
}
