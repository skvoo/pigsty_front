-- Передать владение схемой auth и всеми таблицами/последовательностями supabase_auth_admin,
-- чтобы миграции GoTrue (COMMENT ON TABLE, create or replace function) проходили.
-- Выполнить один раз от supabase_admin в БД app.

ALTER SCHEMA auth OWNER TO supabase_auth_admin;

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'auth')
  LOOP EXECUTE format('ALTER TABLE auth.%I OWNER TO supabase_auth_admin', r.tablename); END LOOP;
  FOR r IN (SELECT sequencename FROM pg_sequences WHERE schemaname = 'auth')
  LOOP EXECUTE format('ALTER SEQUENCE auth.%I OWNER TO supabase_auth_admin', r.sequencename); END LOOP;
END $$;

-- Оставить supabase_admin права
GRANT USAGE ON SCHEMA auth TO supabase_admin;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO supabase_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO supabase_admin;
