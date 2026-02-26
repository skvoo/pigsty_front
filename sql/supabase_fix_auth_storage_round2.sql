-- Round 2: Storage permissions, Auth MFA objects for GoTrue migrations
-- Run: sudo -u postgres psql -d app -f supabase_fix_auth_storage_round2.sql

-- Storage: allow supabase_storage_admin to run migrations (create tables in storage)
GRANT CONNECT ON DATABASE app TO supabase_storage_admin;
GRANT CREATE ON DATABASE app TO supabase_storage_admin;
ALTER SCHEMA storage OWNER TO supabase_storage_admin;

-- Auth: create objects required by migration 20240729123726_add_mfa_phone_config
-- Type factor_type with all values so migration can add column phone (migration adds 'phone' to enum)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factor_type' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
    CREATE TYPE auth.factor_type AS ENUM ('totp', 'webauthn', 'phone');
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'factor_type: %', SQLERRM;
END $$;

-- Tables mfa_factors and mfa_challenges (minimal structure so migration can add columns)
CREATE TABLE IF NOT EXISTS auth.mfa_factors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  friendly_name text,
  factor_type auth.factor_type,
  status text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS auth.mfa_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  factor_id uuid NOT NULL REFERENCES auth.mfa_factors(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  verified_at timestamptz,
  ip_address inet
);

GRANT ALL ON auth.mfa_factors TO supabase_admin;
GRANT ALL ON auth.mfa_challenges TO supabase_admin;

-- Mark migration 20240729123726 as done so GoTrue skips it
INSERT INTO auth.schema_migrations (version) VALUES ('20240729123726') ON CONFLICT (version) DO NOTHING;
INSERT INTO public.schema_migrations (version) VALUES (20240729123726) ON CONFLICT (version) DO NOTHING;
