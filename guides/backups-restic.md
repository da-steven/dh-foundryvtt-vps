



## Cron Setup

🕒 Example Cron Entry

```bash
# Runs every Sunday at 3am.
0 3 * * 0 /home/ubuntu/tools/backup-local-restic-prune.sh
```

## Restoring Backups

### Restore latest snapshot (default):

```bash
bash tools/backup-local-restic-restore.sh
```

### Restore specific snapshot:

```bash
bash tools/backup-local-restic-restore.sh --id=12345678
```