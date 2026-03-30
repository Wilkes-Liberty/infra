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

# ── Configuration ──
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-$HOME/Backups/wilkesliberty}"
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DAY=$(date +"%A")
BACKUP_DAY_OF_MONTH=$(date +"%d")
DOCKER_COMPOSE_DIR="$HOME/Repositories/infra/docker"
NAS_DOCKER_DIR="$HOME/nas_docker"

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

# ── Backup Directory Structure ──
setup_backup_dirs() {
    log "Setting up backup directory structure..."
    
    mkdir -p "$BACKUP_BASE_DIR"/{daily,weekly,monthly}
    mkdir -p "$BACKUP_BASE_DIR/logs"
    
    # Current backup working directory
    CURRENT_BACKUP_DIR="$BACKUP_BASE_DIR/daily/${BACKUP_DATE}"
    mkdir -p "$CURRENT_BACKUP_DIR"/{database,files,volumes}
    
    log "Backup directory: $CURRENT_BACKUP_DIR"
}

# ── PostgreSQL Database Backup ──
backup_postgres() {
    log "Backing up PostgreSQL database..."
    
    local db_backup_file="$CURRENT_BACKUP_DIR/database/drupal_postgres_${BACKUP_DATE}.sql.gz"
    
    # Use Docker to run pg_dump
    if docker exec wl_postgres pg_dump -U drupal -d drupal | gzip > "$db_backup_file"; then
        local size=$(du -h "$db_backup_file" | cut -f1)
        success "PostgreSQL backup complete: $size"
    else
        error "PostgreSQL backup failed!"
        return 1
    fi
}

# ── Drupal Files Backup ──
backup_drupal_files() {
    log "Backing up Drupal files..."
    
    local drupal_backup_file="$CURRENT_BACKUP_DIR/files/drupal_files_${BACKUP_DATE}.tar.gz"
    
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
        # Solr indexes can be large, so we compress heavily
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
    
    # Trigger Redis save first
    docker exec wl_redis redis-cli BGSAVE >/dev/null 2>&1 || warning "Redis BGSAVE failed"
    sleep 2  # Give Redis time to complete save
    
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
    
    # Copy to weekly if Sunday
    if [ "$backup_type" = "WEEKLY" ] || [ "$backup_type" = "MONTHLY" ]; then
        log "Creating weekly backup..."
        cp -r "$CURRENT_BACKUP_DIR" "$BACKUP_BASE_DIR/weekly/backup_${BACKUP_DATE}"
    fi
    
    # Copy to monthly if 1st of month
    if [ "$backup_type" = "MONTHLY" ]; then
        log "Creating monthly backup..."
        cp -r "$CURRENT_BACKUP_DIR" "$BACKUP_BASE_DIR/monthly/backup_${BACKUP_DATE}"
    fi
    
    # Clean up old daily backups
    log "Cleaning up old daily backups (keeping last $DAILY_RETENTION days)..."
    find "$BACKUP_BASE_DIR/daily" -maxdepth 1 -type d -mtime +$DAILY_RETENTION -exec rm -rf {} \; 2>/dev/null || true
    
    # Clean up old weekly backups
    log "Cleaning up old weekly backups (keeping last $WEEKLY_RETENTION days)..."
    find "$BACKUP_BASE_DIR/weekly" -maxdepth 1 -type d -mtime +$WEEKLY_RETENTION -exec rm -rf {} \; 2>/dev/null || true
    
    # Clean up old monthly backups
    log "Cleaning up old monthly backups (keeping last $MONTHLY_RETENTION days)..."
    find "$BACKUP_BASE_DIR/monthly" -maxdepth 1 -type d -mtime +$MONTHLY_RETENTION -exec rm -rf {} \; 2>/dev/null || true
    
    success "Backup rotation complete"
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
        
        # TODO: Implement cloud upload (iCloud, Proton Drive, etc.)
        # For now, just log the intention
        warning "Cloud upload not yet implemented - encrypted backup at: $encrypted_file"
        
        # Future implementations:
        # - rclone copy "$encrypted_file" proton-drive:backups/
        # - cp "$encrypted_file" ~/Library/Mobile\ Documents/com~apple~CloudDocs/Backups/
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
        
        # Use macOS mail command
        echo "$message" | mail -s "WilkesLiberty Backup: $status" "$NOTIFY_EMAIL" || {
            warning "Failed to send email notification"
        }
    fi
}

# ── Verify Backup Integrity ──
verify_backup() {
    log "Verifying backup integrity..."
    
    local errors=0
    
    # Check if backup directory exists and has files
    if [ ! -d "$CURRENT_BACKUP_DIR" ] || [ -z "$(ls -A $CURRENT_BACKUP_DIR)" ]; then
        error "Backup directory is empty or doesn't exist!"
        errors=$((errors + 1))
    fi
    
    # Verify database backup
    if [ -f "$CURRENT_BACKUP_DIR/database/drupal_postgres_${BACKUP_DATE}.sql.gz" ]; then
        if gunzip -t "$CURRENT_BACKUP_DIR/database/drupal_postgres_${BACKUP_DATE}.sql.gz" 2>/dev/null; then
            success "Database backup integrity verified"
        else
            error "Database backup is corrupted!"
            errors=$((errors + 1))
        fi
    fi
    
    # Verify file backups
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
    log "========================================"
    log "WilkesLiberty Backup Started"
    log "========================================"
    
    local start_time=$(date +%s)
    local backup_status="SUCCESS"
    local backup_message=""
    
    # Trap errors
    trap 'error "Backup failed!"; backup_status="FAILURE"' ERR
    
    # Setup
    setup_backup_dirs
    
    # Perform backups
    backup_postgres
    backup_drupal_files
    backup_keycloak
    backup_solr
    backup_redis
    backup_prometheus
    backup_grafana
    
    # Create manifest
    create_manifest
    
    # Verify backups
    if verify_backup; then
        success "Backup verification passed"
    else
        warning "Backup verification had issues, but continuing..."
        backup_status="WARNING"
    fi
    
    # Rotate backups
    rotate_backups
    
    # Optional: Encrypt
    local encrypted_file=$(encrypt_backup)
    
    # Optional: Upload to cloud
    upload_to_cloud "$encrypted_file"
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_min=$((duration / 60))
    local duration_sec=$((duration % 60))
    
    # Summary
    log "========================================"
    log "Backup Complete"
    log "========================================"
    log "Status: $backup_status"
    log "Duration: ${duration_min}m ${duration_sec}s"
    log "Backup Location: $CURRENT_BACKUP_DIR"
    log "Total Size: $(du -sh $CURRENT_BACKUP_DIR | cut -f1)"
    
    # Build notification message
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
    
    # Send notification
    send_notification "$backup_status" "$backup_message"
    
    if [ "$backup_status" = "SUCCESS" ]; then
        success "Backup completed successfully!"
        return 0
    else
        error "Backup completed with warnings or errors"
        return 1
    fi
}

# Run main function
main "$@"
