# Backup proof run 2 - verified results
- Run: https://github.com/pakmultilinks-dot/pkhosting-backup-demo/actions/runs/42210470035
- Commit: e6a64fa (Round 6 fix: set scripts executable in CI before the proof runs)
- Conclusion: success, 56 seconds, 6 Nov 2026 16:28 PKT
- Webhook inbox: https://webhook.site/94c65dfa-9794-48fb-ba84-f3a5d9df912a (1 POST arrived, verified independently)

## RUN 1 - timed backup
- Backup pkhosting_backup_20261106_112853, exit 0, real 0m0.351s
- 3 posts, visit count 4 at backup time; files 4.0K, DB 4.0K

## RUN 2 - timed restore with verification
- Posts after deliberate DELETE: 2
- Restore exit 0, real 0m0.381s
- Restore self-check: posts expected=3 restored=3, visit count expected=4 restored=4
- Database check OK, Files check OK
- Posts after restore: 3, visit count after restore: 4, FILES-MATCH

## RUN 3 - prune to 7
- Backups before the new backup: 10 (9 seeded old + 1 real)
- Prune found 11, removed oldest 4 (20261028 to 20261031)
- Backups after prune: 7

## RUN 4 - failed backup, alert must arrive
- Failed-backup exit: 1 (wrong DB password)
- Backups still 7, partial dir cleaned
- backup.log alert lines: "ALERT: Webhook notification sent" and "ALERT: PKHosting Backup FAILED | mysqldump via docker failed"
- Webhook inbox: total 1, POST at 11:28:55, body "*PKHosting Backup FAILED* / mysqldump via docker failed"

## RUN 5 - cron line install
- crontab exit 0, daily line installed: 15 2 * * * .../scripts/backup.sh
