-- Minimal Supabase auth schema for Studio (auth.users must exist)
-- Run as supabase_admin on database postgres: psql -h 127.0.0.1 -p 5432 -U supabase_admin -d postgres -f supabase_auth_schema_minimal.sql

CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
  instance_id uuid NULL,
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  aud varchar(255) NULL,
  role varchar(255) NULL,
  email varchar(255) NULL,
  encrypted_password varchar(255) NULL,
  confirmed_at timestamptz NULL,
  invited_at timestamptz NULL,
  confirmation_token varchar(255) NULL,
  confirmation_sent_at timestamptz NULL,
  recovery_token varchar(255) NULL,
  recovery_sent_at timestamptz NULL,
  email_change_token_new varchar(255) NULL,
  email_change varchar(255) NULL,
  email_change_sent_at timestamptz NULL,
  last_sign_in_at timestamptz NULL,
  raw_app_meta_data jsonb NULL,
  raw_user_meta_data jsonb NULL,
  is_super_admin bool NULL DEFAULT false,
  created_at timestamptz NULL DEFAULT now(),
  updated_at timestamptz NULL DEFAULT now(),
  banned_until timestamptz NULL,
  phone varchar(255) NULL,
  phone_confirmed_at timestamptz NULL,
  email_confirmed_at timestamptz NULL,
  is_sso_confirmed bool NULL DEFAULT false,
  reauthentication_token varchar(255) NULL,
  reauthentication_sent_at timestamptz NULL,
  deleted_at timestamptz NULL,
  is_anonymous bool NULL DEFAULT false,
  is_sso_user bool NULL DEFAULT false,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS users_instance_id_email_idx ON auth.users (instance_id, email);
CREATE INDEX IF NOT EXISTS users_instance_id_idx ON auth.users (instance_id);

CREATE TABLE IF NOT EXISTS auth.schema_migrations (
  version varchar(255) NOT NULL PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS auth.refresh_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  instance_id uuid NULL,
  token varchar(255) NULL,
  user_id uuid NULL,
  revoked bool NULL DEFAULT false,
  created_at timestamptz NULL DEFAULT now(),
  updated_at timestamptz NULL DEFAULT now(),
  CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS auth.instances (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NULL DEFAULT now(),
  updated_at timestamptz NULL DEFAULT now()
);

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

CREATE TABLE IF NOT EXISTS auth.audit_log_entries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  instance_id uuid NULL,
  payload jsonb NULL,
  created_at timestamptz NULL DEFAULT now(),
  CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id)
);

-- Allow supabase_admin to use auth schema
GRANT USAGE ON SCHEMA auth TO supabase_admin;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO supabase_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO supabase_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON TABLES TO supabase_admin;
