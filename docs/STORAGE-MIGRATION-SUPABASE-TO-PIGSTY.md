# Перенос Supabase Cloud Storage на Pigsty

Пошаговая инструкция по переносу файлов из Supabase Cloud Storage на сервер Pigsty. Для **нескольких проектов** шаги повторяются для каждого проекта.

---

## 1. Что переносится

| Что | Как |
|-----|-----|
| **Метаданные Storage** (бакеты, пути, типы файлов, RLS) | Вместе с дампом БД — таблицы `storage.buckets`, `storage.objects`. Восстанавливаются при импорте схемы/данных по [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](./MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md). |
| **Сами файлы** | **Отдельно** — дампом БД не переносятся. Нужен скрипт: скачать из Cloud по Storage API и загрузить в Storage на Pigsty. |

Сначала выполняете миграцию БД (включая схему `storage`), затем переносите файлы по этой инструкции.

---

## 2. Что нужно перед началом

- **Миграция БД уже выполнена** для этого проекта: целевая БД на Pigsty создана, дамп восстановлен **со схемой storage** (не исключали `--exclude-schema=storage`). Бакеты в `storage.buckets` уже есть на Pigsty.
- **На Pigsty поднят Supabase** с рабочим контейнером **Storage** (Kong на порту 8000). Если контейнеры падали — см. [SUPABASE-CONTAINERS-FIX-2026-02.md](./Reports/SUPABASE-CONTAINERS-FIX-2026-02.md) и `sql/supabase_fix_failing_containers.sql`.
- **Доступ к Supabase Cloud:** Project URL и **Service Role Key** (Dashboard → Project Settings → API → `service_role` secret).
- **Доступ к Supabase на Pigsty:** URL (например `http://104.223.25.234:8000`) и **Service Role Key** вашего self-hosted инстанса. Ключ берётся из конфига приложения Supabase в `pigsty.yml` (JWT/ключи API) или из переменных окружения контейнеров.
- **Node.js** установлен (для скрипта переноса).

---

## 3. Порядок действий (один проект)

1. Собрать инвентаризацию Storage по проекту Cloud (§4).
2. Убедиться, что БД этого проекта на Pigsty восстановлена **со схемой storage** и бакеты созданы.
3. Запустить скрипт переноса файлов (§5) для этого проекта.
4. Проверить объём и политики на Pigsty (§6).

Для **второго и последующих проектов** повторить шаги 1–4, подставляя свои `OLD_PROJECT_URL` и `OLD_PROJECT_SERVICE_KEY`; целевой URL и ключ Pigsty общие.

---

## 4. Инвентаризация Storage (по каждому проекту)

Перед переносом зафиксируйте:

- **Список бакетов** и тип (public/private). Скрипт `sql/supabase_inventory.sql` выводит бакеты и число объектов — запустите по connection string Cloud:
  ```bash
  export SOURCE_DB_URL="postgresql://postgres.PROJECT_REF:PASSWORD@db.PROJECT_REF.supabase.com:5432/postgres"
  psql "$SOURCE_DB_URL" -f sql/supabase_inventory.sql > inventory_storage.txt
  ```
- **Политики RLS** на бакетах (Dashboard → Storage → Policies) — после переноса их нужно проверить или задать заново на Pigsty.
- **Оценка объёма** (число объектов, суммарный размер) — чтобы планировать время и пагинацию в скрипте.

Подробнее: [SUPABASE-INVENTORY-MIGRATION.md](./SUPABASE-INVENTORY-MIGRATION.md), раздел 2.

---

## 5. Скрипт переноса файлов

Скрипт читает объекты из таблицы `storage.objects` старого проекта, скачивает каждый файл через Storage API и загружает в Storage на Pigsty. Бакеты на стороне Pigsty должны уже существовать (они создаются при восстановлении дампа БД со схемой `storage`).

### 5.1 Установка зависимостей

```bash
mkdir storage-migration && cd storage-migration
npm init -y
npm install @supabase/supabase-js
```

### 5.2 Переменные окружения

Создайте файл `.env` (не коммитить):

```env
# Проект Supabase Cloud (источник)
OLD_PROJECT_URL=https://xxxx.supabase.co
OLD_PROJECT_SERVICE_KEY=eyJhbGc...

# Supabase на Pigsty (приёмник)
NEW_PROJECT_URL=http://104.223.25.234:8000
NEW_PROJECT_SERVICE_KEY=eyJhbGc...
```

- Cloud: URL и Service Role Key из Dashboard → Project Settings → API.
- Pigsty: URL — ваш Kong/API (порт 8000), Service Role Key — из конфига Supabase на сервере (см. §2).

### 5.3 Скрипт с пагинацией

Сохраните как `migrate-storage.js`:

```javascript
require('dotenv').config()
const { createClient } = require('@supabase/supabase-js')

const OLD_PROJECT_URL = process.env.OLD_PROJECT_URL
const OLD_PROJECT_SERVICE_KEY = process.env.OLD_PROJECT_SERVICE_KEY
const NEW_PROJECT_URL = process.env.NEW_PROJECT_URL
const NEW_PROJECT_SERVICE_KEY = process.env.NEW_PROJECT_SERVICE_KEY

const BATCH_SIZE = 1000

if (!OLD_PROJECT_URL || !OLD_PROJECT_SERVICE_KEY || !NEW_PROJECT_URL || !NEW_PROJECT_SERVICE_KEY) {
  console.error('Заполните .env: OLD_* и NEW_* переменные')
  process.exit(1)
}

const oldRestClient = createClient(OLD_PROJECT_URL, OLD_PROJECT_SERVICE_KEY, {
  db: { schema: 'storage' },
})
const oldStorageClient = createClient(OLD_PROJECT_URL, OLD_PROJECT_SERVICE_KEY)
const newStorageClient = createClient(NEW_PROJECT_URL, NEW_PROJECT_SERVICE_KEY)

async function migrate() {
  let offset = 0
  let totalMoved = 0
  let totalErrors = 0

  while (true) {
    const { data: objects, error } = await oldRestClient
      .from('objects')
      .select('id, bucket_id, name, metadata')
      .range(offset, offset + BATCH_SIZE - 1)

    if (error) {
      console.error('Ошибка чтения storage.objects:', error)
      throw error
    }
    if (!objects || objects.length === 0) break

    for (const obj of objects) {
      try {
        const { data: fileData, error: downloadError } = await oldStorageClient.storage
          .from(obj.bucket_id)
          .download(obj.name)

        if (downloadError) {
          console.error('Download error', obj.id, obj.name, downloadError)
          totalErrors++
          continue
        }

        const { error: uploadError } = await newStorageClient.storage
          .from(obj.bucket_id)
          .upload(obj.name, fileData, {
            upsert: true,
            contentType: obj.metadata?.mimetype || 'application/octet-stream',
            cacheControl: obj.metadata?.cacheControl || '3600',
          })

        if (uploadError) {
          console.error('Upload error', obj.id, obj.name, uploadError)
          totalErrors++
          continue
        }

        totalMoved++
        if (totalMoved % 50 === 0) console.log('Перенесено объектов:', totalMoved)
      } catch (err) {
        console.error('Error moving', obj.id, obj.name, err)
        totalErrors++
      }
    }

    offset += BATCH_SIZE
    if (objects.length < BATCH_SIZE) break
  }

  console.log('Готово. Перенесено:', totalMoved, 'Ошибок:', totalErrors)
}

migrate().catch((e) => {
  console.error(e)
  process.exit(1)
})
```

Для использования `.env` установите `dotenv`: `npm install dotenv`.

### 5.4 Запуск

```bash
node migrate-storage.js
```

При большом числе объектов скрипт выводит прогресс каждые 50 файлов. Если в вашем self-hosted PostgREST стоит лимит `max_rows` меньше 1000, уменьшите `BATCH_SIZE` в скрипте или увеличьте лимит в настройках PostgREST.

---

## 6. После переноса

- **Проверка:** в Studio на Pigsty (http://104.223.25.234:8000) откройте Storage и убедитесь, что бакеты заполнены и файлы открываются.
- **Политики:** при необходимости повторите RLS-политики для бакетов (как в Cloud) — через SQL или через Studio.
- **Приложения:** переключите фронт/бэкенд на URL и ключи Supabase на Pigsty, чтобы загрузка/скачивание шли в новый Storage.

---

## 7. Несколько проектов

Для каждого Cloud-проекта:

1. Восстановите дамп БД этого проекта в **свою** целевую БД на Pigsty (со схемой `storage`). Один проект Cloud = одна БД на Pigsty (см. [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](./MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md), миграция двух БД).
2. Обновите в `.env` только `OLD_PROJECT_URL` и `OLD_PROJECT_SERVICE_KEY` для этого проекта.
3. **Важно:** на Pigsty Supabase обычно привязан к одной БД (часто `postgres`). Если у вас несколько БД и один инстанс Supabase, то Storage API обслуживает одну БД. Варианты:
   - переносить Storage по очереди в ту же БД, где живёт один из проектов, и в приложениях использовать разные бакеты/префиксы по проектам;
   - либо поднимать отдельный набор контейнеров Supabase на каждую БД (сложнее).
4. Запустите `node migrate-storage.js` для проекта 1, затем смените `OLD_*` и запустите для проекта 2 и т.д.

---

## 8. Чеклист (один проект)

- [ ] Миграция БД выполнена со схемой `storage`; бакеты есть на Pigsty.
- [ ] Контейнер Storage на Pigsty в состоянии Up/healthy.
- [ ] Собрана инвентаризация (бакеты, объём, политики).
- [ ] Создан `.env` с URL и service_role ключами Cloud и Pigsty.
- [ ] Установлены `@supabase/supabase-js` и `dotenv`, скрипт `migrate-storage.js` сохранён.
- [ ] Запущен `node migrate-storage.js`, ошибки просмотрены в логе.
- [ ] Проверены объём и доступ к файлам в Studio на Pigsty.
- [ ] При необходимости заданы политики Storage на Pigsty.

---

## 9. Связанные документы

| Документ | Содержание |
|----------|------------|
| [MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md](./MIGRATION-SUPABASE-CLOUD-TO-PIGSTY.md) | Полная миграция БД Cloud → Pigsty, §8.5 Storage |
| [SUPABASE-INVENTORY-MIGRATION.md](./SUPABASE-INVENTORY-MIGRATION.md) | Инвентаризация Storage (бакеты, политики, объём) |
| [Reports/SUPABASE-CONTAINERS-FIX-2026-02.md](./Reports/SUPABASE-CONTAINERS-FIX-2026-02.md) | Исправление контейнеров rest/auth/storage на Pigsty |

Официальная справка Supabase: [Backup and Restore — Migrate storage objects](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).
