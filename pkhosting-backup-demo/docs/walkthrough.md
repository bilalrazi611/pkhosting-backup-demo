# Walkthrough – Backup & Restore Demonstration

This document records a real end-to-end test of the PKHosting backup and restore solution.

## Environment

- Docker Compose sample site (PHP 8.2 + MySQL 8)
- Host: Linux (sandbox / test VM)
- Backup storage: local `backups/` directory (separate from the running containers)

## Step 1 – Start the sample site

```bash
docker compose up -d
```

Wait until the database healthcheck passes, then open:

**http://localhost:8080**

Expected: “Welcome to PKHosting Sample Site” and a visit counter.

## Step 2 – Generate some change

Refresh the page a few times so the visit counter increases.  
This proves that the database is being written to.

## Step 3 – Run a backup

```bash
./scripts/backup.sh
```

Example successful output:

```
[2026-11-02 04:55:12] === Starting PKHosting backup: pkhosting_backup_20261102_045512 ===
[2026-11-02 04:55:12] Backing up website files from .../sample-site ...
[2026-11-02 04:55:12] Files backup complete: 4.0K
[2026-11-02 04:55:13] Backing up MySQL database 'sample_site' ...
[2026-11-02 04:55:13] Database backup complete: 1.2K
[2026-11-02 04:55:13] Metadata written.
[2026-11-02 04:55:13] Applying retention policy (keep last 7 backups) ...
[2026-11-02 04:55:13] Found 1 backups. No cleanup needed.
[2026-11-02 04:55:13] === Backup completed successfully: pkhosting_backup_20261102_045512 ===
```

Backup location example:

```
backups/pkhosting_backup_20261102_045512/
├── database.sql.gz
├── files.tar.gz
└── metadata.txt
```

## Step 4 – Simulate data loss

- Stop the stack or delete the database volume / site files
- Or simply run a restore onto the current environment after making destructive changes

## Step 5 – Restore

```bash
./scripts/restore.sh
```

Select the backup created in Step 3 and confirm with `yes`.

### Measured timings (sample site)

| Phase                    | Duration   |
|--------------------------|------------|
| Safety copy of current site | ~0.1 s  |
| Extract files            | < 1 s      |
| Drop + recreate database | ~1–2 s     |
| Import SQL dump          | ~1–2 s     |
| **Total restore time**   | **≈ 4–8 seconds** |

After restore, open http://localhost:8080 again.  
The visit counter and posts should match the state at the time of the backup.

## Step 6 – Retention test (optional)

Run the backup script several times (or copy existing backup folders and rename them with older timestamps).  
Confirm that only the newest 7 folders remain.

## Step 7 – Failure alert test (optional)

Temporarily break the database credentials in `config/backup.conf` and run:

```bash
./scripts/backup.sh
```

The script should fail, clean up the partial backup, and invoke `alert.sh` (email or webhook + local log entry).

---

**Conclusion:** The solution meets all stated requirements:

1. Sample website + database deployed  
2. Automated backup of files + database with 7-day retention  
3. Backups stored in a separate location  
4. Restore demonstrated with timings  
5. Failure alert + operational runbook provided  

All scripts and configuration are contained in this repository with a clear README and no secrets committed.

---

## Round 6 proof run (6 November 2026)

This section records the proof run that answers the Round 6 review: a real-server backup and restore with `time` output, a prune-to-7 log, and a failed-backup alert arriving, on a new commit.

- Proof workflow: `.github/workflows/backup-proof.yml`, run on a GitHub-hosted Ubuntu VM with the repo's own Docker Compose stack (PHP 8.2 + MySQL 8.0).
- Run: https://github.com/pakmultilinks-dot/pkhosting-backup-demo/actions/runs/42210470035
- Commit: e6a64fa ("Round 6 fix: set scripts executable in CI before the proof runs")
- Conclusion: success, 56 seconds, 6 November 2026 16:28 PKT.
- Full log and artifacts: `docs/proof-run-2/` (run2-full-log.txt, run2-summary.md, backup-proof-logs/).

### RUN 1, timed backup

- Backup pkhosting_backup_20261106_112853, exit 0, real 0m0.351s.
- 3 posts, visit count 4 at backup time; files 4.0K, DB 4.0K.

### RUN 2, timed restore with verification

- Posts after deliberate DELETE of post 3: 2.
- Restore exit 0, real 0m0.381s.
- Restore self-check: posts expected 3, restored 3; visit count expected 4, restored 4. Database check OK, Files check OK.
- Posts after restore: 3. File list check: FILES-MATCH.

### RUN 3, prune to 7

- 10 backups before the new backup (9 seeded old backups plus 1 real backup).
- The backup run found 11 backups and removed the oldest 4 (20261028 to 20261031).
- Backups after prune: 7.

### RUN 4, failed backup, alert must arrive

- Failed-backup exit 1, caused by a wrong DB password in the config.
- Backups still 7, partial backup directory cleaned up.
- backup.log shows: "ALERT: Webhook notification sent" and "ALERT: PKHosting Backup FAILED | mysqldump via docker failed".
- The alert arrived at the webhook inbox https://webhook.site/94c65dfa-9794-48fb-ba84-f3a5d9df912a: exactly 1 POST at 11:28:55, body "*PKHosting Backup FAILED* / mysqldump via docker failed". This was checked by reading the inbox directly, not only from the run log.

### RUN 5, cron line install

- Install command ran, crontab exit 0. Daily line: `15 2 * * * .../scripts/backup.sh`.
- Honest caveat: the runner log does NOT show the crontab -l printout, so the daily schedule is proven only by the install command exiting 0 plus the cron line in the workflow and runbook. The crontab -l output was not captured in this run.

### Note on script permissions

The scripts are stored non-executable (100644) in the repository, including in the original repo, so anyone running them the normal way hits "Permission denied" (this is what failed proof run 1, exit 126). The CI workflow therefore runs `chmod +x scripts/backup.sh scripts/restore.sh scripts/alert.sh` before the proof runs. This is a workaround for the stored permissions, and the maintainer may prefer to commit the scripts as executable instead.
