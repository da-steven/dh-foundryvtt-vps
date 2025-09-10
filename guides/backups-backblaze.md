# Quick Reference

## Configure/update/view settings for rclone:
```bash
rclone config
```
OR
```bash
rclone config show
```

## To see all buckets inside a remote (e.g. `b2-v13`):
```bash
rclone lsd b2-v13:
```

## Show the contents of remote buckets:
```bash
rclone ls b2-v12:dh-foundry-foundry-v12
rclone ls b2-v13:dh-foundry-foundry-v13
```

## To list folders inside:
```bash
rclone lsf b2-v12:dh-foundry-foundry-v12
rclone lsf b2-v13:dh-foundry-foundry-v13
```

## List remotes
```bash
rclone listremotes
```


# Foundry VTT Backups to Backblaze B2 (Using rclone)

This guide walks you through setting up automatic backups of your Foundry VTT **data directory** to Backblaze B2 cloud storage using `rclone`. It includes incremental backup support, file versioning, and restore instructions.

---

## 🧰 What You’ll Need

- A Backblaze B2 account (free or paid)
- A VPS with Foundry installed
- Your `FOUNDRY_DATA_DIR` (e.g. `$HOME/FoundryVTT-Data`)
- Basic terminal access to the VPS

---

## 🚀 Step 1: Create a B2 Bucket

1. Go to [Backblaze B2](https://secure.backblaze.com/b2_buckets.htm)
2. Create a **private bucket**, e.g. `foundry-backups`
3. Enable **Keep all versions** or set **lifecycle rules** (see below)

---

## 🔐 Step 2: Create Application Keys

1. Visit [Application Keys](https://secure.backblaze.com/app_keys.htm)
2. Create a key with access to your bucket
3. Copy:
   - **Key ID** (like `004abc...`)
   - **Application Key**

---

## 🛠️ Step 3: Install rclone

```bash


```

> Or use curl:
```bash
curl https://rclone.org/install.sh | sudo bash
```

---

## 🔧 Step 4: Configure rclone with B2

```bash
rclone config
```

Follow the prompts:

1. `n` for new remote
2. Name it something like `b2`
3. Choose `6` for Backblaze B2
4. Enter:
   - Key ID → your app key ID
   - Application Key → your app key
5. Accept defaults for other options
6. Type `q` to quit when done

You now have `b2:foundry-backups` as a usable remote path.

---

## 🧩 Step 5: Set Bucket Lifecycle Rules (Optional)

Go to your **bucket settings** in the B2 dashboard:

- **Keep prior versions**: enable to support rollback
- **Hide old versions**: enable for storage savings
- Set a retention period:
  - e.g. *keep deleted files for 30 days*

---

## 💾 Step 6: Create Incremental Backup Script

Create a file `~/backup-to-b2.sh`:

```bash
#!/bin/bash

# === Config ===
SOURCE_DIR="$HOME/FoundryVTT-Data"
BUCKET_NAME="dh-foundry-foundry-v12"
DEST_REMOTE="b2:$BUCKET_NAME"
ARCHIVE_REMOTE="b2:$BUCKET_NAME/archive/$(date +%Y-%m-%d)"
LOG_DIR="$HOME/logs"
LOG_FILE="$LOG_DIR/backup-log.txt"

mkdir -p "$LOG_DIR"

# === Log Function ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

# === Start Log Entry ===
log "📦 Starting backup: $SOURCE_DIR → $DEST_REMOTE"
log "🗂️  Archive dir for changed/deleted: $ARCHIVE_REMOTE"
log "📝 Logging to: $LOG_FILE"
log "---------------------------------------------"

# === Safety Checks ===
if ! command -v rclone &>/dev/null; then
  log "❌ rclone is not installed. Aborting."
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  log "❌ Source directory not found: $SOURCE_DIR"
  exit 1
fi

# === Run Backup ===
rclone copy "$SOURCE_DIR" "$DEST_REMOTE" \
  --transfers=8 \
  --checkers=4 \
  --fast-list \
  --log-level INFO \
  --log-file="$LOG_FILE"

STATUS=$?

if [[ $STATUS -eq 0 ]]; then
  log "✅ Backup completed successfully."
else
  log "❌ Backup failed with exit code: $STATUS"
fi

log "============================================="

```

Make it executable:

```bash
chmod +x ~/dh-foundryvtt-vps/tools/backup-to-b2.sh
```

---

## ⏰ Step 7: Schedule Daily Backup (Cron)
To run this every night at 1 AM:

```bash
crontab -e
```
Add:

```bash
0 1 * * * $HOME/dh-foundryvtt-vps/tools/backup-to-b2.sh >> $HOME/logs/cron-backup-run.log 2>&1
```

This lets you see cron-specific errors in a separate cron-backup-run.log, while your script's internal actions go into the regular backup-log.txt.

---

## ♻️ Optional: Manual Backup Anytime

```bash
bash ~/backup-to-b2.sh
```

---

## 🔁 Restore From Backup

### Step 1: List Files

```bash
rclone ls b2:foundry-backups
```

### Step 2: Download Backup

We recommend restoring to a local backup folder first:

```bash
mkdir -p ~/Restores/foundry-latest
rclone copy b2:foundry-backups ~/Restores/foundry-latest --progress
```

Or restore an archive from a specific date:

```bash
rclone copy b2:foundry-backups-archive/2024-05-18 ~/Restores/foundry-2024-05-18
```

### Step 3: Replace Your Live Data (Carefully!)

```bash
# Stop Foundry container first
docker stop foundryvtt-main

# Backup existing data
cp -r $HOME/FoundryVTT-Data $HOME/FoundryVTT-Data-backup

# Restore
rsync -av ~/Restores/foundry-latest/ $HOME/FoundryVTT-Data/
```

Then restart:

```bash
docker start foundryvtt-main
```

---

## 🧠 Best Practices

- 🔁 **Use `rclone sync` with `--backup-dir`** for safe versioning
- 📆 **Schedule daily backups** with cron
- 🕒 **Retain versions for at least 30 days** for rollback
- 📁 **Exclude large temp/log files** if needed with `--exclude`
- 🧪 **Test restores regularly**

---

## 🔗 Resources

- [Backblaze B2 Docs](https://www.backblaze.com/b2/docs/)
- [rclone B2 Docs](https://rclone.org/b2/)
- [FoundryVTT Data Storage Guide](https://foundryvtt.com/article/data-storage/)
- [rclone Filtering](https://rclone.org/filtering/)




With `rclone` + Backblaze B2, you have **flexible logging options**—but they aren’t automatic unless you configure them. Here's a breakdown of the types of logging available, and how to enable them:

---

## ✅ Types of Logging You Can Enable with rclone

### 1. **Standard Output / Errors (Default)**

By default, `rclone` prints messages to your terminal:

* Basic progress, errors, and status
* Temporary unless redirected

You can see:

```bash
Transferred:   	  1.234 GiB / 1.234 GiB, 100%
Errors:                 0
Checks:              5431 / 5431, 100%
Transferred:         123 / 123, 100%
Elapsed time:        2m35s
```

---

### 2. **Persistent Log File**

You can **log to a file** using `--log-file`:

```bash
rclone sync /source b2:bucket --log-file="$HOME/backup-log.txt"
```

Add this to your cron script to keep daily logs.

---

### 3. **Log Level Control**

Control **verbosity** with `--log-level`:

| Level    | Description                         |
| -------- | ----------------------------------- |
| `DEBUG`  | Most detailed (for troubleshooting) |
| `INFO`   | Normal operation messages           |
| `NOTICE` | Warnings & important notices        |
| `ERROR`  | Only errors                         |

**Example:**

```bash
rclone sync /source b2:bucket \
  --log-level INFO \
  --log-file "$HOME/rclone-backup.log"
```

---

### 4. **Log Rotation / Retention (Manual)**

`rclone` does **not** automatically rotate logs. You should:

* Use a log folder like `~/logs/rclone/`
* Set up a logrotate rule
* Or include logic in your cron script to delete old logs (e.g. keep 7 days)

**Example cron cleanup:**

```bash
find ~/logs/rclone/ -type f -mtime +7 -delete
```

---

## 🔍 Backblaze B2-Side Logging?

Backblaze does **not provide per-file logs** but does:

* Track **API usage and billing** in your account dashboard
* Show **bucket file history** (if versioning is enabled)

There is **no per-upload event log** unless you enable and track it with `rclone`.

---

## 💡 Recommendation for Daily Use

For a clean backup routine:

```bash
#!/bin/bash

LOG_DIR="$HOME/logs/rclone"
mkdir -p "$LOG_DIR"

DATE=$(date +%F)
LOG_FILE="$LOG_DIR/b2-backup-$DATE.log"

rclone sync "$HOME/FoundryVTT-Data" "b2:foundry-backups" \
  --backup-dir "b2:foundry-backups-archive/$DATE" \
  --b2-hard-delete \
  --log-level INFO \
  --log-file "$LOG_FILE" \
  --progress
```

Then use cron to clean logs:

```bash
0 4 * * * bash ~/backup-to-b2.sh
0 5 * * * find ~/logs/rclone -type f -mtime +14 -delete
```

---

Let me know if you want help setting up that script with full logging and rotation.


--- 
Great question!

### 🟡 Where does the name `b2:foundry-backups` come from?

It comes from your `rclone` **remote configuration**. Specifically:

* `b2` = the **name of the remote** (defined in your `rclone config`)
* `foundry-backups` = the **name of the bucket** inside that remote

So:

```bash
rclone ls b2:foundry-backups
```

Means: “List all files in the `foundry-backups` bucket on the `b2` remote.”

---

### 🟢 How to see all defined remotes

Run:

```bash
rclone listremotes
```

This will output something like:

```
b2:
dropbox:
gdrive:
```

These are all the **configured remotes** on your system (from `~/.config/rclone/rclone.conf`).

---

### 🟢 How to browse all contents of a remote

You can use:

```bash
rclone lsd b2:
```

This lists all **buckets** under your `b2` remote.

Then:

```bash
rclone ls b2:your-bucket-name
```

Will list files in that bucket.

---

### 🔍 Tip: Inspect remotes with config

To see full details (keys, endpoints, etc.):

```bash
rclone config show
```

Or interactively:

```bash
rclone config
```

---

Would you like a summary Markdown doc of these `rclone` basics for your project?

# Rclone Quick Reference

This guide explains how to use `rclone` to interact with your cloud storage (e.g., Backblaze B2).

---

## 📦 Remotes and Buckets

- **Remote**: A named connection in `rclone` (e.g., `b2:`).
- **Bucket**: A storage container inside the remote (e.g., `foundry-backups`).

The full path format is:

```
remote:bucket-name/path/to/files
```

Example:

```bash
rclone ls b2:foundry-backups
```

---

## 🔍 View Configured Remotes

To list all remotes defined on your system:

```bash
rclone listremotes
```

Example output:

```
b2:
dropbox:
gdrive:
```

---

## 📂 List Buckets in a Remote

To see all buckets inside a remote (e.g. `b2`):

```bash
rclone lsd b2:
```

To list contents of a specific bucket:

```bash
rclone ls b2:foundry-backups
```

To list folders inside:

```bash
rclone lsf b2:foundry-backups/
```

---

## ⚙️ Inspect Remote Configuration

To see the full config file (credentials included):

```bash
rclone config show
```

To edit or inspect remotes interactively:

```bash
rclone config
```

---

## 🧪 Test a Backup Connection

Verify that your credentials are valid and the remote is accessible:

```bash
rclone about b2:foundry-backups
```

Or test transfer:

```bash
rclone copy ~/some-folder b2:foundry-backups/test-run --dry-run
```

---

## 🔒 Config File Location

Your remotes are stored in:

```
~/.config/rclone/rclone.conf
```

Keep this file secure!

---

## 🧼 Cleanup

To delete a file or folder from the remote:

```bash
rclone delete b2:foundry-backups/path/to/file
```

To delete a whole folder:

```bash
rclone purge b2:foundry-backups/old-folder
```

> ⚠️ Be cautious with `purge`—it deletes everything under the path.

---

## 🔗 Resources

- [Rclone Website](https://rclone.org/)
- [Rclone Backblaze B2 Guide](https://rclone.org/b2/)
