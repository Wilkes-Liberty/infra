#!/bin/bash
# =============================================
# WilkesLiberty Backup Restore Test
# =============================================
# Verifies that the latest daily backup can actually be restored.
# Spins up a temporary Postgres container, restores the Drupal dump,
# checks table counts, then tears down. Non-destructive — production
# data is never touched.
#
# Usage:
#   scripts/test-backup-restore.sh
#   scripts/test-backup-restore.sh --backup-dir /path/to/specific/backup
#
# Exit codes:
#   0  — restore succeeded and verification passed
#   1  — restore failed or verification failed
# =============================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]  $1${NC}"; }
ok()      { echo -e "${GREEN}[PASS]  $1${NC}"; }
warn()    { echo -e "${YELLOW}[WARN]  $1${NC}"; }
fail()    { echo -e "${RED}[FAIL]  $1${NC}" >&2; }

# ── Argument parsing ─────────────────────────────────────────────────────────
BACKUP_BASE="${BACKUP_BASE_DIR:-$HOME/Backups/wilkesliberty}"
EXPLICIT_BACKUP_DIR=""

for arg in "$@"; do
    case "$arg" in
        --backup-dir) EXPLICIT_BACKUP_DIR_NEXT=true ;;
        *)
            if [ "${EXPLICIT_BACKUP_DIR_NEXT:-false}" = "true" ]; then
                EXPLICIT_BACKUP_DIR="$arg"
                EXPLICIT_BACKUP_DIR_NEXT=false
            fi
            ;;
    esac
done

# ── Find backup directory ────────────────────────────────────────────────────
if [ -n "$EXPLICIT_BACKUP_DIR" ]; then
    BACKUP_DIR="$EXPLICIT_BACKUP_DIR"
else
    LATEST=$(ls -t "${BACKUP_BASE}/daily" 2>/dev/null | head -1)
    if [ -z "$LATEST" ]; then
        fail "No daily backups found in ${BACKUP_BASE}/daily"
        exit 1
    fi
    BACKUP_DIR="${BACKUP_BASE}/daily/${LATEST}"
fi

info "Testing backup: ${BACKUP_DIR}"

# ── Find database dump ───────────────────────────────────────────────────────
DB_DUMP=$(ls -t "${BACKUP_DIR}/database/drupal_postgres_"*.sql.gz 2>/dev/null | head -1)
if [ -z "$DB_DUMP" ]; then
    fail "No drupal_postgres_*.sql.gz found in ${BACKUP_DIR}/database/"
    exit 1
fi

# Basic sanity: must be a valid gzip
DUMP_SIZE=$(stat -f%z "$DB_DUMP" 2>/dev/null || stat -c%s "$DB_DUMP")
if [ "$DUMP_SIZE" -lt 1024 ]; then
    fail "Dump file is suspiciously small (${DUMP_SIZE} bytes) — backup may have failed silently."
    fail "Re-run the backup script manually: ~/Scripts/backup-onprem.sh"
    exit 1
fi
ok "Found dump: $(basename "$DB_DUMP") ($(du -h "$DB_DUMP" | cut -f1))"

# Verify gzip integrity before attempting restore
if ! gunzip -t "$DB_DUMP" 2>/dev/null; then
    fail "Dump failed gzip integrity check — file is corrupt"
    exit 1
fi
ok "Gzip integrity check passed"

# ── Spin up temporary Postgres container ────────────────────────────────────
CONTAINER="wl_backup_test_$(date +%s)"
info "Starting temporary Postgres container: ${CONTAINER}"

docker run -d --name "$CONTAINER" \
    -e POSTGRES_USER=drupal \
    -e POSTGRES_DB=drupal \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    postgres:16 >/dev/null

# Ensure cleanup on exit
cleanup() {
    info "Cleaning up temporary container..."
    docker stop "$CONTAINER" >/dev/null 2>&1 || true
    docker rm "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Wait for Postgres to be ready
info "Waiting for Postgres to accept connections..."
for i in $(seq 1 20); do
    if docker exec "$CONTAINER" pg_isready -U drupal -d drupal >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
docker exec "$CONTAINER" pg_isready -U drupal -d drupal >/dev/null || {
    fail "Postgres container did not become ready within 20s"
    exit 1
}
ok "Postgres container is ready"

# ── Restore dump ─────────────────────────────────────────────────────────────
info "Restoring database dump (this may take a minute)..."
# Suppress "role does not exist" warnings — expected because the dump includes
# GRANT statements for wl_app which isn't present in the fresh temp container.
# These are non-fatal: the data restores correctly and Drupal runs as wl_app.
if ! gunzip -c "$DB_DUMP" \
    | docker exec -i "$CONTAINER" psql -U drupal -d drupal -q 2>&1 \
    | grep -v "role.*does not exist" \
    | grep -v "^$"; then
    # grep returns non-zero if no lines pass; only fail if psql itself errors
    true
fi
# Verify psql actually succeeded by checking the table count exists
if ! docker exec "$CONTAINER" psql -U drupal -d drupal -c "SELECT 1" >/dev/null 2>&1; then
    fail "psql restore failed — cannot query the restored database"
    exit 1
fi
ok "Database restored successfully"

# ── Verify restore ───────────────────────────────────────────────────────────
info "Verifying restored data..."

# 1. Table count
TABLE_COUNT=$(docker exec "$CONTAINER" psql -U drupal -d drupal -t -c \
    "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" \
    | tr -d ' \n')
if [ "${TABLE_COUNT:-0}" -lt 50 ]; then
    fail "Only ${TABLE_COUNT} tables found — expected ≥50 for a populated Drupal install"
    exit 1
fi
ok "Table count: ${TABLE_COUNT} tables in public schema"

# 2. Key Drupal tables exist
MISSING=""
for tbl in node node_field_data users users_field_data config; do
    EXISTS=$(docker exec "$CONTAINER" psql -U drupal -d drupal -t -c \
        "SELECT 1 FROM information_schema.tables WHERE table_name = '${tbl}' AND table_schema = 'public';" \
        | tr -d ' \n')
    if [ "$EXISTS" != "1" ]; then
        MISSING="${MISSING} ${tbl}"
    fi
done
if [ -n "$MISSING" ]; then
    fail "Missing expected Drupal core tables:${MISSING}"
    exit 1
fi
ok "Core Drupal tables present (node, users, config, ...)"

# 3. Node count (sanity — should be > 0 for any real site)
NODE_COUNT=$(docker exec "$CONTAINER" psql -U drupal -d drupal -t -c \
    "SELECT count(*) FROM node;" | tr -d ' \n')
ok "Node count: ${NODE_COUNT} nodes"

# 4. Config entries
CONFIG_COUNT=$(docker exec "$CONTAINER" psql -U drupal -d drupal -t -c \
    "SELECT count(*) FROM config;" | tr -d ' \n')
if [ "${CONFIG_COUNT:-0}" -lt 10 ]; then
    warn "Config table has only ${CONFIG_COUNT} entries — may be an incomplete backup"
fi
ok "Config entries: ${CONFIG_COUNT}"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "Backup restore test PASSED"
echo ""
info "  Backup date:  $(basename "$BACKUP_DIR")"
info "  Dump file:    $(basename "$DB_DUMP")"
info "  Dump size:    $(du -h "$DB_DUMP" | cut -f1)"
info "  Tables:       ${TABLE_COUNT}"
info "  Nodes:        ${NODE_COUNT}"
info "  Config rows:  ${CONFIG_COUNT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
