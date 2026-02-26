-- Миграция: добавить email и password_hash в public.users (БД td)
-- Для уже развёрнутой схемы. Применение: psql "postgresql://tdadmin:...@host:6432/td" -f sql/td_users_add_email_password.sql
-- Если в users уже есть строки без email/password_hash, сначала заполните их, затем выполните эту миграцию.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS email varchar(255) NOT NULL UNIQUE,
  ADD COLUMN IF NOT EXISTS password_hash varchar(255) NOT NULL;

COMMENT ON COLUMN public.users.email IS 'Email пользователя.';
COMMENT ON COLUMN public.users.password_hash IS 'Хэш пароля.';
