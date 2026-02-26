-- =============================================================================
-- Инвентаризация проекта Supabase Cloud для миграции на Pigsty
-- Запуск: psql "$SOURCE_DB_URL" -f sql/supabase_inventory.sql
-- Результат можно сохранить и передать для анализа (без паролей).
-- Примечание: блоки 9–10 (Storage) и 14 (Auth) требуют схем storage/auth;
-- если их нет, соответствующие запросы выдадут ошибку — пропустите или игнорируйте.
-- =============================================================================

\echo '=== 1. Версия PostgreSQL ==='
SELECT version();

\echo ''
\echo '=== 2. Размер БД ==='
SELECT pg_size_pretty(pg_database_size(current_database())) AS db_size;

\echo ''
\echo '=== 3. Расширения (extensions) ==='
SELECT extname, extversion
FROM pg_extension
WHERE extname != 'plpgsql'
ORDER BY extname;

\echo ''
\echo '=== 4. Схемы и размер по схемам ==='
SELECT n.nspname AS schema_name,
       pg_size_pretty(sum(pg_total_relation_size(c.oid))) AS size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT LIKE 'pg_%'
  AND c.relkind IN ('r', 'm')
GROUP BY n.nspname
ORDER BY sum(pg_total_relation_size(c.oid)) DESC NULLS LAST;

\echo ''
\echo '=== 5. Таблицы (public, auth, storage, realtime) ==='
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname IN ('public', 'auth', 'storage', 'realtime', 'extensions', 'graphql_public')
ORDER BY schemaname, pg_total_relation_size(schemaname||'.'||tablename) DESC NULLS LAST;

\echo ''
\echo '=== 6. Роли (не системные) ==='
SELECT rolname, rolsuper, rolcanlogin, rolcreatedb, rolcreaterole
FROM pg_roles
WHERE rolname NOT LIKE 'pg_%'
ORDER BY rolname;

\echo ''
\echo '=== 7. Таблицы с RLS ==='
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE rowsecurity = true
ORDER BY schemaname, tablename;

\echo ''
\echo '=== 8. Политики RLS (кратко) ==='
SELECT schemaname, tablename, policyname, permissive, roles::text, cmd
FROM pg_policies
ORDER BY schemaname, tablename, policyname;

\echo ''
\echo '=== 9. Storage: buckets (пропуск, если схемы storage нет) ==='
SELECT id, name, public, file_size_limit, allowed_mime_types, created_at
FROM storage.buckets
ORDER BY name;

\echo ''
\echo '=== 10. Storage: количество объектов по bucket ==='
SELECT bucket_id, count(*) AS objects, pg_size_pretty(sum((metadata->>'size')::bigint)) AS approx_size
FROM storage.objects
GROUP BY bucket_id
ORDER BY count(*) DESC;

\echo ''
\echo '=== 11. Realtime: публикации (если есть) ==='
SELECT pubname, puballtables, pubinsert, pubupdate, pubdelete
FROM pg_publication
WHERE pubname NOT LIKE 'pg_%'
ORDER BY pubname;

\echo ''
\echo '=== 12. Функции в public (кастомные) ==='
SELECT n.nspname, p.proname, pg_get_function_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname NOT LIKE 'pg_%'
ORDER BY p.proname;

\echo ''
\echo '=== 13. Триггеры в public ==='
SELECT tgname, relname AS table_name, proname AS function_name
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_proc p ON p.oid = t.tgfoid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND NOT t.tgisinternal
ORDER BY relname, tgname;

\echo ''
\echo '=== 14. Auth: количество пользователей (если есть схема auth) ==='
SELECT count(*) AS auth_users_count FROM auth.users;

\echo ''
\echo '=== Конец инвентаризации ==='
