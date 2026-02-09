-- Тестовая запись для проверки забора данных фронтом из Pigsty
-- Выполнить после app_schema.sql: psql -h HOST -p 5432 -U dbuser_app -d app -f seed_news_test.sql

INSERT INTO public.news (
  slug,
  title_en,
  content_en,
  excerpt_en,
  tags,
  image,
  published,
  title_ru,
  content_ru,
  excerpt_ru
) VALUES (
  'test-from-pigsty',
  'Test article from Pigsty',
  'This is test content. Frontend should fetch this from Pigsty via your API.',
  'Test excerpt',
  ARRAY['test', 'pigsty'],
  '',
  true,
  'Тестовая запись из Pigsty',
  'Это тестовый контент. Фронт должен получать его из Pigsty через ваш API.',
  'Тестовый отрывок'
)
ON CONFLICT (slug) DO NOTHING;
