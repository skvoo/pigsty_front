# Инвентаризация для тестовой миграции: GD-lounge и imperial

Результат прохождения чеклиста из [SUPABASE-INVENTORY-MIGRATION.md](./SUPABASE-INVENTORY-MIGRATION.md) по проектам **GD-lounge** и **imperial** перед тестовой миграцией на Pigsty (БД → gdloungedb/imperialdb, Storage → MinIO).

Источник сводки по БД и Storage: [MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md](./MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md).

---

## 1. База данных (PostgreSQL)

### 1.1 GD-lounge

| Параметр | Значение |
|----------|----------|
| Размер БД | 12 MB |
| Postgres | 17.6 |
| Целевая БД на Pigsty | `gdloungedb` |

**Расширения:** исключить при восстановлении: pg_graphql, supabase_vault. Включить при необходимости: pg_stat_statements, pgcrypto, uuid-ossp.

**Таблицы public (бизнес-данные):** news (472 kB), leads (64 kB), gallery, menu_items, menu_categories, events (по 32 kB).

**RLS в public:** события, галерея, лиды, меню, новости — политики на SELECT/INSERT для public или authenticated.

**Инвентаризация (SQL):** запустить `psql "$SOURCE_DB_URL" -f sql/supabase_inventory.sql > inventory_gdlounge.txt` по connection string GD-lounge и при необходимости обновить этот раздел.

### 1.2 imperial

| Параметр | Значение |
|----------|----------|
| Размер БД | 17 MB |
| Postgres | 17.6 |
| Целевая БД на Pigsty | `imperialdb` |

**Расширения:** те же, что у GD-lounge (pg_graphql, supabase_vault — исключить при восстановлении).

**Таблицы public (бизнес-данные):** products (1400 kB), furniture_items (624 kB), product_categories (312 kB), categories (232 kB), furniture_item_categories (184 kB), news (168 kB), events (144 kB), orders (128 kB), brand_collection_categories (128 kB), users (96 kB), furniture_categories, furniture_brands (80 kB), brand_collections (64 kB), order_items (48 kB), brands (40 kB), admin_users, refunds (32 kB), product_count_cache (16 kB).

**RLS в public:** в инвентаризации не перечислены — проверить после переноса.

**Функции в public:** refresh_product_count_cache, set_events_updated_at, update_updated_at_column.

**Триггеры:** events_updated_at → set_events_updated_at; furniture_items_updated_at, orders_updated_at, products_updated_at → update_updated_at_column.

**Инвентаризация (SQL):** запустить по connection string imperial и при необходимости обновить этот раздел.

---

## 2. Storage (бакеты и объём)

### 2.1 GD-lounge

| Бакет | Тип | Объектов | Ориентировочный объём |
|-------|-----|----------|------------------------|
| assets | public | 112 | ~180 MB |

Лимит файла 50 MB, MIME image/*, video/*.

**Целевой бакет MinIO для теста:** `gd-lounge-assets`.

### 2.2 imperial

| Бакет | Тип | Объектов | Ориентировочный объём |
|-------|-----|----------|------------------------|
| event-images | public | 4 | ~713 kB |
| furniture-images | public | — | см. Dashboard |
| news-images | public | 5 | ~7.7 MB |
| product-images | public | 1240 | ~134 MB |
| site-images | public | 27 | ~6 MB |

Лимиты и MIME в Dashboard не заданы (null).

**Целевые бакеты MinIO для теста:** `imperial-event-images`, `imperial-furniture-images`, `imperial-news-images`, `imperial-product-images`, `imperial-site-images` (или один бакет `imperial-assets` с префиксами по типу).

---

## 3. Auth (GoTrue)

| Проект | Auth users (из инвентаризации) | Решение для теста |
|--------|--------------------------------|-------------------|
| GD-lounge | 0 | Auth на Pigsty для теста не поднимать. Если фронт не логинит — не трогать. |
| imperial | 0 | То же. |

**Dashboard (проверить вручную):** Authentication → Providers (Email, Magic Link, OAuth), URL Configuration, кастомный SMTP. При гибриде — оставить Auth в Cloud, данные и файлы на Pigsty.

---

## 4. Realtime

| Проект | Публикация в БД | Использование в коде |
|--------|------------------|----------------------|
| GD-lounge | supabase_realtime | Проверить: есть ли `supabase.channel()` в коде. Если нет — не настраивать на Pigsty. |
| imperial | supabase_realtime | То же. |

Для тестовой миграции Realtime не настраивать, если подписки в реальном времени не используются.

---

## 5. Edge Functions

| Проект | Edge Functions |
|--------|----------------|
| GD-lounge | Проверить в Dashboard → Edge Functions и в репо (supabase/functions/). Записать список и назначение. |
| imperial | То же. |

Если есть — заменить на API routes бэкенда или отдельный сервис.

---

## 6. Add-ons

По каждому проекту: **Project Settings → Add-ons** — список включённых дополнений (Logflare, Custom Domains и т.д.) и нужность на Pigsty.

---

## 7. Сводка: что переносим в тесте

| Сервис | GD-lounge | imperial |
|--------|-----------|----------|
| **Database** | Да → gdloungedb | Да → imperialdb |
| **Storage** | Да → MinIO (gd-lounge-assets) | Да → MinIO (бакеты imperial-*) |
| **Auth** | Нет (0 users) или гибрид (Cloud) | Нет или гибрид |
| **Realtime** | Не настраивать, если не используется | То же |
| **Edge Functions** | Заменить на API при наличии | То же |

---

## 8. Связанные документы

- [SUPABASE-INVENTORY-MIGRATION.md](./SUPABASE-INVENTORY-MIGRATION.md) — полный чеклист инвентаризации.
- [MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md](./MIGRATION-PROJECTS-GD-LOUNGE-IMPERIAL.md) — команды экспорта/восстановления БД и сводка по таблицам/бакетам.
- [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](./MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md) — полная инструкция по миграции БД.
