-- Round 3: Auth OAuth migration 20250804100000 needs code_challenge_method and oauth_clients
-- Run: sudo -u postgres psql -d app -f supabase_fix_auth_oauth_round3.sql

CREATE TYPE auth.code_challenge_method AS ENUM ('s256', 'plain');

CREATE TABLE IF NOT EXISTS auth.oauth_clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id text UNIQUE NOT NULL,
  client_secret text,
  name text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

GRANT ALL ON auth.oauth_clients TO supabase_admin;
