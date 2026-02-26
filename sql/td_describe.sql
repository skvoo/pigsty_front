\echo '=== COLUMNS ==='
SELECT c.table_name, c.column_name, c.data_type, c.character_maximum_length, c.column_default, c.is_nullable
FROM information_schema.columns c
WHERE c.table_schema = 'public' AND c.table_name IN ('users', 'tickets')
ORDER BY c.table_name, c.ordinal_position;

\echo '=== FOREIGN KEYS ==='
SELECT tc.table_name, kcu.column_name, ccu.table_name AS ref_table, ccu.column_name AS ref_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public';

\echo '=== INDEXES ==='
SELECT tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = 'public' AND tablename IN ('users', 'tickets') ORDER BY tablename;
