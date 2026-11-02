# PKHosting Backup & Restore – Operational Runbook

**Purpose:** Quick reference for operators when performing or troubleshooting backups and restores for sites hosted on (or similar to) the PKHosting platform.

---

## 1. Daily Backup Health Check

| Check | Command / Location | Expected Result |
|-------|--------------------|-----------------|
| Last backup exists | `ls -lt backups/` | Newest folder is from today or yesterday |
| Backup log | `tail -30 backups/backup.log` | Ends with “Backup completed successfully” |
| Retention | Count of `pkhosting_backup_*` folders | ≤ 7 |

If the last run failed, check the log and the alert destination (email/webhook).

---

## 2. Manual Backup

```bash
cd /path/to/pkhosting-backup-demo
./scripts/backup.sh
```

On success you will see the backup directory path.  
On failure an alert is sent and a partial folder is cleaned up.

---

## 3. Restore Procedure (Standard)

1. Identify the backup you need:
   ```bash
   ./scripts/restore.sh
   ```
   (Interactive list is shown)

2. Or restore a specific backup non-interactively:
   ```bash
   ./scripts/restore.sh pkhosting_backup_20261102_021500
   ```

3. Confirm with `yes` when prompted.

4. Verify the site:
   - Open http://localhost:8080 (or the production URL)
   - Check that expected content and visit counter are present

5. Record the restore time and backup name in your change log.

**Typical restore window for this sample size:** under 10 seconds.

---

## 4. Restore onto a Completely Fresh Server

1. Install Docker + Docker Compose
2. Clone the repository
3. Copy `config/backup.conf.example` → `config/backup.conf` and adjust paths/credentials
4. Copy the desired backup folder from the backup storage location
5. Start the stack: `docker compose up -d`
6. Run the restore script against the chosen backup
7. Verify

---

## 5. Failure Scenarios & Actions

| Symptom | Likely Cause | Action |
|---------|--------------|--------|
| “Configuration file not found” | Missing `backup.conf` | Copy from example and edit |
| mysqldump fails | DB container down or wrong credentials | `docker compose ps` / check config |
| Disk full | Too many backups or large site | Free space; retention should already limit to 7 |
| Alert not received | mail/sendmail missing or webhook invalid | Check `alert.sh` and config |
| Restore leaves site broken | Wrong backup chosen or incomplete archive | Restore from a known-good older backup |

---

## 6. Changing Retention or Storage Location

Edit `config/backup.conf`:

```bash
RETENTION_COUNT=7          # change as needed
BACKUP_ROOT=/mnt/backups   # point to another disk, NFS, or cloud mount
```

No code changes required.

---

## 7. Contacts / Escalation

- Primary: DevOps / System Administrator responsible for the server
- Secondary: PKHosting support (if this is a customer-facing managed service)

---

**Last updated:** November 2026

