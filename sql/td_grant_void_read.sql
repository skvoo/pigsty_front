-- Выдать пользователю void права на чтение в БД td
-- Владелец таблиц (tdadmin) может выдавать права. Применение: от tdadmin к БД td.

GRANT USAGE ON SCHEMA public TO void;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO void;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO void;
