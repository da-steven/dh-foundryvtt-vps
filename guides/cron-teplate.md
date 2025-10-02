# Cron Template
The purpose of this file is to archive my cron setup version control and recovery.

## Crontab contents

```bash
# === Foundry VTT Automated Backups ===
PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin
HOME=/home/ubuntu

# Take a snapshot of modules and systems (Tuesdays @ 1:00 AM)
# 0 1 * * 2 bash $HOME/dh-foundryvtt-vps/tools/foundry-snapshot-metadata.sh >> $HOME/logs/foundry-snapshot.log 2>&1
0 1 * * 2 bash $HOME/dh-foundryvtt-vps/tools/foundry-snapshot-metadata.sh >> $HOME/FoundryVTT-Backups/logs/foundry-snapshot.log 2>&1

# Create $HOME/logs and delete any logs older than 30 days (Daily @ 2:00 AM)
0 2 * * * mkdir -p "$HOME/logs" && find "$HOME/logs" -type f -mtime +30 -delete

# Create $HOME/FoundryVTT-Backups/logs and delete any logs older than 90 days (Daily @ 2:30 AM)
30 2 * * * mkdir -p "$HOME/FoundryVTT-Backups/logs" && find "$HOME/FoundryVTT-Backups/logs" -type f -mtime +90 -delete

# Local backup - Restic (Daily @ 3:00 AM)
# 0 3 * * * bash $HOME/dh-foundryvtt-vps/tools/backup-local-restic.sh >> $HOME/logs/restic-backup.log 2>&1
0 3 * * * bash $HOME/dh-foundryvtt-vps/tools/backup-local-restic.sh >> $HOME/FoundryVTT-Backups/logs/restic-backup.log 2>&1

# Local prune - Restic (Saturdays @ 3:30 AM)
# 30 3 * * 6 bash $HOME/dh-foundryvtt-vps/tools/backup-local-restic-prune.sh >> $HOME/logs/restic-prune.log 2>&1
30 3 * * 6 bash $HOME/dh-foundryvtt-vps/tools/backup-local-restic-prune.sh >> $HOME/FoundryVTT-Backups/logs/restic-prune.log 2>&1

# B2 remote backup of Foundry (Weekly on Sundays @ 4:00 AM)
# 0 4 * * 7 bash $HOME/dh-foundryvtt-vps/tools/backup-remote-b2-rclone.sh >> $HOME/logs/b2-backup.log 2>&1
0 4 * * 7 bash $HOME/dh-foundryvtt-vps/tools/backup-remote-b2-rclone.sh >> $HOME/FoundryVTT-Backups/logs/b2-backup.log 2>&1

# B2 remote backup of shared-assets (Weekly on Sundays @ 5:00 AM)
# 0 5 * * 7 bash $HOME/dh-foundryvtt-vps/tools/backup-remote-b2-rclone-assets.sh >> $HOME/logs/b2-backup.log 2>&1
0 5 * * 7 bash $HOME/dh-foundryvtt-vps/tools/backup-remote-b2-rclone-assets.sh >> $HOME/FoundryVTT-Backups/logs/b2-backup.log 2>&1
# Alt log location: $HOME/logs/b2-assets-backup.log 2>&1

# B2 remote backup - 4:00 AM daily
# 0 4 * * * bash /home/ubuntu/dh-foundryvtt-vps/tools/backup-remote-b2-rclone.sh >> $HOME/logs/b2-backup.log 2>&1
```