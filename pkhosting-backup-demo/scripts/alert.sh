#!/usr/bin/env bash
#
# PKHosting Alert Script
# Sends a notification when a backup fails.
# Supports: email (mail/sendmail) or a simple webhook (optional).
#
# Usage: ./alert.sh "Subject" "Body message"
#

set -euo pipefail

SUBJECT="${1:-PKHosting Backup Alert}"
BODY="${2:-A backup operation failed. Please check the logs.}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/backup.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

ALERT_EMAIL="${ALERT_EMAIL:-}"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
LOG_FILE="${BACKUP_ROOT:-$PROJECT_ROOT/backups}/backup.log"

log_alert() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1" >> "${LOG_FILE:-/tmp/pkhosting-alert.log}"
}

# -------------------------------------------------------
# Method 1: Email (if ALERT_EMAIL is set and mail is available)
# -------------------------------------------------------
if [[ -n "$ALERT_EMAIL" ]]; then
    if command -v mail >/dev/null 2>&1; then
        echo "$BODY" | mail -s "$SUBJECT" "$ALERT_EMAIL" \
            && log_alert "Email sent to ${ALERT_EMAIL}" \
            || log_alert "Failed to send email to ${ALERT_EMAIL}"
    elif command -v sendmail >/dev/null 2>&1; then
        {
            echo "To: ${ALERT_EMAIL}"
            echo "Subject: ${SUBJECT}"
            echo ""
            echo "$BODY"
        } | sendmail -t \
            && log_alert "Email sent via sendmail to ${ALERT_EMAIL}" \
            || log_alert "Failed to send email via sendmail"
    else
        log_alert "mail/sendmail not available – email alert skipped"
    fi
fi

# -------------------------------------------------------
# Method 2: Simple webhook (Slack / Discord / custom)
# -------------------------------------------------------
if [[ -n "$ALERT_WEBHOOK" ]]; then
    if command -v curl >/dev/null 2>&1; then
        curl -s -X POST -H "Content-Type: application/json" \
            -d "{\"text\":\"*${SUBJECT}*\n${BODY}\"}" \
            "$ALERT_WEBHOOK" >/dev/null \
            && log_alert "Webhook notification sent" \
            || log_alert "Webhook notification failed"
    else
        log_alert "curl not available – webhook alert skipped"
    fi
fi

# -------------------------------------------------------
# Always write to local log so the failure is never silent
# -------------------------------------------------------
log_alert "${SUBJECT} | ${BODY}"

echo "Alert recorded: ${SUBJECT}"
exit 0
