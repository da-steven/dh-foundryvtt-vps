# Foundry VTT - Cron Backup Configuration Guide

## 🤖 **Cron-Ready Scripts Status**

### ✅ **SUITABLE FOR CRON (Fully Automated):**
- `backup-local-rsync.sh` - Local incremental backups
- `backup-local-restic.sh` - Local encrypted backups  
- `backup-remote-b2-rclone.sh` - Remote cloud backups
- `backup-local-restic-prune.sh` - Cleanup old snapshots

### ❌ **NOT SUITABLE FOR CRON (Interactive):**
- `backup-local-restic-restore.sh` - Requires user confirmation
- `backup-local-rsync-restore.sh` - Requires user confirmation
- `restic-setup.sh` - One-time setup, needs user input

---

## 📅 **Recommended Cron Schedule**

### **Option 1: Conservative (Low Resource Usage)**
```bash
# Edit crontab: crontab -e

# Set PATH for cron
PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

# Daily local rsync backup at 2:00 AM
0 2 * * * cd /home/ubuntu/dh-foundryvtt-vps && ./tools/backup-local-rsync.sh >> /var/log/foundry-cron.log 2>&1

# Weekly restic backup on Sunday at 3:00 AM  
0 3 * * 0 cd /home/ubuntu/dh-foundryvtt-vps && ./tools/backup-local-restic.sh >> /var/log/foundry-cron.log 2>&1

# Monthly restic prune on 1st day at 4:00 AM
0 4 1 * * cd /home/ubuntu/dh-foundryvtt-vps && ./tools/backup-local-restic-prune.sh >> /var/log/foundry-cron.log 2>&1

# Weekly remote backup on Saturday at 5:00 AM
0 5 * * 6 cd /home/ubuntu/dh-foundryvtt-vps && ./tools/backup-remote-b2-rclone.sh >> /var/log/foundry-cron.log 2>&1
```

### **Option 2: Comprehensive (Maximum Protection)**
```bash
# Edit crontab: crontab -e

# Set PATH for cron
PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

# Daily local rsync backup at 2:00 AM
0 2 * * * cd /home/ubuntu/dh-foundryvtt-vps && ./tools/backup-local-rsync.sh >> /var/log/foundry-cron.log 2>&1

# Daily restic backup at 2:30 AM
30 2 * * * cd /home/ubuntu/dh-foundryvtt-vps && ./tools/backup-local-restic.sh >> /var/log/foundry-cron.log 2>&1

# Weekly restic prune on Sunday at 3:00 AM
0 3 * * 0 cd /home/ubuntu/dh-foundryvtt-vps && ./tools/backup-local-restic-prune.sh >> /var/log/foundry-cron.log 2>&1

# Daily remote backup at 4:00 AM
0 4 * * * cd /home/ubuntu/dh-foundryvtt-vps && ./tools/backup-remote-b2-rclone.sh >> /var/log/foundry-cron.log 2>&1

# Weekly log cleanup on Monday at 5:00 AM
0 5 * * 1 find /home/ubuntu/logs -name "*.log" -mtime +30 -delete
```

### **Option 3: Minimal (Basic Protection)**
```bash
# Edit crontab: crontab -e

# Set PATH for cron
PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

# Daily local backup at 2:00 AM (choose ONE backup method)
0 2 * * * cd /home/ubuntu/dh-foundryvtt-vps && ./tools/backup-local-rsync.sh >> /var/log/foundry-cron.log 2>&1

# Weekly remote backup on Sunday at 3:00 AM
0 3 * * 0 cd /home/ubuntu/dh-foundryvtt-vps && ./tools/backup-remote-b2-rclone.sh >> /var/log/foundry-cron.log 2>&1
```

---

## 🔧 **Cron Setup Instructions**

### **1. Edit Crontab**
```bash
crontab -e
```

### **2. Add Your Chosen Schedule**
Copy one of the options above into your crontab.

### **3. Verify Cron Job**
```bash
# List current cron jobs
crontab -l

# Check cron service status
sudo systemctl status cron
```

### **4. Monitor Logs**
```bash
# Watch main cron log
tail -f /var/log/foundry-cron.log

# Watch individual backup logs
tail -f /home/ubuntu/FoundryVTT-Backups/logs/*.log
```

---

## 📊 **Monitoring & Maintenance**

### **Check Backup Status**
```bash
# Validate configuration
bash tools/validate-config.sh

# List available backups
bash tools/backup-local-rsync-restore.sh --list
bash tools/backup-local-restic-restore.sh --list

# Check disk usage
df -h
du -sh /home/ubuntu/FoundryVTT-Backups/
```

### **Log Rotation Setup**
Create `/etc/logrotate.d/foundry-backups`:
```
/var/log/foundry-cron.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 ubuntu ubuntu
}

/home/ubuntu/FoundryVTT-Backups/logs/*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 0644 ubuntu ubuntu
}
```

### **Failure Notifications (Optional)**
Add email notifications for backup failures:
```bash
# Install mailutils
sudo apt install mailutils

# Modify cron entries to send email on failure:
0 2 * * * cd /home/ubuntu/dh-foundryvtt-vps && ./tools/backup-local-rsync.sh >> /var/log/foundry-cron.log 2>&1 || echo "Rsync backup failed" | mail -s "Foundry Backup Failed" your-email@example.com
```

---

## ⚠️ **Important Notes**

### **Timing Considerations:**
- **Stagger backup times** to avoid resource conflicts
- **Run during low-usage hours** (typically 2-5 AM)
- **Avoid running during Foundry game sessions**

### **Resource Usage:**
- **Rsync**: Moderate CPU, high I/O during backup
- **Restic**: Higher CPU (compression/encryption), moderate I/O
- **Remote uploads**: Network bandwidth intensive

### **Backup Verification:**
- **Test restores monthly** to ensure backups are working
- **Monitor disk space** to prevent backup failures
- **Check logs regularly** for any issues

### **Security:**
- **Cron runs as your user**, not root
- **Password files have 600 permissions**
- **Scripts use absolute paths** to avoid PATH issues

---

## 🧪 **Testing Your Cron Setup**

### **1. Test Individual Scripts**
```bash
# Test each backup script manually first
bash tools/backup-local-rsync.sh
bash tools/backup-local-restic.sh
bash tools/backup-remote-b2-rclone.sh
```

### **2. Test Cron Environment**
```bash
# Create a test cron job that runs in 2 minutes
# Add to crontab: * * * * * cd /home/ubuntu/dh-foundryvtt-vps && ./tools/validate-config.sh >> /tmp/cron-test.log 2>&1

# Check results
cat /tmp/cron-test.log
```

### **3. Monitor First Runs**
```bash
# Watch logs during first automated run
tail -f /var/log/foundry-cron.log
tail -f /home/ubuntu/FoundryVTT-Backups/logs/*.log
```

---

## 🎯 **Success Indicators**

Your cron backup setup is working correctly when you see:
- ✅ Regular entries in `/var/log/foundry-cron.log`
- ✅ New backup files appearing daily/weekly
- ✅ No error messages in backup logs
- ✅ Disk space usage gradually increasing (but not filling up)
- ✅ Remote backups appearing in your cloud storage

Remember: **Test your restore procedures regularly!** Backups are only valuable if you can restore from them.