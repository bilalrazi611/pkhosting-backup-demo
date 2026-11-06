#!/usr/bin/env bash
#
# PKHosting Restore Script
# Restores website files and database from a selected backup.
#
# Usage:
#   ./restore.sh                          # Interactive – lists available backups
#   ./restore.sh pkhosting_backup_YYYYMMDD_HHMMSS
#
# IMPORTANT: Run this against a fresh or intentionally wiped environment.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/backup.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

BACKUP_ROOT="${BACKUP_ROOT:-$PROJECT_ROOT/backups}"
SITE_ROOT="${SITE_ROOT:-$PROJECT_ROOT/sample-site}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# -------------------------------------------------------
# Select backup
# -------------------------------------------------------
if [[ $# -ge 1 ]]; then
    BACKUP_NAME="$1"
    BACKUP_DIR="${BACKUP_ROOT}/${BACKUP_NAME}"
else
    echo "Available backups:"
    echo "------------------"
    mapfile -t AVAILABLE < <(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "pkhosting_backup_*" | sort -r)
    if [[ ${#AVAILABLE[@]} -eq 0 ]]; then
        echo "No backups found in ${BACKUP_ROOT}"
        exit 1
    fi
    for i in "${!AVAILABLE[@]}"; do
        name=$(basename "${AVAILABLE[$i]}")
        size=$(du -sh "${AVAILABLE[$i]}" | cut -f1)
        echo "  [$((i+1))] ${name}  (${size})"
    done
    echo ""
    read -rp "Select backup number to restore: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#AVAILABLE[@]} )); then
        echo "Invalid selection."
        exit 1
    fi
    BACKUP_DIR="${AVAILABLE[$((choice-1))]}"
    BACKUP_NAME=$(basename "$BACKUP_DIR")
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "ERROR: Backup directory not found: $BACKUP_DIR"
    exit 1
fi

echo ""
echo "You are about to restore:"
echo "  Backup : ${BACKUP_NAME}"
echo "  Target : ${SITE_ROOT}"
echo "  Database: ${DB_NAME}"
echo ""
read -rp "Type 'yes' to continue: " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Restore cancelled."
    exit 0
fi

START_TIME=$(date +%s)
log "=== Starting restore from ${BACKUP_NAME} ==="

# -------------------------------------------------------
# 1. Restore files
# -------------------------------------------------------
log "Restoring website files ..."
if [[ ! -f "${BACKUP_DIR}/files.tar.gz" ]]; then
    echo "ERROR: files.tar.gz not found in backup"
    exit 1
fi

# Backup current site (safety)
SAFETY_DIR="${SITE_ROOT}.pre-restore.$(date +%Y%m%d_%H%M%S)"
if [[ -d "$SITE_ROOT" ]]; then
    log "Creating safety copy of current site at ${SAFETY_DIR}"
    mv "$SITE_ROOT" "$SAFETY_DIR"
fi

mkdir -p "$(dirname "$SITE_ROOT")"
tar -xzf "${BACKUP_DIR}/files.tar.gz" -C "$(dirname "$SITE_ROOT")" \
    || { echo "ERROR: Failed to extract files"; exit 1; }

log "Files restored."

# -------------------------------------------------------
# 2. Restore database
# -------------------------------------------------------
log "Restoring MySQL database ..."

if [[ ! -f "${BACKUP_DIR}/database.sql.gz" ]]; then
    echo "ERROR: database.sql.gz not found in backup"
    exit 1
fi

# Drop and recreate database for a clean restore
if docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER:-pkhosting-db}$"; then
    docker exec -i "${DB_CONTAINER:-pkhosting-db}" \
        mysql -u"${DB_USER}" -p"${DB_PASS}" -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; CREATE DATABASE \`${DB_NAME}\`;" \
        || { echo "ERROR: Failed to recreate database"; exit 1; }

    gunzip -c "${BACKUP_DIR}/database.sql.gz" | \
        docker exec -i "${DB_CONTAINER:-pkhosting-db}" \
        mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" \
        || { echo "ERROR: Failed to import database"; exit 1; }
else
    mysql -h"${DB_HOST:-127.0.0.1}" -P"${DB_PORT:-3307}" \
        -u"${DB_USER}" -p"${DB_PASS}" \
        -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; CREATE DATABASE \`${DB_NAME}\`;" \
        || { echo "ERROR: Failed to recreate database"; exit 1; }

    gunzip -c "${BACKUP_DIR}/database.sql.gz" | \
        mysql -h"${DB_HOST:-127.0.0.1}" -P"${DB_PORT:-3307}" \
        -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" \
        || { echo "ERROR: Failed to import database"; exit 1; }
fi

log "Database restored."

# -------------------------------------------------------
# 3. Verify restore against the backup metadata
# -------------------------------------------------------
log "Verifying restore ..."
db_query() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${DB_CONTAINER:-pkhosting-db}$"; then
        docker exec "${DB_CONTAINER:-pkhosting-db}" mysql -u"${DB_USER}" -p"${DB_PASS}" -N -e "$1" "${DB_NAME}" 2>/dev/null
    else
        mysql -h"${DB_HOST:-127.0.0.1}" -P"${DB_PORT:-3307}" -u"${DB_USER}" -p"${DB_PASS}" -N -e "$1" "${DB_NAME}" 2>/dev/null
    fi
}
EXPECTED_POSTS="$(grep '^Posts:' "${BACKUP_DIR}/metadata.txt" 2>/dev/null | awk '{print $2}')"
EXPECTED_VISITS="$(grep '^Visit count:' "${BACKUP_DIR}/metadata.txt" 2>/dev/null | awk '{print $3}')"
ACTUAL_POSTS="$(db_query "SELECT COUNT(*) FROM posts;" || echo "unknown")"
ACTUAL_VISITS="$(db_query "SELECT visit_count FROM stats WHERE id=1;" || echo "unknown")"
log "Posts: expected=${EXPECTED_POSTS} restored=${ACTUAL_POSTS}"
log "Visit count: expected=${EXPECTED_VISITS} restored=${ACTUAL_VISITS}"
if [[ -n "$EXPECTED_POSTS" && "$EXPECTED_POSTS" != "unknown" && "$EXPECTED_POSTS" == "$ACTUAL_POSTS" && "$EXPECTED_VISITS" == "$ACTUAL_VISITS" ]]; then
    log "Database check: OK (row counts match the backup)"
else
    echo "ERROR: Database check FAILED (restored counts do not match the backup metadata)"
    exit 1
fi
if diff <(tar -tzf "${BACKUP_DIR}/files.tar.gz" | grep -v '/$' | sort) <(cd "$SITE_ROOT" && find . -type f | sed 's|^\./|sample-site/|' | sort) >/dev/null; then
    log "Files check: OK (restored file list matches the backup archive)"
else
    echo "ERROR: Files check FAILED (restored file list differs from the backup)"
    exit 1
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

log "=== Restore completed successfully in ${DURATION} seconds ==="
echo ""
echo "Restore finished."
echo "  Backup used : ${BACKUP_NAME}"
echo "  Duration    : ${DURATION} seconds"
echo "  Site path   : ${SITE_ROOT}"
echo ""
echo "You can now verify the site (e.g. http://localhost:8080)."
