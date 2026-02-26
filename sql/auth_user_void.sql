CREATE EXTENSION IF NOT EXISTS pgcrypto;
INSERT INTO auth.instances (id) SELECT gen_random_uuid() WHERE NOT EXISTS (SELECT 1 FROM auth.instances);
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmed_at, is_anonymous, is_sso_user
) VALUES (
  gen_random_uuid(),
  (SELECT id FROM auth.instances LIMIT 1),
  'authenticated', 'authenticated', 'void@void.com',
  crypt('V0id#xK9mQ', gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  now(), now(), now(), false, false
);
