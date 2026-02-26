-- Add missing columns to auth.users for Supabase Studio / GoTrue compatibility
-- Run on DB where Studio is connected (e.g. app): psql -h 127.0.0.1 -p 5432 -U supabase_admin -d app -f supabase_auth_schema_patch.sql

-- banned_until: used by Studio Auth UI
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS banned_until timestamptz NULL;
-- is_anonymous: Studio / GoTrue expect it (anonymous sign-in)
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS is_anonymous bool NULL DEFAULT false;
-- is_sso_user: Studio Auth UI
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS is_sso_user bool NULL DEFAULT false;

-- phone auth
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS phone varchar(255) NULL;
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS phone_confirmed_at timestamptz NULL;

-- email confirmation (alias / alternate name)
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS email_confirmed_at timestamptz NULL;

-- SSO
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS is_sso_confirmed bool NULL DEFAULT false;

-- reauthentication
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS reauthentication_token varchar(255) NULL;
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS reauthentication_sent_at timestamptz NULL;

-- audit
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;

-- identities table (Studio may expect it)
CREATE TABLE IF NOT EXISTS auth.identities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NULL,
  identity_data jsonb NULL,
  provider varchar(255) NULL,
  provider_id varchar(255) NULL,
  last_sign_in_at timestamptz NULL,
  created_at timestamptz NULL DEFAULT now(),
  updated_at timestamptz NULL DEFAULT now(),
  CONSTRAINT identities_pkey PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS identities_user_id_idx ON auth.identities (user_id);
CREATE INDEX IF NOT EXISTS identities_provider_id_idx ON auth.identities (provider, provider_id);
GRANT ALL ON auth.identities TO supabase_admin;

-- audit_log_entries (often expected by Studio)
CREATE TABLE IF NOT EXISTS auth.audit_log_entries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  instance_id uuid NULL,
  payload jsonb NULL,
  created_at timestamptz NULL DEFAULT now(),
  CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id)
);
GRANT ALL ON auth.audit_log_entries TO supabase_admin;
