# PKHosting – Automated Backup & Restore Demo

**Task:** Automated Backup & Restore for a Sample Website  
**Brand:** PKHosting.com (TechAbout)  
**Source:** Zeshan request ZR-26-00753 – Task 17 (DevOps Engineer)

This repository demonstrates a complete, production-style backup and restore solution that can be used as a reference for PKHosting customers or internal operations.

## What this project does

1. Deploys a sample website + MySQL database using Docker Compose
2. Runs a daily backup script that:
   - Archives website files
   - Dumps the MySQL database
   - Stores everything in a **separate** location
   - Keeps only the **last 7** successful backups (automatic rotation)
3. Provides a restore script that can bring a fresh environment back from any backup
4. Sends an alert (email or webhook) when a backup fails
5. Includes a short operational runbook

## Requirements

- Docker & Docker Compose
- bash
- `tar`, `gzip`, `mysqldump` (or Docker – preferred)
- Optional: `mail` / `sendmail` or a webhook endpoint for alerts

## Quick Start

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd pkhosting-backup-demo

# 2. Create config from example
cp config/backup.conf.example config/backup.conf
# Edit config/backup.conf if needed (paths, credentials, alert email)

# 3. Start the sample website + database
docker compose up -d

# 4. Wait a few seconds for MySQL to become healthy, then open:
#    http://localhost:8080

# 5. Make the scripts executable
chmod +x scripts/*.sh

# 6. Run a backup
./scripts/backup.sh

# 7. List backups and restore (interactive)
./scripts/restore.sh
```

## Project Structure

```
pkhosting-backup-demo/
├── docker-compose.yml          # Sample site (PHP + MySQL)
├── sample-site/                # Demo website files + init.sql
├── scripts/
│   ├── backup.sh               # Daily backup + rotation
│   ├── restore.sh              # Interactive / non-interactive restore
│   └── alert.sh                # Failure notification
├── config/
│   └── backup.conf.example     # Configuration template
├── backups/                    # Backup storage (git-ignored)
├── docs/
│   └── walkthrough.md          # Step-by-step demonstration
├── runbook.md                  # Operational runbook
├── README.md
└── .gitignore
```

## Backup Behaviour

| Feature                    | Implementation                                      |
|---------------------------|-----------------------------------------------------|
| Files                     | `tar.gz` of the site directory                      |
| Database                  | `mysqldump` (via Docker preferred) + gzip           |
| Storage location          | Separate folder (`backups/`) – can be changed to another disk, NFS, or cloud mount |
| Retention                 | Keeps only the newest 7 backups                     |
| Schedule                  | Designed for daily cron (example below)             |
| Failure alert             | Email and/or webhook via `alert.sh`                 |

### Recommended Cron Entry

```cron
# Run every day at 02:15
15 2 * * * /path/to/pkhosting-backup-demo/scripts/backup.sh >> /path/to/pkhosting-backup-demo/backups/cron.log 2>&1
```

## Restore Demonstration

See `docs/walkthrough.md` for a timed restore example.

Typical restore time on a small sample site (measured during testing):

- File extract: < 1 second
- Database recreate + import: 2–5 seconds
- **Total restore time: usually under 10 seconds** for this demo size

## Security Notes

- `config/backup.conf` is git-ignored – never commit real credentials
- Database passwords shown in the example are for local demo only
- In production:
  - Use strong passwords / secrets management
  - Store backups on a different server or object storage (S3, Backblaze, etc.)
  - Restrict access to the backup directory
  - Consider encrypting backups at rest

## Limitations

- Designed as a clear, understandable demo – not a full enterprise backup platform
- Single-server focus (no multi-region replication)
- Alerting is basic (email or simple webhook)
- Does not currently support incremental/differential backups
- Assumes the operator has shell access to the server

## Live URL (when running)

Once `docker compose up -d` is running:

- Sample website: **http://localhost:8080**

(For a public demonstration you can expose the port via a tunnel or deploy the same stack on any VPS.)

## How to submit this task

1. Push this repository to GitHub (real commit history)
2. Make sure `config/backup.conf` is **not** committed
3. Include the GitHub repository URL
4. Optionally include a short screen recording or the walkthrough notes showing backup + restore timings

---

**Author:** Prepared for PKHosting / TechAbout DevOps task  
**Date:** November 2026

