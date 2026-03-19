# Imperial: контракт URL изображений (MinIO / S3)

**Статус:** ссылки в БД (products.images, news.image, events.image) переведены с Supabase Storage на MinIO; в БД хранятся URL вида `https://db.sharconai.com/s3/<bucket>/<key>`. API по-прежнему переписывает любые оставшиеся Supabase-URL на лету.

## Целевой публичный префикс

Все новые и мигрированные объекты отдаются как:

`https://db.sharconai.com/s3/<minio-bucket>/<object-key>`

Бакеты Imperial: `imperial-product-images`, `imperial-news-images`, `imperial-event-images`, `imperial-furniture-images`, `imperial-site-images`.

## Хранение в БД (рекомендация)

| Вариант | Плюсы |
|--------|--------|
| **Относительный ключ** в бакете (например `2024/photo.jpg`) | Меньше дублирования домена; смена CDN — одна env на фронте. |
| **Полный URL** на `db.sharconai.com/s3/...` | Проще отладка; не зависит от `NEXT_PUBLIC_IMPERIAL_STORAGE_BASE`. |

Оба варианта поддерживаются на странице `/test-imperial`: полные URL идут в `<img src>` как есть; относительные пути собираются с базой из `NEXT_PUBLIC_IMPERIAL_STORAGE_BASE` (по умолчанию `https://db.sharconai.com/s3`).

## API (Next.js)

Эндпоинты `/api/imperial/products`, `/api/imperial/news`, `/api/imperial/events` отдают URL из БД; если в БД ещё есть старые Supabase-URL — они **переписываются** в MinIO на лету (см. [`frontend/lib/imperial-storage-url.ts`](../frontend/lib/imperial-storage-url.ts)). После миграции БД в ответах в основном уже MinIO-URL.

Проверка подключения: `/api/imperial/stats` возвращает счётчики по таблицам и поля `database`, `host` (текущая БД и хост) — на странице `/test-imperial` отображается «База: imperialdb · Хост: …», чтобы убедиться, что `DATABASE_URL_IMPERIAL` указывает на нужную БД (для Pigsty ожидается хост 104.223.25.234).

Переменные:

- `IMPERIAL_S3_PUBLIC_BASE` — база для переписанных URL (сервер). Если не задана, используется `NEXT_PUBLIC_IMPERIAL_STORAGE_BASE` или `https://db.sharconai.com/s3`.
- `NEXT_PUBLIC_IMPERIAL_STORAGE_BASE` — база для клиента при сборке URL из относительных путей.

Ссылки **WordPress** (`wp-content/uploads/...`) API **не** меняет: их нужно перенести в MinIO и обновить БД — скрипт ниже.

## Скрипты

| Задача | Файл |
|--------|------|
| Аудит доменов в `products.images`, `news.image`, `events.image` | [`scripts/audit_imperial_image_urls.sql`](../scripts/audit_imperial_image_urls.sql) (на сервере через `psql`) |
| Одноразово записать в БД замену Supabase → MinIO для `products.images` | [`scripts/sql/imperial_rewrite_supabase_urls_products.sql`](../scripts/sql/imperial_rewrite_supabase_urls_products.sql) (после проверки объектов в MinIO) |
| Импорт картинок WordPress в MinIO + UPDATE БД | [`scripts/imperial-wp-images-to-minio/`](../scripts/imperial-wp-images-to-minio/) (`npm install`, `.env` по `.env.example`, запуск **на хосте** с доступом к БД и MinIO) |

## Мониторинг

Периодически:

```sql
SELECT COUNT(*) FROM public.products
WHERE images::text ~ 'supabase\.co|wp-content';
```

Аналогично для `news.image`, `events.image`.
