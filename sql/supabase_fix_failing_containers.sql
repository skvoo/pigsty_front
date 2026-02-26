-- Fix for failing Supabase containers (PostgREST, Storage, Realtime, GoTrue)
-- Run on database app as superuser: psql -h 127.0.0.1 -p 5432 -U postgres -d app -f supabase_fix_failing_containers.sql
-- Password for new users must match POSTGRES_PASSWORD in Supabase env (e.g. SupaAdmin7mN2pQ4r)

-- ========== 1. PostgREST: authenticator + anon, authenticated, service_role ==========
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator WITH LOGIN PASSWORD 'SupaAdmin7mN2pQ4r';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
END $$;

GRANT anon, authenticated, service_role TO authenticator;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;

-- ========== 2. Storage: supabase_storage_admin ==========
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_storage_admin') THEN
    CREATE ROLE supabase_storage_admin WITH LOGIN PASSWORD 'SupaAdmin7mN2pQ4r';
  END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS storage;
GRANT USAGE ON SCHEMA storage TO supabase_storage_admin;
GRANT ALL ON SCHEMA storage TO supabase_storage_admin;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO supabase_storage_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO supabase_storage_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL ON TABLES TO supabase_storage_admin;

-- Storage schema also for anon/authenticated/service_role (API access)
GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;

CREATE SCHEMA IF NOT EXISTS graphql_public;
GRANT USAGE ON SCHEMA graphql_public TO anon, authenticated, service_role;

-- ========== 3. Realtime: schema _realtime ==========
CREATE SCHEMA IF NOT EXISTS _realtime;
GRANT ALL ON SCHEMA _realtime TO supabase_admin;
GRANT ALL ON SCHEMA _realtime TO authenticator;
ALTER USER supabase_admin SET search_path TO _realtime, public;

-- ========== 4. GoTrue: fix migration 20221208132122 (uuid = text) ==========
-- Original migration fails: id = user_id::text → operator does not exist: uuid = text
-- Run the intended update with correct cast, then mark migration as done
DO $$
BEGIN
  UPDATE auth.identities
  SET last_sign_in_at = '2022-11-25'
  WHERE last_sign_in_at IS NULL
    AND created_at = '2022-11-25'
    AND updated_at = '2022-11-25'
    AND provider = 'email'
    AND id::text = user_id::text;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Backfill skipped or already applied: %', SQLERRM;
END $$;

INSERT INTO auth.schema_migrations (version) VALUES ('20221208132122') ON CONFLICT (version) DO NOTHING;

-- GoTrue may also use public.schema_migrations (golang-migrate)
CREATE TABLE IF NOT EXISTS public.schema_migrations (version bigint PRIMARY KEY);
INSERT INTO public.schema_migrations (version) VALUES (20221208132122) ON CONFLICT (version) DO NOTHING;

-- ========== 5. HBA: allow Docker/containers to connect (if not already) ==========
-- Pigsty pg_hba already has 172.17.0.0/16; no change here.
