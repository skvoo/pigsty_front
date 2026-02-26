-- Миграция БД td под схему ticket-defenders-express (Prisma)
-- Применение: psql "postgresql://tdadmin:...@host:6432/td" -f sql/td_migrate_to_prisma.sql
-- Требуется: уже применён sql/td_schema.sql (users, tickets с file_url).

-- 1) users: добавить full_name, phone
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS full_name varchar(200) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS phone varchar(25) NULL;

-- 2) Таблица ticket_files (несколько файлов на тикет)
CREATE TABLE IF NOT EXISTS public.ticket_files (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  file_url varchar(2048) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ticket_files_ticket_id_idx ON public.ticket_files (ticket_id);

-- 3) Перенести существующие file_url из tickets в ticket_files (один тикет → одна строка)
INSERT INTO public.ticket_files (ticket_id, file_url, created_at)
SELECT id, file_url, created_at
FROM public.tickets
WHERE file_url IS NOT NULL AND file_url != ''
  AND NOT EXISTS (
    SELECT 1 FROM public.ticket_files tf WHERE tf.ticket_id = tickets.id
  );

-- 4) tickets: добавить status, json_data, updated_at
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS status varchar(50) NOT NULL DEFAULT 'new',
  ADD COLUMN IF NOT EXISTS json_data json NULL,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- 5) Удалить file_url из tickets (данные уже в ticket_files)
ALTER TABLE public.tickets DROP COLUMN IF EXISTS file_url;

-- Комментарии для ясности
COMMENT ON TABLE public.ticket_files IS 'Файлы тикетов (ticket-defenders-express / Prisma)';
COMMENT ON COLUMN public.tickets.status IS 'Статус тикета (new и др.)';
COMMENT ON COLUMN public.tickets.json_data IS 'Доп. данные тикета (JSON)';
