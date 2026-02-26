# Перенос Supabase Cloud Storage в MinIO (Pigsty)

Пошаговый перенос файлов из Supabase Cloud Storage в **MinIO** на сервере Pigsty для проектов GD-lounge и imperial. Один запуск скрипта переносит **один** бакет источника в **один** бакет MinIO.

Связано: [STORAGE-MIGRATION-SUPABASE-TO-PIGSTY.md](./STORAGE-MIGRATION-SUPABASE-TO-PIGSTY.md) (перенос в Supabase Storage на Pigsty); [TEST-MIGRATION-INVENTORY.md](./TEST-MIGRATION-INVENTORY.md) (список бакетов).

---

## 1. Подготовка MinIO на Pigsty

В [pigsty.yml](../pigsty.yml) уже добавлены бакеты и пользователи:

| Бакет MinIO | Проект | Пользователь S3 (access_key) |
|-------------|--------|------------------------------|
| gd-lounge-assets | GD-lounge | s3user_gdlounge |
| imperial-event-images | imperial | s3user_imperial_ev |
| imperial-furniture-images | imperial | s3user_imperial_fu |
| imperial-news-images | imperial | s3user_imperial_nw |
| imperial-product-images | imperial | s3user_imperial_pr |
| imperial-site-images | imperial | s3user_imperial_si |

Применить на сервере: `./minio.yml -l minio`. Пароли пользователей — в `pigsty.yml` (secret_key); хранить в секретах, не коммитить.

Публичное чтение для бакетов (чтобы по URL открывать файлы): в консоли MinIO (порт 9001) или через `mc anonymous set download myminio/<bucket>`.

---

## 2. Соответствие бакетов (источник → MinIO)

### GD-lounge

| Supabase Cloud | MinIO |
|----------------|--------|
| assets | gd-lounge-assets |

### imperial

| Supabase Cloud | MinIO |
|----------------|--------|
| event-images | imperial-event-images |
| furniture-images | imperial-furniture-images |
| news-images | imperial-news-images |
| product-images | imperial-product-images |
| site-images | imperial-site-images |

---

## 3. Скрипт миграции

Расположение: `scripts/storage-migration-minio/`.

### 3.1 Установка

```bash
cd scripts/storage-migration-minio
npm install
```

### 3.2 Переменные окружения

**Вариант А — один скрипт для всех 6 бакетов:** добавьте в корневой файл **supabase-credentials.env** (рядом с REF и паролями):

- **SUPABASE_GDLOUNGE_SERVICE_KEY** — service_role ключ проекта GD-lounge (Dashboard → Project Settings → API → service_role).
- **SUPABASE_IMPERIAL_SERVICE_KEY** — service_role ключ проекта imperial.

Затем из корня репо: `.\scripts\run_storage_migration.ps1`. Скрипт сам подставит URL из REF и по очереди перенесёт все бакеты.

**Вариант Б — вручную по одному бакету:** в `scripts/storage-migration-minio/` создайте `.env` по образцу `.env.example`:

- **OLD_PROJECT_URL**, **OLD_PROJECT_SERVICE_KEY** — Supabase Cloud (Dashboard → Project Settings → API, service_role).
- **MINIO_ENDPOINT** — `http://104.223.25.234:9000`.
- **MINIO_ACCESS_KEY**, **MINIO_SECRET_KEY** — пользователь MinIO (см. таблицу в §1).
- **SOURCE_BUCKET**, **TARGET_BUCKET** — одна пара бакетов за запуск.

### 3.3 Запуск (один бакет за раз)

**GD-lounge (бакет assets):**

```bash
SOURCE_BUCKET=assets TARGET_BUCKET=gd-lounge-assets \
MINIO_ACCESS_KEY=s3user_gdlounge MINIO_SECRET_KEY=GdLoungeStorage7xKp2mNqR \
OLD_PROJECT_URL=https://<GDLOUNGE_REF>.supabase.co OLD_PROJECT_SERVICE_KEY=<service_role> \
MINIO_ENDPOINT=http://104.223.25.234:9000 \
node migrate_storage_to_minio.js
```

**imperial (по одному бакету):**

Повторить 5 раз, подставляя SOURCE_BUCKET, TARGET_BUCKET и соответствующего пользователя MinIO (s3user_imperial_ev, s3user_imperial_fu, …). Пароль для всех imperial-пользователей в конфиге один (ImperialStorage7xKp2mNqR) — при необходимости сменить в pigsty.yml и переприменить.

Пример для product-images:

```bash
SOURCE_BUCKET=product-images TARGET_BUCKET=imperial-product-images \
MINIO_ACCESS_KEY=s3user_imperial_pr MINIO_SECRET_KEY=ImperialStorage7xKp2mNqR \
OLD_PROJECT_URL=https://<IMPERIAL_REF>.supabase.co OLD_PROJECT_SERVICE_KEY=<service_role> \
MINIO_ENDPOINT=http://104.223.25.234:9000 \
node migrate_storage_to_minio.js
```

### 3.4 После переноса

- Проверить объём и список объектов в консоли MinIO (http://104.223.25.234:9001).
- Включить публичное чтение на бакетах, если фронт будет строить URL вида `http://104.223.25.234:9000/<bucket>/<key>`.
- Обновить фронт/бэкенд: загрузка через ваш API в MinIO, отображение по новым URL (см. [FRONTEND-AFTER-SUPABASE-CLOUD.md](./FRONTEND-AFTER-SUPABASE-CLOUD.md)).

---

## 4. Связанные документы

- [TEST-MIGRATION-INVENTORY.md](./TEST-MIGRATION-INVENTORY.md) — инвентаризация бакетов и объёмов.
- [TD-MINIO-DEPLOY-AND-FRONTEND.md](./TD-MINIO-DEPLOY-AND-FRONTEND.md) — паттерн API загрузки в MinIO для фронта.
- [FRONTEND-AFTER-SUPABASE-CLOUD.md](./FRONTEND-AFTER-SUPABASE-CLOUD.md) — что изменить во фронте после миграции.
