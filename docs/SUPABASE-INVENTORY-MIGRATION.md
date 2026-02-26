# Полная инвентаризация Supabase Cloud перед миграцией на Pigsty

Чеклист того, что нужно **изучить и зафиксировать** по каждому проекту Supabase (БД, Storage, Auth, дополнения, Realtime), чтобы спланировать миграцию на Pigsty и ничего не упустить.

---

## 1. База данных (PostgreSQL)

### 1.1 Автоматическая инвентаризация (SQL)

Запустите один раз **по каждому проекту** (подставьте свой connection string):

```bash
# Проект 1
export SOURCE_DB_URL="postgresql://postgres.PROJECT1_REF:PASSWORD@db.PROJECT1_REF.supabase.com:5432/postgres"
psql "$SOURCE_DB_URL" -f sql/supabase_inventory.sql > inventory_project1.txt

# Проект 2
export SOURCE_DB_URL="postgresql://postgres.PROJECT2_REF:PASSWORD@db.PROJECT2_REF.supabase.com:5432/postgres"
psql "$SOURCE_DB_URL" -f sql/supabase_inventory.sql > inventory_project2.txt
```

Пароль берите из `supabase-credentials.env` или из Dashboard → Project Settings → Database. Файлы `inventory_*.txt` можно передать для анализа (в них нет паролей).

**Что собирает скрипт:** версия Postgres, размер БД, расширения, схемы и размеры, таблицы, роли, RLS и политики, Storage (buckets и число объектов), публикации Realtime, функции и триггеры в `public`, число пользователей в `auth.users`.

Если схем `storage` или `auth` нет, запросы к ним выдадут ошибку — это нормально, остальной вывод будет.

### 1.2 Что вынести для Pigsty

| Элемент | Действие на Pigsty |
|--------|---------------------|
| **Расширения** | Добавить в `pg_extensions` кластера или включить в БД после создания. Расширения Supabase-only (`pgsodium`, `pg_graphql`, `pg_net`) на обычном Postgres нет — либо исключить из дампа, либо заменить своей логикой. |
| **Схемы** | Решить: переносим только `public` или ещё `auth`/`storage`/`realtime` (для полного self-host Supabase). При переносе только данных — дамп с `--exclude-schema=auth,storage,realtime,...`. |
| **Роли** | В дампе заменить `supabase_admin` → `postgres`. При необходимости завести в `pg_users` пользователей приложения и роли для PostgREST (`anon`, `authenticated`, `service_role`, `authenticator`). |
| **RLS** | После восстановления проверить политики; при переходе на свой API возможно упрощение под одного пользователя БД. |

При миграции **нескольких баз** рекомендуется экспорт через **Supabase CLI** (один сценарий на все проекты, правка текстовых SQL) — см. [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](./MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md) §4.0 и раздел «Миграция нескольких БД».

---

## 2. Storage (файлы и бакеты)

Дамп БД переносит только **метаданные** (таблицы `storage.buckets`, `storage.objects`). Сами файлы нужно копировать отдельно.

### 2.1 Что зафиксировать

**Из SQL (скрипт уже выводит):**
- Список бакетов (`storage.buckets`: имя, public/private, лимиты размера, MIME).
- Количество объектов по бакету и ориентировочный объём.

**Из Dashboard вручную (для каждого проекта):**
- **Storage → Buckets:** названия бакетов, публичный/приватный, лимиты (если меняли).
- **Storage → Policies:** какие RLS-политики стоят на бакетах (для воспроизведения на Pigsty или в своём хранилище).
- Оценка объёма файлов (Dashboard или по числу объектов и среднему размеру) — для планирования переноса.

### 2.2 Перенос файлов на Pigsty

- Файлы переносятся **отдельно от дампа**: через [Supabase Storage API](https://supabase.com/docs/reference/javascript/storage-from-list) (list + download) и загрузку в self-hosted Storage или в MinIO/S3. Официально: [Migrate storage objects](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).
- Если на Pigsty поднят Supabase (контейнер storage), после переноса БД нужно восстановить метаданные и загрузить файлы в те же пути; политики доступа задать заново или перенести из дампа.

---

## 3. Auth (GoTrue)

### 3.1 Что зафиксировать

**Из SQL (скрипт выводит):**
- Количество записей в `auth.users` (масштаб миграции пользователей).

**Из Dashboard вручную:**
- **Authentication → Providers:** какие включены (Email, Magic Link, Google, GitHub, и т.д.), нужны ли те же на Pigsty.
- **Authentication → URL Configuration:** Site URL, Redirect URLs — при переносе на свой домен обновить.
- **Authentication → Email Templates:** кастомизация (опционально).
- Используется ли **кастомный SMTP** (Authentication → Settings) — для воспроизведения на self-host нужно будет настроить свой SMTP.

### 3.2 На Pigsty

- При **полном self-host** Supabase: контейнер Auth (GoTrue) подключается к вашей БД с перенесённой схемой `auth`; провайдеры и URL настраиваются в переменных окружения/конфиге.
- При **гибриде** (Auth в Cloud, данные в Pigsty): Auth не переносится, в инвентаризации достаточно понимать, что логины остаются в Supabase.

---

## 4. Add-ons (дополнения проекта)

В Supabase Dashboard у проекта могут быть **дополнения** (платные или в рамках плана).

### 4.1 Где смотреть

- **Project Settings → Add-ons** (или Billing / Add-ons в боковом меню).
- Типичные примеры: **Logflare** (логи), **Custom Domains**, **Pause project**, дополнительные ресурсы.

### 4.2 Что записать

- Список включённых add-ons и для чего они используются.
- На Pigsty часть функциональности может быть своей: логи — в Loki/Grafana (Pigsty уже даёт метрики/логи), домены — через Nginx, пауза — не нужна при self-host.

---

## 5. Realtime

### 5.1 Что зафиксировать

**Из SQL (скрипт выводит):**
- Публикации (`pg_publication`): какие таблицы в Realtime.

**Из кода/документации:**
- Где в приложении используется `supabase.channel()` / Realtime — какие таблицы и события (INSERT/UPDATE/DELETE).

### 5.2 На Pigsty

- Для Realtime нужен `wal_level = logical` и настройка публикаций; контейнер Realtime подключается к той же БД. См. [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](./MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md) §8.3 и [SUPABASE-STUDIO-PIGSTY.md](./SUPABASE-STUDIO-PIGSTY.md).
- Если Realtime не используете — контейнер можно не поднимать или отключить.

---

## 6. Edge Functions

### 6.1 Что зафиксировать

- **Dashboard → Edge Functions:** список функций и примерное назначение.
- Или в репозитории проекта — папка `supabase/functions/` (если используете CLI).

### 6.2 На Pigsty

- Edge Functions на self-host Supabase разворачиваются отдельно (Deno runtime); либо заменяются на свой бэкенд (API routes, отдельный сервис). Нужно перечислить, что чем заменяем.

---

## 7. Прочее из Dashboard

- **Project Settings → General:** Project ref, регион, версия Postgres (уже есть в SQL).
- **API:** Project URL, anon key, service_role key — для переключения приложений на Pigsty (свой URL и ключи при полном self-host) или для скриптов переноса Storage.
- **Database:** Connection string (уже используете для SQL-инвентаризации и дампа).

---

## 8. Сводная таблица: что откуда брать

| Раздел        | Источник              | Что записать / сохранить |
|---------------|------------------------|---------------------------|
| БД            | `sql/supabase_inventory.sql` | Вывод в `inventory_project1.txt` и `inventory_project2.txt` |
| Storage       | SQL + Dashboard        | Бакеты, политики, объём; план переноса файлов |
| Auth          | SQL + Dashboard        | Число пользователей; провайдеры; SMTP; URL |
| Add-ons       | Dashboard → Add-ons    | Список add-ons и необходимость на Pigsty |
| Realtime      | SQL + код приложения   | Публикации; использование в коде |
| Edge Functions| Dashboard / репо        | Список функций и план замены |
| API/ключи     | Dashboard → API        | URL, anon/service_role при полном переносе |

---

## 9. Связанные документы

- [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](./MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md) — пошаговая миграция БД и переключение приложений.
- [SUPABASE-STUDIO-PIGSTY.md](./SUPABASE-STUDIO-PIGSTY.md) — Studio и Realtime на Pigsty.
- [FRONTEND-INTEGRATION.md](./FRONTEND-INTEGRATION.md) — гибрид (Auth в Cloud, данные в Pigsty).

После заполнения чеклиста по обоим проектам можно составить точный план: какие БД создавать на Pigsty, что исключать из дампа, какие расширения и роли добавить, как переносить Storage и нужно ли поднимать Auth/Realtime на Pigsty.
