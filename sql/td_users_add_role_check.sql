-- Миграция: добавить CHECK на role (только допустимые значения). БД td.
-- По рекомендации PostgreSQL docs: именованный CHECK улучшает сообщения об ошибках.
-- Применение: psql "postgresql://tdadmin:...@host:6432/td" -f sql/td_users_add_role_check.sql

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_role_check,
  ADD CONSTRAINT users_role_check CHECK (role IN ('user', 'admin'));
