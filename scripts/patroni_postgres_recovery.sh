#!/bin/bash
# Diagnose and optionally recover Patroni/PostgreSQL on Pigsty server (single-node pg-meta).
# Run on server 104.223.25.234 as user with sudo (e.g. st).
#
# Usage:
#   Diagnose only:
#     ./patroni_postgres_recovery.sh
#   Diagnose and promote this node to primary (if standby):
#     ./patroni_postgres_recovery.sh --fix
#
# Copy to server: scp scripts/patroni_postgres_recovery.sh st@104.223.25.234:~/
# Then: chmod +x patroni_postgres_recovery.sh && ./patroni_postgres_recovery.sh [--fix]

set -e
PG_DATA="${PG_DATA:-/pg/data}"
PATRONI_CTL_CFG="${PATRONI_CTL_CFG:-/pg/bin/patroni.yml}"
FIX=
for a in "$@"; do
  case "$a" in
    --fix) FIX=1 ;;
  esac
done

echo "=== Patroni/PostgreSQL recovery script ==="
echo "PG_DATA=$PG_DATA"
echo ""

# 1. Patroni service
echo "--- 1. Patroni service ---"
if systemctl is-active --quiet patroni 2>/dev/null; then
  echo "patroni: active (running)"
else
  echo "patroni: $(systemctl is-active patroni 2>/dev/null || echo 'unknown')"
  if [ -n "$FIX" ]; then
    echo "Starting patroni..."
    sudo systemctl start patroni
    sleep 3
  else
    echo "Run with --fix to start patroni, or: sudo systemctl start patroni"
  fi
fi
echo ""

# 2. Cluster state (as postgres)
echo "--- 2. Patroni cluster state ---"
if [ -r "$PATRONI_CTL_CFG" ]; then
  sudo -u postgres patronictl -c "$PATRONI_CTL_CFG" list 2>/dev/null || echo "patronictl list failed (check etcd and patroni)"
else
  echo "Config not found: $PATRONI_CTL_CFG"
fi
echo ""

# 3. standby.signal
echo "--- 3. Standby signal ---"
if [ -f "$PG_DATA/standby.signal" ]; then
  echo "standby.signal is present -> instance is in standby mode."
  if [ -n "$FIX" ]; then
    echo "Removing standby.signal and restarting Patroni to promote to primary..."
    sudo systemctl stop patroni
    sleep 2
    sudo -u postgres rm -f "$PG_DATA/standby.signal"
    sudo systemctl start patroni
    echo "Waiting 5s for Patroni to start..."
    sleep 5
    sudo -u postgres patronictl -c "$PATRONI_CTL_CFG" list 2>/dev/null || true
  else
    echo "To promote this node to primary, run: $0 --fix"
  fi
else
  echo "No standby.signal -> not in standby mode."
fi
echo ""

# 4. PostgreSQL connection
echo "--- 4. PostgreSQL connection ---"
if sudo -u postgres psql -h 127.0.0.1 -p 5432 -d postgres -t -c 'SELECT 1' 2>/dev/null; then
  echo "PostgreSQL: accepting connections."
  sudo -u postgres psql -h 127.0.0.1 -p 5432 -d postgres -c 'SELECT version();' 2>/dev/null | head -3
else
  echo "PostgreSQL: not accepting connections (or still starting)."
  if [ -n "$FIX" ] && [ -f "$PG_DATA/standby.signal" ]; then
    echo "After --fix, wait a few seconds and run this script again to verify."
  fi
fi
echo ""

echo "=== Done ==="
echo "Full runbook: docs/RUNBOOK-PATRONI-POSTGRES-RECOVERY.md"
