#!/bin/bash
# Скачать данные из Supabase Cloud на сервер Pigsty и восстановить в gdloungedb и imperialdb.
# Запуск на сервере: нужен файл с учётными данными (см. ниже).
#
# Подготовка:
#   1. Скопировать supabase-credentials.env на сервер (в домашний каталог или в ~/pigsty):
#      scp supabase-credentials.env st@104.223.25.234:~/
#   2. Если пароль содержит $, в файле на сервере задать значение в одинарных кавычках:
#      SUPABASE_GDLOUNGE_PASSWORD='$sharkMan2026$'
#   3. Для imperial при необходимости добавить SUPABASE_IMPERIAL_POOLER_HOST (если нет — используется тот же хост, что для GD).
#
# Запуск на сервере:
#   cd ~
#   chmod +x pull_supabase_to_server.sh
#   ./pull_supabase_to_server.sh
#
# Либо из репо (локально): scp scripts/pull_supabase_to_server.sh st@104.223.25.234:~/ && ssh st@104.223.25.234 'bash ~/pull_supabase_to_server.sh'

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd)"
CRED_FILE="${1:-$HOME/supabase-credentials.env}"
if [ ! -f "$CRED_FILE" ] && [ -n "$SCRIPT_DIR" ]; then
  CRED_FILE="$SCRIPT_DIR/../supabase-credentials.env"
fi
if [ ! -f "$CRED_FILE" ]; then
  echo "Файл с учётными данными не найден. Укажите путь: $0 /path/to/supabase-credentials.env"
  exit 1
fi

echo "Загрузка переменных из $CRED_FILE"
set -a
# shellcheck source=/dev/null
source "$CRED_FILE" 2>/dev/null || true
set +a

REF_GD="${SUPABASE_GDLOUNGE_REF:?SUPABASE_GDLOUNGE_REF не задан}"
PWD_GD="${SUPABASE_GDLOUNGE_PASSWORD:?SUPABASE_GDLOUNGE_PASSWORD не задан}"
POOLER_GD="${SUPABASE_GDLOUNGE_POOLER_HOST:-aws-1-ap-south-1.pooler.supabase.com}"

REF_IMP="${SUPABASE_IMPERIAL_REF:?SUPABASE_IMPERIAL_REF не задан}"
PWD_IMP="${SUPABASE_IMPERIAL_PASSWORD:?SUPABASE_IMPERIAL_PASSWORD не задан}"
POOLER_IMP="${SUPABASE_IMPERIAL_POOLER_HOST:-$POOLER_GD}"

PIGSTY_PWD="${PIGSTY_POSTGRES_PASSWORD:?PIGSTY_POSTGRES_PASSWORD не задан}"

WORKDIR="${MIGRATION_WORKDIR:-$HOME/migration_supabase}"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

PGDUMP="${PGDUMP:-/usr/pgsql/bin/pg_dump}"
PGRESTORE="${PGRESTORE:-/usr/pgsql/bin/pg_restore}"
PSQL="${PSQL:-/usr/pgsql/bin/psql}"

echo "=== 1. Экспорт GD-lounge из Supabase (pooler: $POOLER_GD) ==="
export PGPASSWORD="$PWD_GD"
"$PGDUMP" "postgresql://postgres.${REF_GD}@${POOLER_GD}:5432/postgres" \
  --no-owner --no-privileges \
  --exclude-schema=graphql_public --exclude-schema=extensions \
  --format custom --file backup_gdlounge.dump
unset PGPASSWORD
echo "GD-lounge dump: $(ls -la backup_gdlounge.dump)"

echo "=== 2. Экспорт imperial из Supabase (pooler: $POOLER_IMP) ==="
export PGPASSWORD="$PWD_IMP"
if ! "$PGDUMP" "postgresql://postgres.${REF_IMP}@${POOLER_IMP}:5432/postgres" \
  --no-owner --no-privileges \
  --exclude-schema=graphql_public --exclude-schema=extensions \
  --format custom --file backup_imperial.dump 2>&1; then
  echo "Внимание: дамп imperial не удался (возможно, другой Session pooler для проекта — задайте SUPABASE_IMPERIAL_POOLER_HOST в env)."
  : > backup_imperial.dump
fi
unset PGPASSWORD
echo "imperial dump: $(ls -la backup_imperial.dump)"

echo "=== 3. Восстановление в gdloungedb (через socket, от пользователя postgres) ==="
cp backup_gdlounge.dump /tmp/ 2>/dev/null || true
chmod 644 /tmp/backup_gdlounge.dump 2>/dev/null || true
sudo -u postgres "$PGRESTORE" -d gdloungedb --no-owner --no-privileges /tmp/backup_gdlounge.dump 2>/dev/null || true
echo "=== 4. Восстановление в imperialdb ==="
if [ -s backup_imperial.dump ]; then
  cp backup_imperial.dump /tmp/
  chmod 644 /tmp/backup_imperial.dump
  sudo -u postgres "$PGRESTORE" -d imperialdb --no-owner --no-privileges /tmp/backup_imperial.dump 2>/dev/null || true
else
  echo "backup_imperial.dump пустой или отсутствует (задайте SUPABASE_IMPERIAL_POOLER_HOST для своего региона из Dashboard)."
fi

echo "=== Готово. Проверка количества таблиц ==="
sudo -u postgres "$PSQL" -d gdloungedb -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" | xargs echo "gdloungedb public tables:"
sudo -u postgres "$PSQL" -d imperialdb -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" | xargs echo "imperialdb public tables:" 2>/dev/null || true
echo "Дампы сохранены в $WORKDIR (backup_gdlounge.dump, backup_imperial.dump)."
