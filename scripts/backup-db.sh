#!/bin/bash
# Database backup script for Wilkes Liberty infrastructure
# This script creates backups of the production database

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/opt/backups/db}"
DB_HOST="${DB_HOST:-db1.prod.wilkesliberty.com}"
DB_NAME="${DB_NAME:-drupal}"
DB_USER="${DB_USER:-backup_user}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/drupal_backup_${TIMESTAMP}.sql.gz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if mysqldump is available
    if ! command -v mysqldump &> /dev/null; then
        error "mysqldump not found. Please install MySQL client tools."
        exit 1
    fi
    
    # Check if backup directory exists
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
    
    # Check database connectivity
    if ! mysql -h "$DB_HOST" -u "$DB_USER" -e "SELECT 1;" &>/dev/null; then
        error "Cannot connect to database. Check credentials and connectivity."
        exit 1
    fi
}

# Create database backup
create_backup() {
    log "Starting database backup..."
    log "Database: $DB_NAME"
    log "Host: $DB_HOST" 
    log "Output: $BACKUP_FILE"
    
    # Create the backup with compression
    if mysqldump \
        --host="$DB_HOST" \
        --user="$DB_USER" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --add-drop-database \
        --databases "$DB_NAME" | gzip > "$BACKUP_FILE"; then
        
        log "Backup completed successfully"
        log "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
    else
        error "Backup failed!"
        exit 1
    fi
}

# Clean up old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    find "$BACKUP_DIR" -name "drupal_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    local remaining_backups=$(find "$BACKUP_DIR" -name "drupal_backup_*.sql.gz" | wc -l)
    log "Remaining backups: $remaining_backups"
}

# Main execution
main() {
    log "=== Database Backup Script Started ==="
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                cat << EOF
Usage: $0 [options]

Options:
    --help, -h          Show this help message
    --dry-run           Show what would be done without executing
    --retention DAYS    Set retention period (default: $RETENTION_DAYS)
    --backup-dir DIR    Set backup directory (default: $BACKUP_DIR)

Environment Variables:
    DB_HOST            Database hostname (default: $DB_HOST)
    DB_NAME            Database name (default: $DB_NAME)  
    DB_USER            Database user (default: $DB_USER)
    BACKUP_DIR         Backup directory (default: $BACKUP_DIR)
    RETENTION_DAYS     Retention period in days (default: $RETENTION_DAYS)

Example:
    $0 --retention 14 --backup-dir /custom/backup/path
EOF
                exit 0
                ;;
            --dry-run)
                log "DRY RUN MODE - No actual backup will be created"
                DRY_RUN=true
                shift
                ;;
            --retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            --backup-dir)
                BACKUP_DIR="$2"
                BACKUP_FILE="${BACKUP_DIR}/drupal_backup_${TIMESTAMP}.sql.gz"
                shift 2
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log "Would create backup: $BACKUP_FILE"
        log "Would clean up backups older than $RETENTION_DAYS days from $BACKUP_DIR"
        exit 0
    fi
    
    check_prerequisites
    create_backup
    cleanup_old_backups
    
    log "=== Database Backup Script Completed ==="
}

# Run main function with all arguments
main "$@"