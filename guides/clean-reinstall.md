If you want to **reset your VPS and reinstall Foundry**, while preserving your **Cloudflare tunnel** and keeping your **domain routing intact**, here’s a clean and reliable step-by-step plan:

---

## 🧹 VPS Reset + Foundry Reinstall Guide

### ✅ **Assumptions**

* You’re using Docker to run Foundry.
* Your Foundry `data` folder is at: `~/FoundryVTT-Data/`
* The Cloudflare tunnel is managed from the dashboard and already linked to your domain (e.g., `foundry.example.com`) and port (e.g., `30000`).
* You’re keeping the **same VPS**.

---

### 🔻 Step 1: Stop and Remove Docker Container

```bash
docker ps -a  # Identify your container ID 
docker ps -a --format '{{.Names}}' # Show container names c(e.g., foundryvtt-main)
docker stop foundryvtt-main
docker rm foundryvtt-main
```

Or use your tag name if different (e.g., `foundryvtt-dev`, `foundryvtt-test`, etc.).

---

### 🔻 Step 2: Delete Old Installation Files

If you want to fully remove the previous install:

```bash
sudo rm -rf /opt/foundry-*  # or your INSTALL_DIR base if it’s in a different location
sudo rm -rf /opt/FoundryVTT/*
```

This deletes the app but **not your world data**.

---

### ✅ Step 3: (Optional) Back Up or Reset Your Data Folder

* If you want to **keep your data**:

```bash
# Backup example
cp -r ~/FoundryVTT-Data ~/FoundryVTT-Data-backup
```

* If you want to **reset**:

```bash
rm -rf ~/FoundryVTT-Data/*
```

---

### 🔁 Step 4: Re-run the Foundry Install Script

Run your updated script:

```bash
bash foundry-vtt-setup.sh
```

* If prompted for a tag, enter the same one (or leave blank if optional).
* When asked for the **Foundry download URL**, use your timed Node.js link from the Foundry website.
* Use the **same port** as before (default is `30000`).

---

### 🔄 Step 5: Ensure the Cloudflare Tunnel Still Works

As long as:

* The **Cloudflare tunnel** was created via the dashboard
* The **tunnel routes traffic to the same port** (`localhost:30000`)
* The **cloudflared service is still running**

...your tunnel should continue working **without needing to update or reinstall cloudflared**.

Check:

```bash
sudo systemctl status cloudflared
```

If it’s not running:

```bash
sudo systemctl start cloudflared
```

Or run it manually:

```bash
cloudflared tunnel run --token <your-token>
```

---

## ✅ TL;DR – Minimal Reset

If you just want to reinstall Foundry and keep your tunnel:

```bash
docker stop foundryvtt-main
docker rm foundryvtt-main
sudo rm -rf /opt/foundry-main
bash foundry-vtt-setup.sh
```

Your Cloudflare tunnel **does not need to be reinstalled** as long as:

* It's set up via the dashboard
* It points to the same port
* `cloudflared` is running

---

Let me know if you want a "reset" shell script or a wrapper that automates the cleanup + reinstall.
