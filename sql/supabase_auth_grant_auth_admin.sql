-- Права для GoTrue (контейнер auth): пользователь supabase_auth_admin должен иметь доступ к схеме auth.
-- Выполнить один раз в БД app после создания пользователя (pgsql_user): от supabase_admin.
-- psql -h 127.0.0.1 -p 5432 -U supabase_admin -d app -f supabase_auth_grant_auth_admin.sql

GRANT USAGE ON SCHEMA auth TO supabase_auth_admin;
GRANT CREATE ON SCHEMA auth TO supabase_auth_admin;  -- миграции GoTrue создают таблицы/функции
GRANT ALL ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA auth TO supabase_auth_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON TABLES TO supabase_auth_admin;
