-- Пример: создание пользователя в auth.users (обход кнопки "Create user" в Studio)
-- Требуется расширение pgcrypto. Выполнять от supabase_admin в БД app.
-- Использование: подставьте свой email и пароль, затем:
--   PGPASSWORD=SupaAdmin7mN2pQ4r psql -h 127.0.0.1 -p 5432 -U supabase_admin -d app -f auth_user_create_example.sql

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Если таблица auth.instances пуста — создаём одну запись:
INSERT INTO auth.instances (id) SELECT gen_random_uuid() WHERE NOT EXISTS (SELECT 1 FROM auth.instances);

INSERT INTO auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmed_at,
  is_anonymous,
  is_sso_user
) VALUES (
  gen_random_uuid(),
  (SELECT id FROM auth.instances LIMIT 1),
  'authenticated',
  'authenticated',
  'user@example.com',                    -- замените на нужный email
  crypt('YourSecurePassword', gen_salt('bf')),  -- замените на пароль
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  now(),
  now(),
  now(),
  false,
  false
);
