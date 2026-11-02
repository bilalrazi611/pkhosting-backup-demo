#!/usr/bin/env bash
#
# PKHosting Automated Backup Script
# Backs up website files + MySQL database, stores in a separate location,
# keeps only the last 7 successful backups, and sends an alert on failure.
#
# Usage: ./backup.sh
# Recommended: run daily via cron (see README)
#

set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/backup.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    echo "Copy config/backup.conf.example to config/backup.conf and edit values."
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Defaults if not set in config
BACKUP_ROOT="${BACKUP_ROOT:-$PROJECT_ROOT/backups}"
SITE_ROOT="${SITE_ROOT:-$PROJECT_ROOT/sample-site}"
RETENTION_COUNT="${RETENTION_COUNT:-7}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="pkhosting_backup_${TIMESTAMP}"
BACKUP_DIR="${BACKUP_ROOT}/${BACKUP_NAME}"
LOG_FILE="${BACKUP_ROOT}/backup.log"
ALERT_SCRIPT="${SCRIPT_DIR}/alert.sh"

# Ensure backup root exists
mkdir -p "$BACKUP_ROOT"
mkdir -p "$BACKUP_DIR"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

fail() {
    log "ERROR: $1"
    if [[ -x "$ALERT_SCRIPT" ]]; then
        "$ALERT_SCRIPT" "PKHosting Backup FAILED" "$1"
    fi
    # Clean up partial backup
    rm -rf "$BACKUP_DIR"
    exit 1
}

log "=== Starting PKHosting backup: ${BACKUP_NAME} ==="

# -------------------------------------------------------
# 1. Backup website files
# -------------------------------------------------------
log "Backing up website files from ${SITE_ROOT} ..."
if [[ ! -d "$SITE_ROOT" ]]; then
    fail "Site root directory not found: $SITE_ROOT"
fi

tar -czf "${BACKUP_DIR}/files.tar.gz" -C "$(dirname "$SITE_ROOT")" "$(basename "$SITE_ROOT")" \
    || fail "Failed to create files archive"

log "Files backup complete: $(du -h "${BACKUP_DIR}/files.tar.gz" | cut -f1)"

# -------------------------------------------------------
# 2. Backup MySQL database
# -------------------------------------------------------
log "Backing up MySQL database '${DB_NAME}' ..."

# Prefer docker exec if the db container is running
if docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER:-pkhosting-db}$"; then
    docker exec "${DB_CONTAINER:-pkhosting-db}" \
        mysqldump -u"${DB_USER}" -p"${DB_PASS}" --single-transaction --routines --triggers "${DB_NAME}" \
        > "${BACKUP_DIR}/database.sql" \
        || fail "mysqldump via docker failed"
else
    # Fallback to local mysqldump (if MySQL client is available)
    mysqldump -h"${DB_HOST:-127.0.0.1}" -P"${DB_PORT:-3307}" \
        -u"${DB_USER}" -p"${DB_PASS}" --single-transaction --routines --triggers "${DB_NAME}" \
        > "${BACKUP_DIR}/database.sql" \
        || fail "mysqldump failed"
fi

# Compress the dump
gzip "${BACKUP_DIR}/database.sql" \
    || fail "Failed to compress database dump"

log "Database backup complete: $(du -h "${BACKUP_DIR}/database.sql.gz" | cut -f1)"

# -------------------------------------------------------
# 3. Write metadata
# -------------------------------------------------------
cat > "${BACKUP_DIR}/metadata.txt" <<EOF
Backup Name:    ${BACKUP_NAME}
Timestamp:      $(date -Iseconds)
Host:           $(hostname)
Site Root:      ${SITE_ROOT}
Database:       ${DB_NAME}
Files Size:     $(du -h "${BACKUP_DIR}/files.tar.gz" | cut -f1)
DB Size:        $(du -h "${BACKUP_DIR}/database.sql.gz" | cut -f1)
EOF

log "Metadata written."

# -------------------------------------------------------
# 4. Retention: keep only the last N backups
# -------------------------------------------------------
log "Applying retention policy (keep last ${RETENTION_COUNT} backups) ..."

# List backup directories sorted by name (timestamp), oldest first
mapfile -t ALL_BACKUPS < <(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "pkhosting_backup_*" | sort)

TOTAL=${#ALL_BACKUPS[@]}
if (( TOTAL > RETENTION_COUNT )); then
    TO_DELETE=$(( TOTAL - RETENTION_COUNT ))
    log "Found ${TOTAL} backups. Removing oldest ${TO_DELETE} ..."
    for ((i=0; i<TO_DELETE; i++)); do
        log "  Deleting: ${ALL_BACKUPS[$i]}"
        rm -rf "${ALL_BACKUPS[$i]}"
    done
else
    log "Found ${TOTAL} backups. No cleanup needed."
fi

log "=== Backup completed successfully: ${BACKUP_NAME} ==="
log "Location: ${BACKUP_DIR}"
echo ""
echo "Backup successful: ${BACKUP_DIR}"
exit 0
