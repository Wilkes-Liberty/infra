#!/bin/bash
# =============================================
# WilkesLiberty On-Premises Backup Script
# =============================================
# Backs up:
#   - PostgreSQL database (Drupal + Keycloak)
#   - Drupal files (~/nas_docker/drupal)
#   - Keycloak data (~/nas_docker/keycloak)
#   - Solr indexes (~/nas_docker/solr)
#   - Redis data (~/nas_docker/redis)
#   - Docker volumes
#
# Retention:
#   - Daily: 7 days
#   - Weekly: 4 weeks
#   - Monthly: 12 months
# =============================================

set -euo pipefail

# ── PATH: launchd provides only /usr/bin:/bin:/usr/sbin:/sbin by default.
# Docker Desktop installs the CLI at /usr/local/bin/docker (symlink to the app
# bundle) and Homebrew puts it at /opt/homebrew/bin/docker. Prepend both so
# this script works in both the launchd and interactive shell contexts.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# ── Argument parsing ──────────────────────────────────────────────────────────
DRY_RUN=false

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "WilkesLiberty on-premises backup script."
    echo ""
    echo "Options:"
    echo "  --dry-run   Print what would be done without creating any files"
    echo "  --help      Show this help message and exit"
    echo ""
    echo "Environment variables:"
    echo "  BACKUP_BASE_DIR           Backup destination (default: ~/Backups/wilkesliberty)"
    echo "  BACKUP_NOTIFICATION_EMAIL Email address for backup status notifications"
    echo "  BACKUP_ENCRYPTION_KEY     Passphrase for AES-256 encrypted archive"
    echo "  POSTMARK_SERVER_TOKEN     Postmark API token for failure alerts"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")            # Run a real backup"
    echo "  $(basename "$0") --dry-run  # Preview without writing anything"
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage; exit 1 ;;
    esac
done

# ── Configuration ──
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-$HOME/Backups/wilkesliberty}"
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DAY=$(date +"%A")
BACKUP_DAY_OF_MONTH=$(date +"%d")
NAS_DOCKER_DIR="$HOME/nas_docker"

# Load credentials from the Docker env file if available. This ensures
# BACKUP_ENCRYPTION_KEY, BACKUP_NOTIFICATION_EMAIL, and POSTMARK_SERVER_TOKEN
# are present even in the launchd context (which inherits no shell env).
ENV_FILE="$HOME/nas_docker/.env"
if [ -f "$ENV_FILE" ]; then
    # Source selectively to avoid clobbering unrelated vars.
    # shellcheck disable=SC1090
    _src_val() { grep "^${1}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | sed 's/^["'"'"']//;s/["'"'"']$//' || true; }
    BACKUP_ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-$(_src_val BACKUP_ENCRYPTION_KEY)}"
    BACKUP_NOTIFICATION_EMAIL="${BACKUP_NOTIFICATION_EMAIL:-$(_src_val BACKUP_NOTIFICATION_EMAIL)}"
    POSTMARK_SERVER_TOKEN="${POSTMARK_SERVER_TOKEN:-$(_src_val POSTMARK_SERVER_TOKEN)}"
fi

# Retention settings
DAILY_RETENTION=7
WEEKLY_RETENTION=28
MONTHLY_RETENTION=365

# Notification settings
NOTIFY_EMAIL="${BACKUP_NOTIFICATION_EMAIL:-}"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Logging Functions ──
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

success() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

# ── Dry-run wrapper ───────────────────────────────────────────────────────────
run_cmd() {
    local description="$1"
    shift
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] $description${NC}"
        echo -e "  → $*"
    else
        "$@"
    fi
}

# ── Failure alert via Postmark API ────────────────────────────────────────────
# Sends an email via the Postmark API using /usr/bin/curl (always on PATH).
# Requires POSTMARK_SERVER_TOKEN to be set (loaded from .env above).
# Safe to call early — curl is on the standard PATH even without our export.
send_failure_alert() {
    local reason="$1"
    local details="${2:-}"

    error "Backup failure: ${reason}"

    if [ -z "${POSTMARK_SERVER_TOKEN:-}" ]; then
        warning "POSTMARK_SERVER_TOKEN not set — failure alert not sent"
        return 0
    fi

    local to="${NOTIFY_EMAIL:-3@wilkesliberty.com}"
    local log_tail
    log_tail=$(tail -20 "${BACKUP_BASE_DIR}/logs/backup-error.log" 2>/dev/null || true)

    local full_body
    full_body="Backup failure on $(hostname) at ${BACKUP_DATE}

Reason: ${reason}

Details:
${details}

Recent error log (last 20 lines):
${log_tail:-  (no error log available)}"

    # Use python3 (-c with sys.argv) to produce properly-escaped JSON.
    # python3 is at /usr/bin/python3 on macOS (Command Line Tools).
    local payload
    if ! payload=$(python3 -c "
import json, sys
subject, body, to = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({'From':'alerts@wilkesliberty.com','To':to,'Subject':subject,'TextBody':body}))
" "[wl-prod] Backup FAILED — ${reason}" "${full_body}" "${to}" 2>/dev/null); then
        warning "Could not build Postmark payload — skipping alert"
        return 0
    fi

    /usr/bin/curl -s -X POST https://api.postmarkapp.com/email \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "X-Postmark-Server-Token: ${POSTMARK_SERVER_TOKEN}" \
        -d "${payload}" >/dev/null 2>&1 \
        && log "Failure alert sent via Postmark to ${to}" \
        || warning "Failed to send Postmark alert (curl error)"
}

# ── Pre-flight checks ─────────────────────────────────────────────────────────
# Abort early with a Postmark alert if the prerequisites aren't met.
# Called before any backup I/O so we don't create a partial backup directory.
check_prerequisites() {
    log "Running pre-flight checks..."

    if ! command -v docker >/dev/null 2>&1; then
        send_failure_alert "docker not found on PATH" \
            "PATH at backup time: ${PATH}

Fix: verify /opt/homebrew/bin or /usr/local/bin is in the script PATH export."
        exit 1
    fi

    local pg_name
    pg_name=$(docker ps --filter "name=wl_postgres" --format '{{.Names}}' 2>/dev/null | head -1)
    if [ -z "$pg_name" ]; then
        local pg_state
        pg_state=$(docker ps -a --filter "name=wl_postgres" --format 'Status: {{.Status}}' 2>/dev/null | head -1)
        send_failure_alert "wl_postgres container not running" \
            "Container state: ${pg_state:-not found}

The Docker stack may be down. Run: docker compose -f ~/nas_docker/docker-compose.yml up -d"
        exit 1
    fi

    local health
    health=$(docker inspect -f '{{.State.Health.Status}}' wl_postgres 2>/dev/null || echo "no healthcheck")
    if [ "$health" = "unhealthy" ]; then
        warning "wl_postgres health is '${health}' — attempting backup anyway"
    fi

    success "Pre-flight: docker OK, wl_postgres running (health: ${health})"
}

# ── Backup Directory Structure ──
setup_backup_dirs() {
    log "Setting up backup directory structure..."

    CURRENT_BACKUP_DIR="$BACKUP_BASE_DIR/daily/${BACKUP_DATE}"

    if [ "$DRY_RUN" = true ]; then
        warning "[DRY RUN] Would create: $BACKUP_BASE_DIR/{daily,weekly,monthly,logs}"
        warning "[DRY RUN] Would create: $CURRENT_BACKUP_DIR/{database,files,volumes}"
        log "Dry-run backup directory: $CURRENT_BACKUP_DIR"
        return
    fi

    mkdir -p "$BACKUP_BASE_DIR"/{daily,weekly,monthly}
    mkdir -p "$BACKUP_BASE_DIR/logs"
    mkdir -p "$CURRENT_BACKUP_DIR"/{database,files,volumes}

    log "Backup directory: $CURRENT_BACKUP_DIR"
}

# ── PostgreSQL Database Backup ──
backup_postgres() {
    log "Backing up PostgreSQL database..."

    local db_backup_file="$CURRENT_BACKUP_DIR/database/drupal_postgres_${BACKUP_DATE}.sql.gz"

    if [ "$DRY_RUN" = true ]; then
        warning "[DRY RUN] Would run: docker exec wl_postgres pg_dump -U drupal -d drupal | gzip > $db_backup_file"
        warning "[DRY RUN] Would run: docker exec wl_postgres pg_dump -U keycloak -d keycloak | gzip > (keycloak backup file)"
        return
    fi

    # Dump to a .tmp file so a failed/empty dump never masquerades as a valid
    # backup in the daily directory. Move to the final name only after passing
    # a size check.
    local tmp_dump="${db_backup_file}.tmp"

    if docker exec wl_postgres pg_dump -U drupal -d drupal | gzip > "$tmp_dump"; then
        local dump_bytes
        dump_bytes=$(stat -f%z "$tmp_dump" 2>/dev/null || stat -c%s "$tmp_dump")
        if [ "${dump_bytes:-0}" -lt 10240 ]; then
            rm -f "$tmp_dump"
            local health
            health=$(docker inspect -f '{{.State.Health.Status}}' wl_postgres 2>/dev/null || echo "unknown")
            send_failure_alert "Drupal dump suspiciously small (${dump_bytes} bytes)" \
                "Expected at least 10 KB for a populated Drupal database.
wl_postgres health: ${health}

This usually means pg_dump produced no output. Check container logs:
  docker logs wl_postgres --tail 50"
            return 1
        fi
        mv "$tmp_dump" "$db_backup_file"
        local size
        size=$(du -h "$db_backup_file" | cut -f1)
        success "PostgreSQL (drupal) backup complete: $size"
    else
        rm -f "$tmp_dump"
        send_failure_alert "pg_dump failed (nonzero exit)" \
            "docker exec wl_postgres pg_dump -U drupal -d drupal exited with an error.
Check container logs: docker logs wl_postgres --tail 50"
        error "PostgreSQL (drupal) backup failed!"
        return 1
    fi

    # Keycloak database (optional — may not exist yet)
    local kc_backup_file="$CURRENT_BACKUP_DIR/database/keycloak_postgres_${BACKUP_DATE}.sql.gz"
    local kc_tmp="${kc_backup_file}.tmp"
    if docker exec wl_postgres pg_dump -U keycloak -d keycloak | gzip > "$kc_tmp" 2>/dev/null; then
        local kc_bytes
        kc_bytes=$(stat -f%z "$kc_tmp" 2>/dev/null || stat -c%s "$kc_tmp")
        if [ "${kc_bytes:-0}" -gt 1024 ]; then
            mv "$kc_tmp" "$kc_backup_file"
            local kc_size
            kc_size=$(du -h "$kc_backup_file" | cut -f1)
            success "PostgreSQL (keycloak) backup complete: $kc_size"
        else
            rm -f "$kc_tmp"
            warning "PostgreSQL (keycloak) backup skipped — keycloak database may not exist yet"
        fi
    else
        rm -f "$kc_tmp"
        warning "PostgreSQL (keycloak) backup skipped — keycloak database may not exist yet"
    fi
}

# ── Drupal Files Backup ──
backup_drupal_files() {
    log "Backing up Drupal files..."

    local drupal_backup_file="$CURRENT_BACKUP_DIR/files/drupal_files_${BACKUP_DATE}.tar.gz"

    if [ "$DRY_RUN" = true ]; then
        warning "[DRY RUN] Would backup: $NAS_DOCKER_DIR/drupal → $drupal_backup_file"
        return
    fi

    if [ -d "$NAS_DOCKER_DIR/drupal" ]; then
        tar -czf "$drupal_backup_file" -C "$NAS_DOCKER_DIR" drupal 2>/dev/null || {
            warning "Some Drupal files may be inaccessible (permissions), continuing..."
        }
        local size=$(du -h "$drupal_backup_file" | cut -f1)
        success "Drupal files backup complete: $size"
    else
        warning "Drupal directory not found, skipping"
    fi
}

# ── Keycloak Data Backup ──
backup_keycloak() {
    log "Backing up Keycloak data..."

    local keycloak_backup_file="$CURRENT_BACKUP_DIR/files/keycloak_data_${BACKUP_DATE}.tar.gz"

    if [ -d "$NAS_DOCKER_DIR/keycloak" ]; then
        tar -czf "$keycloak_backup_file" -C "$NAS_DOCKER_DIR" keycloak 2>/dev/null || {
            warning "Some Keycloak files may be inaccessible, continuing..."
        }
        local size=$(du -h "$keycloak_backup_file" | cut -f1)
        success "Keycloak backup complete: $size"
    else
        warning "Keycloak directory not found, skipping"
    fi
}

# ── Solr Indexes Backup (Optional) ──
backup_solr() {
    log "Backing up Solr indexes (optional)..."

    local solr_backup_file="$CURRENT_BACKUP_DIR/files/solr_indexes_${BACKUP_DATE}.tar.gz"

    if [ -d "$NAS_DOCKER_DIR/solr" ]; then
        tar -czf "$solr_backup_file" -C "$NAS_DOCKER_DIR" solr 2>/dev/null || {
            warning "Some Solr files may be inaccessible, continuing..."
        }
        local size=$(du -h "$solr_backup_file" | cut -f1)
        success "Solr backup complete: $size"
    else
        warning "Solr directory not found, skipping"
    fi
}

# ── Redis Data Backup ──
backup_redis() {
    log "Backing up Redis data..."

    # Trigger Redis save first (best-effort; container may not be running)
    docker exec wl_redis redis-cli BGSAVE >/dev/null 2>&1 || warning "Redis BGSAVE failed (container may be down)"
    sleep 2

    local redis_backup_file="$CURRENT_BACKUP_DIR/files/redis_data_${BACKUP_DATE}.tar.gz"

    if [ -d "$NAS_DOCKER_DIR/redis" ]; then
        tar -czf "$redis_backup_file" -C "$NAS_DOCKER_DIR" redis
        local size=$(du -h "$redis_backup_file" | cut -f1)
        success "Redis backup complete: $size"
    else
        warning "Redis directory not found, skipping"
    fi
}

# ── Prometheus Data Backup ──
backup_prometheus() {
    log "Backing up Prometheus metrics data..."

    local prometheus_backup_file="$CURRENT_BACKUP_DIR/volumes/prometheus_${BACKUP_DATE}.tar.gz"

    if [ -d "$NAS_DOCKER_DIR/prometheus/data" ]; then
        tar -czf "$prometheus_backup_file" -C "$NAS_DOCKER_DIR/prometheus" data
        local size=$(du -h "$prometheus_backup_file" | cut -f1)
        success "Prometheus backup complete: $size"
    else
        warning "Prometheus data directory not found, skipping"
    fi
}

# ── Grafana Dashboards Backup ──
backup_grafana() {
    log "Backing up Grafana dashboards and config..."

    local grafana_backup_file="$CURRENT_BACKUP_DIR/volumes/grafana_${BACKUP_DATE}.tar.gz"

    if [ -d "$NAS_DOCKER_DIR/grafana" ]; then
        tar -czf "$grafana_backup_file" -C "$NAS_DOCKER_DIR" grafana
        local size=$(du -h "$grafana_backup_file" | cut -f1)
        success "Grafana backup complete: $size"
    else
        warning "Grafana directory not found, skipping"
    fi
}

# ── Create Backup Manifest ──
create_manifest() {
    log "Creating backup manifest..."

    local manifest_file="$CURRENT_BACKUP_DIR/MANIFEST.txt"

    cat > "$manifest_file" << EOF
WilkesLiberty Backup Manifest
=============================
Backup Date: $BACKUP_DATE
Backup Type: $(determine_backup_type)
Hostname: $(hostname)
Mac Mini Model: $(system_profiler SPHardwareDataType | grep "Model Name" | cut -d: -f2 | xargs)

Contents:
---------
$(find "$CURRENT_BACKUP_DIR" -type f -exec ls -lh {} \; | awk '{print $9, $5}')

Total Backup Size:
------------------
$(du -sh "$CURRENT_BACKUP_DIR" | cut -f1)

Checksums (SHA256):
-------------------
$(find "$CURRENT_BACKUP_DIR" -type f -name "*.gz" -exec shasum -a 256 {} \;)
EOF

    success "Manifest created: $manifest_file"
}

# ── Determine Backup Type ──
determine_backup_type() {
    if [ "$BACKUP_DAY_OF_MONTH" = "01" ]; then
        echo "MONTHLY"
    elif [ "$BACKUP_DAY" = "Sunday" ]; then
        echo "WEEKLY"
    else
        echo "DAILY"
    fi
}

# ── Rotate Weekly and Monthly Backups ──
rotate_backups() {
    log "Rotating backups..."

    local backup_type=$(determine_backup_type)

    if [ "$backup_type" = "WEEKLY" ] || [ "$backup_type" = "MONTHLY" ]; then
        log "Creating weekly backup..."
        cp -r "$CURRENT_BACKUP_DIR" "$BACKUP_BASE_DIR/weekly/backup_${BACKUP_DATE}"
    fi

    if [ "$backup_type" = "MONTHLY" ]; then
        log "Creating monthly backup..."
        cp -r "$CURRENT_BACKUP_DIR" "$BACKUP_BASE_DIR/monthly/backup_${BACKUP_DATE}"
    fi

    log "Cleaning up old daily backups (keeping last $DAILY_RETENTION days)..."
    find "$BACKUP_BASE_DIR/daily" -maxdepth 1 -type d -mtime +$DAILY_RETENTION -exec rm -rf {} \; 2>/dev/null || true

    log "Cleaning up old weekly backups (keeping last $WEEKLY_RETENTION days)..."
    find "$BACKUP_BASE_DIR/weekly" -maxdepth 1 -type d -mtime +$WEEKLY_RETENTION -exec rm -rf {} \; 2>/dev/null || true

    log "Cleaning up old monthly backups (keeping last $MONTHLY_RETENTION days)..."
    find "$BACKUP_BASE_DIR/monthly" -maxdepth 1 -type d -mtime +$MONTHLY_RETENTION -exec rm -rf {} \; 2>/dev/null || true

    success "Backup rotation complete"
}

# ── Log Rotation ──────────────────────────────────────────────────────────────
# Called at EXIT so it runs after all output for this session is written.
# Trims backup.log and backup-error.log to the last 10 000 lines (~100 daily
# runs). After this process exits, launchd closes the file descriptor; the
# next run appends to the trimmed file normally.
rotate_logs() {
    local max_lines=10000
    local log_dir="${BACKUP_BASE_DIR}/logs"
    for f in "${log_dir}/backup.log" "${log_dir}/backup-error.log"; do
        [ -f "$f" ] || continue
        local lines
        lines=$(wc -l < "$f" 2>/dev/null || echo 0)
        if [ "$lines" -gt "$max_lines" ]; then
            tail -n "$max_lines" "$f" > "$f.tmp" 2>/dev/null \
                && mv "$f.tmp" "$f" \
                || rm -f "$f.tmp"
        fi
    done
}

# ── Encrypt Backup (Optional) ──
encrypt_backup() {
    if [ -n "$ENCRYPTION_KEY" ]; then
        log "Encrypting backup..."

        local encrypted_file="$BACKUP_BASE_DIR/encrypted/backup_${BACKUP_DATE}.tar.gz.enc"
        mkdir -p "$BACKUP_BASE_DIR/encrypted"

        tar -czf - -C "$BACKUP_BASE_DIR/daily" "${BACKUP_DATE}" | \
            openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"$ENCRYPTION_KEY" > "$encrypted_file"

        local size=$(du -h "$encrypted_file" | cut -f1)
        success "Encrypted backup created: $size"

        echo "$encrypted_file"
    else
        warning "Encryption key not set, skipping encryption"
        echo ""
    fi
}

# ── Upload to Cloud (Placeholder) ──
upload_to_cloud() {
    local encrypted_file="$1"

    if [ -n "$encrypted_file" ]; then
        log "Uploading encrypted backup to cloud storage..."
        warning "Cloud upload not yet implemented - encrypted backup at: $encrypted_file"
    else
        warning "No encrypted file to upload"
    fi
}

# ── Send Notification ──
send_notification() {
    local status="$1"
    local message="$2"

    if [ -n "$NOTIFY_EMAIL" ]; then
        log "Sending notification email to $NOTIFY_EMAIL..."
        echo "$message" | mail -s "WilkesLiberty Backup: $status" "$NOTIFY_EMAIL" || {
            warning "Failed to send email notification"
        }
    fi
}

# ── Verify Backup Integrity ──
verify_backup() {
    log "Verifying backup integrity..."

    local errors=0

    if [ ! -d "$CURRENT_BACKUP_DIR" ] || [ -z "$(ls -A $CURRENT_BACKUP_DIR)" ]; then
        error "Backup directory is empty or doesn't exist!"
        errors=$((errors + 1))
    fi

    if [ -f "$CURRENT_BACKUP_DIR/database/drupal_postgres_${BACKUP_DATE}.sql.gz" ]; then
        if gunzip -t "$CURRENT_BACKUP_DIR/database/drupal_postgres_${BACKUP_DATE}.sql.gz" 2>/dev/null; then
            success "Database backup integrity verified"
        else
            error "Database backup is corrupted!"
            errors=$((errors + 1))
        fi
    fi

    for file in "$CURRENT_BACKUP_DIR/files"/*.tar.gz; do
        if [ -f "$file" ]; then
            if tar -tzf "$file" >/dev/null 2>&1; then
                success "File backup $(basename $file) integrity verified"
            else
                error "File backup $(basename $file) is corrupted!"
                errors=$((errors + 1))
            fi
        fi
    done

    if [ $errors -eq 0 ]; then
        success "All backups verified successfully!"
        return 0
    else
        error "Backup verification failed with $errors errors"
        return 1
    fi
}

# ── Main Execution ──
main() {
    # Trim log files at exit so they don't grow unbounded (~100 daily runs max).
    trap 'rotate_logs' EXIT

    if [ "$DRY_RUN" = true ]; then
        log "========================================"
        log "WilkesLiberty Backup (DRY RUN — no files will be created)"
        log "========================================"
    else
        log "========================================"
        log "WilkesLiberty Backup Started"
        log "========================================"
    fi

    local start_time=$(date +%s)
    local backup_status="SUCCESS"
    local backup_message=""

    trap 'error "Backup failed!"; backup_status="FAILURE"' ERR

    # Verify Docker and the Postgres container are available before creating
    # any directories or dump files.
    if [ "$DRY_RUN" = false ]; then
        check_prerequisites
    fi

    setup_backup_dirs

    backup_postgres
    backup_drupal_files
    backup_keycloak
    backup_solr
    backup_redis
    backup_prometheus
    backup_grafana

    create_manifest

    if verify_backup; then
        success "Backup verification passed"
    else
        warning "Backup verification had issues, but continuing..."
        backup_status="WARNING"
    fi

    rotate_backups

    local encrypted_file=$(encrypt_backup)

    upload_to_cloud "$encrypted_file"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_min=$((duration / 60))
    local duration_sec=$((duration % 60))

    log "========================================"
    log "Backup Complete"
    log "========================================"
    log "Status: $backup_status"
    log "Duration: ${duration_min}m ${duration_sec}s"
    log "Backup Location: $CURRENT_BACKUP_DIR"
    log "Total Size: $(du -sh $CURRENT_BACKUP_DIR | cut -f1)"

    backup_message="WilkesLiberty Backup Completed

Status: $backup_status
Date: $BACKUP_DATE
Duration: ${duration_min}m ${duration_sec}s
Location: $CURRENT_BACKUP_DIR
Size: $(du -sh $CURRENT_BACKUP_DIR | cut -f1)

Backup Contents:
- PostgreSQL database
- Drupal files
- Keycloak data
- Solr indexes
- Redis data
- Prometheus metrics
- Grafana dashboards

Retention: Daily (7d), Weekly (4w), Monthly (12mo)
"

    send_notification "$backup_status" "$backup_message"

    if [ "$backup_status" = "SUCCESS" ]; then
        success "Backup completed successfully!"
        return 0
    else
        error "Backup completed with warnings or errors"
        return 1
    fi
}

main "$@"
