-- Пометить миграции как выполненные, чтобы GoTrue не падал на несовместимых скриптах (uuid vs text в наших таблицах)
INSERT INTO auth.schema_migrations (version) VALUES ('00_init_auth_schema') ON CONFLICT DO NOTHING;
INSERT INTO auth.schema_migrations (version) VALUES ('20221208132122_backfill_email_last_sign_in_at') ON CONFLICT DO NOTHING;
