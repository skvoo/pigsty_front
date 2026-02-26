-- Миграция: добавить role в public.users (БД td)
-- Применение: psql "postgresql://tdadmin:...@host:6432/td" -f sql/td_users_add_role.sql

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS role varchar(20) NOT NULL DEFAULT 'user';

COMMENT ON COLUMN public.users.role IS 'Роль пользователя (например user, admin). По умолчанию user.';
