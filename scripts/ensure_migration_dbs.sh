#!/bin/bash
# Create gdloungedb and imperialdb on Pigsty if missing.
# On server run: sudo -u postgres bash -s < ensure_migration_dbs.sh
# Or copy and: ssh st@104.223.25.234 'sudo -u postgres bash -s' < scripts/ensure_migration_dbs.sh

set -e
for db in gdloungedb imperialdb; do
  exists=$(psql -h 127.0.0.1 -p 5432 -d postgres -t -A -c "SELECT 1 FROM pg_database WHERE datname = '$db' LIMIT 1;" 2>/dev/null || true)
  if [ -z "$exists" ]; then
    echo "Creating database $db..."
    psql -h 127.0.0.1 -p 5432 -d postgres -c "CREATE DATABASE \"$db\";"
  else
    echo "Database $db already exists."
  fi
done
echo "Done."
