-- Schema for frontend test: news app
-- Run as dbuser_app (or admin) on database "app"
-- Usage: psql -h 104.223.25.234 -p 5432 -U dbuser_app -d app -f app_schema.sql
-- Or via PgBouncer: -p 6432

CREATE TABLE IF NOT EXISTS public.news (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  slug text NOT NULL,
  title_en text NOT NULL,
  content_en text NOT NULL,
  excerpt_en text NOT NULL DEFAULT ''::text,
  tags text[] NOT NULL DEFAULT '{}'::text[],
  image text NOT NULL DEFAULT ''::text,
  published boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  title_ru text NULL DEFAULT ''::text,
  content_ru text NULL DEFAULT ''::text,
  excerpt_ru text NULL DEFAULT ''::text,
  CONSTRAINT news_pkey PRIMARY KEY (id),
  CONSTRAINT news_slug_key UNIQUE (slug)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS news_published_created_at_idx
  ON public.news USING btree (published, created_at DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS news_slug_published_idx
  ON public.news USING btree (slug) TABLESPACE pg_default
  WHERE (published = true);

CREATE INDEX IF NOT EXISTS news_tags_gin_idx
  ON public.news USING gin (tags) TABLESPACE pg_default;
