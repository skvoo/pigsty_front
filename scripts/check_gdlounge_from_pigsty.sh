#!/bin/bash
# Проверка подключения к БД GD-lounge (Supabase) С СЕРВЕРА Pigsty.
# Копировать на сервер и запускать там: scp scripts/check_gdlounge_from_pigsty.sh st@104.223.25.234:~/
# На сервере: chmod +x check_gdlounge_from_pigsty.sh && export SUPABASE_GDLOUNGE_REF=czhonxtlovawwjfbxgbx SUPABASE_GDLOUNGE_PASSWORD='...' && ./check_gdlounge_from_pigsty.sh
# Для IPv4 с сервера задайте Session pooler: SUPABASE_GDLOUNGE_POOLER_HOST=aws-0-REGION.pooler.supabase.com (взять в Dashboard → Connect).

REF="${SUPABASE_GDLOUNGE_REF:-czhonxtlovawwjfbxgbx}"
HOST="${SUPABASE_GDLOUNGE_POOLER_HOST:-db.$REF.supabase.co}"
export PGPASSWORD="${SUPABASE_GDLOUNGE_PASSWORD}"

echo "Подключение к $HOST:5432 (GD-lounge)..."
psql -h "$HOST" -p 5432 -U "postgres.$REF" -d postgres -c "SELECT 1 AS test, current_database(), version();"
echo "Exit code: $?"
