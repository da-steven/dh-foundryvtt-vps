# Foundry Backups
- Backing up your Foundry VTT data is essential. 
- A good backup strategy should combine local (on your VPS) and remote backups.
- There are multiple methods you can use for backups. Use what you prefer.
- This repo includes scripts for the following:
  - Local incremental backups using `rsync`
  - Remote backups usig `rclone` and **Backbloze B2**

## Local Incremental Backups

### Make a manual local backup:

```bash 
bash backup-to-local.sh
```

### Setup regular automatic local backups:

### Restore local backup

```bash
bash toos/restore-local-backup.sh
```
**Usage**:
```bash
# List available backups
bash tools/restore-backup.sh --list

# Dry-run the latest restore (preview)
bash tools/restore-backup.sh --dry-run

# Restore a specific backup
bash tools/restore-backup.sh --from=2025-05-17

# Restore a specific backup with dry-run
bash tools/restore-backup.sh --from=2025-05-17 --dry-run
```



WIP CONTENT BELOW
---

## 🔒 Backup Strategy Overview

Foundry data is all stored in the **data directory**, e.g. `/opt/foundry/main/`. Backing up that folder regularly is essential.

Your backup plan should ideally include:

* 🔁 **Automated backups** (daily or weekly)
* 💾 **Manual backup trigger** (before updates)
* 🌩️ **Remote offsite storage** (e.g. Backblaze B2, S3, Dropbox)
* 📦 **Local rotation** (keep last 3–7 backups)

---

## ✅ Local Backup (Baseline)

Create a simple compressed copy:

```bash
DATE=$(date +"%Y-%m-%d")
tar -czf /opt/foundry/backups/foundry-backup-$DATE.tar.gz /opt/foundry/main
```

You can wrap this in a cron job to run it daily or weekly.

---

## ☁️ Option 1: Backblaze B2

### 🔧 Setup Steps

1. **Create a B2 Bucket**

   * Go to [https://www.backblaze.com/](https://www.backblaze.com/)
   * Create a bucket, get your **Key ID** and **Application Key**

2. **Install `rclone` on your VPS**

   ```bash
   sudo apt install rclone
   ```

3. **Configure Backblaze with `rclone`**

   ```bash
   rclone config
   ```

   * Name: `foundry-b2`
   * Type: `b2`
   * Use your Key ID / App Key when prompted

4. **Backup to B2 with a command like:**

   ```bash
   rclone copy /opt/foundry/backups foundry-b2:your-bucket-name/foundry-backups --progress
   ```

5. **Automate with cron (daily backup + upload):**

   ```bash
   2 3 * * * /usr/bin/tar -czf /opt/foundry/backups/backup-$(date +\%F).tar.gz /opt/foundry/main && /usr/bin/rclone copy /opt/foundry/backups foundry-b2:your-bucket-name/foundry-backups
   ```

---

## 🛠️ Option 2: S3-Compatible Storage (AWS, Wasabi, etc.)

You can use `rclone` or AWS CLI. Configure with credentials and sync like:

```bash
rclone sync /opt/foundry/backups s3:your-bucket-name
```

Wasabi is a cost-effective alternative if you want S3 compatibility but cheaper pricing.

---

## 🔄 Option 3: rsync to Another Server

If you manage a second VPS or NAS:

```bash
rsync -avz /opt/foundry/main/ user@backup-server:/backup/foundry/
```

Combine with SSH keys for passwordless automation.

---

## ✋ Manual Backup Script

Create a script like `manual-backup.sh`:

```bash
#!/bin/bash
DATE=$(date +%F-%H%M)
DEST="/opt/foundry/backups/foundry-$DATE.tar.gz"
tar -czf "$DEST" /opt/foundry/main
echo "✅ Manual backup created at: $DEST"
```

---

## 📅 Automatic Backup (Cron)

To backup daily at 3:05 AM:

```bash
5 3 * * * /opt/foundry/scripts/manual-backup.sh
```

To rotate old backups, add a `find` command:

```bash
find /opt/foundry/backups -name "*.tar.gz" -mtime +7 -delete
```

---

## 🔐 Optional: Encrypt Backups

Use GPG to encrypt backups before remote upload:

```bash
gpg -c /opt/foundry/backups/foundry-2024-05-18.tar.gz
```

---

## 🧪 Restore From Backup

```bash
tar -xzf foundry-backup-2024-05-18.tar.gz -C /opt/foundry/main --strip-components=1
```

---

## Summary: Best Practice

| Feature            | Recommendation                         |
| ------------------ | -------------------------------------- |
| Local Backup       | Daily `tar.gz` with rotation           |
| Offsite Storage    | Backblaze B2 via `rclone`              |
| Trigger on Update  | Use `manual-backup.sh` before upgrades |
| Restore Simplicity | Keep `tar.gz` structure clean          |
| Automation         | Use `cron` or `systemd` timer          |

Would you like a working `backup.sh` and `restore.sh` script pair next?
