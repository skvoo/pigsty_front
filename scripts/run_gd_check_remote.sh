#!/bin/bash
# Читает /tmp/.gd_check_env (должен быть скопирован отдельно). Пароль читается через grep/cut, чтобы $ в пароле не интерпретировался.
set -e
sed -i 's/\r$//' /tmp/.gd_check_env 2>/dev/null || true
REF=$(grep '^SUPABASE_GDLOUNGE_REF=' /tmp/.gd_check_env | head -1 | cut -d= -f2- | tr -d '\r')
HOST=$(grep '^SUPABASE_GDLOUNGE_POOLER_HOST=' /tmp/.gd_check_env | head -1 | cut -d= -f2- | tr -d '\r')
export PGPASSWORD=$(grep '^SUPABASE_GDLOUNGE_PASSWORD=' /tmp/.gd_check_env | head -1 | cut -d= -f2- | tr -d '\r')
psql -h "$HOST" -p 5432 -U "postgres.$REF" -d postgres -c "SELECT 1 AS ok, current_database();"
rm -f /tmp/.gd_check_env
