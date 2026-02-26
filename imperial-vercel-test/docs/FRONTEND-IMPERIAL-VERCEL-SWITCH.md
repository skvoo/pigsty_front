# Imperial: переключение с Supabase Cloud на наш сервер (Vercel)

Инструкция для фронтенда: что изменить в проекте **Imperial**, чтобы данные и файлы шли с нашего сервера (Pigsty: БД **imperialdb**, файлы в **MinIO**), а не с Supabase Cloud. Деплой — **Vercel**.

---

## 1. Как сейчас (Supabase Cloud)

- **БД:** фронт или API обращается к Supabase через клиент: `createClient(NEXT_PUBLIC_SUPABASE_URL, anon_key)`, запросы `supabase.from('news')`, `supabase.from('products')` и т.д.
- **Файлы (Storage):** загрузка и отображение через `supabase.storage.from('event-images')`, `supabase.storage.from('product-images')` и т.д.

---

## 2. Что будет после переключения

- **БД:** данные из **imperialdb** на сервере **104.223.25.234** через ваш API (`fetch('/api/imperial/...')`).
- **Файлы:** MinIO на том же сервере; отображение по URL `http://104.223.25.234:9000/<bucket>/<path>`.

---

## 3. Переменные в Vercel

В **Settings → Environment Variables**:

| Переменная | Значение |
|------------|----------|
| `DATABASE_URL_IMPERIAL` | `postgresql://USER:PASSWORD@104.223.25.234:6432/imperialdb` |

Для картинок по умолчанию используется `http://104.223.25.234:9000`; при необходимости задать `NEXT_PUBLIC_IMPERIAL_STORAGE_BASE`.

**Важно:** на сервере в PgBouncer должно быть разрешено подключение к БД `imperialdb` с внешних IP (добавить правило в `pgb_hba_rules` в pigsty.yml).

---

## 4. Тест на Vercel

После деплоя открыть **`https://<проект>.vercel.app/test-imperial`**. На странице: статус БД, счётчики по таблицам, записи из news/products/events с картинками из MinIO.
