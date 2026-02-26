-- Схема MVP Ticket Defender (TD)
-- Спецификация: https://docs.google.com/spreadsheets/d/1ufNkVvwihvz6xErw5D2cXae_-GSuseT31rz5sQJpiOs/edit?gid=1546643986
-- Применение: psql "postgresql://tdadmin:...@host:6432/td" -f sql/td_schema.sql

-- Пользователи (минимальная таблица для FK из tickets; приложение может синхронизировать из Supabase Auth)
CREATE TABLE IF NOT EXISTS public.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email varchar(255) NOT NULL UNIQUE,
  password_hash varchar(255) NOT NULL,
  role varchar(20) NOT NULL DEFAULT 'user' CONSTRAINT users_role_check CHECK (role IN ('user', 'admin')),
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.users IS 'Пользователи TD; id может соответствовать auth.users(id) при интеграции с Supabase';
COMMENT ON COLUMN public.users.email IS 'Email пользователя.';
COMMENT ON COLUMN public.users.password_hash IS 'Хэш пароля.';
COMMENT ON COLUMN public.users.role IS 'Роль пользователя (например user, admin). По умолчанию user.';

-- Тикеты
CREATE TABLE IF NOT EXISTS public.tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  file_url varchar(1024) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.tickets IS 'Тикеты MVP Ticket Defender';
COMMENT ON COLUMN public.tickets.id IS 'Уникальный идентификатор тикета. Генерируется автоматически.';
COMMENT ON COLUMN public.tickets.user_id IS 'Ссылка на пользователя, который загрузил тикет. Связь с таблицей users.';
COMMENT ON COLUMN public.tickets.file_url IS 'URL файла в облачном хранилище (Supabase Storage).';
COMMENT ON COLUMN public.tickets.created_at IS 'Дата и время создания тикета.';

-- Индексы для типичных запросов
CREATE INDEX IF NOT EXISTS tickets_user_id_idx ON public.tickets (user_id);
CREATE INDEX IF NOT EXISTS tickets_created_at_idx ON public.tickets (created_at DESC);

-- Права для tdadmin (уже владелец БД, при необходимости раскомментировать)
-- GRANT ALL ON public.users TO tdadmin;
-- GRANT ALL ON public.tickets TO tdadmin;
