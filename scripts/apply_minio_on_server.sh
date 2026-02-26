#!/usr/bin/env bash
# Run ON the server (e.g. after SSH). Creates MinIO buckets and users from pigsty.yml.
# Usage: copy to server and run, or: ssh st@104.223.25.234 'bash -s' < scripts/apply_minio_on_server.sh

set -e
PIGSTY_DIR="${PIGSTY_DIR:-$HOME/pigsty}"
if [[ ! -f "$PIGSTY_DIR/pigsty.yml" ]]; then
  echo "Error: $PIGSTY_DIR/pigsty.yml not found. Set PIGSTY_DIR or run from ~/pigsty." >&2
  exit 1
fi
cd "$PIGSTY_DIR"
./minio.yml -l minio
