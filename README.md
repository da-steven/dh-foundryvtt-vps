# Foundry VTT - VPS Configuration Script

A simple script and setup guide to install and run [Foundry Virtual Tabletop](https://foundryvtt.com/) on a VPS with secure HTTPS access via [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/).

---

## ✅ Requirements

Before you begin, you will need:

1. A **Foundry VTT license**
2. A **Debian-based VPS** (e.g. Oracle Free Tier, DigitalOcean, etc.)
3. A **Cloudflare account** (free plan is fine)
4. A **custom domain name** (managed by Cloudflare DNS)

---

## 🚀 Install Foundry

### 1. Get a Timed Download Link

1. Go to [FoundryVTT.com](https://foundryvtt.com/) and log in.
2. Visit the **Download Software** page.
3. **Stay on that page** — you’ll return to generate a **timed download URL** for the **Node.js version** later.

---

### 2. Run the Foundry Setup Script

1. SSH into your VPS:

```bash
ssh ubuntu@<your-server-ip>
```

2. Clone your project and run the setup script:

```bash
bash foundry-vtt-setup.sh
```

3. Follow the prompts:
   - You’ll be asked to name your instance (optional)
   - Paste the **timed URL** when prompted
   - The script will install Docker, unzip, and Foundry VTT

---

## 🌐 Set Up a Cloudflare Tunnel

You will configure HTTPS access using Cloudflare's **Zero Trust dashboard**, which lets you bypass the need for NGINX or Let's Encrypt setup.

### 1. Log into Cloudflare

Go to [one.dash.cloudflare.com](https://one.dash.cloudflare.com/) and follow the instructions to set up a new **Tunnel**.

### 2. Follow the Cloudflare Guide

Use this official guide to create and connect the tunnel:
👉 [Cloudflare Tunnel Setup Guide](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/)

Steps you’ll complete:

- Add a tunnel name
- Install `cloudflared` on your VPS
- Run a `cloudflared` command that:
  - Creates the tunnel
  - Binds it to your domain

---

## 🛠️ Example Cloudflared Setup (Debian)

Install Cloudflare’s official tunnel client:

### 1. Add Cloudflare’s GPG key

```bash
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
```

### 2. Add Cloudflare’s apt repository

```bash
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
```

### 3. Install `cloudflared`

```bash
sudo apt update
sudo apt install cloudflared
```

### 4. Launch Your Tunnel

**Option 1: Auto-start on boot**

```bash
sudo cloudflared service install <YOUR-TOKEN>
```

**Option 2: Manual (current session only)**

```bash
cloudflared tunnel run --token <YOUR-TOKEN>
```

---

## 🔧 Troubleshooting

### General Linux Tips

| Task | Command |
|------|---------|
| Reboot the server | `sudo reboot` |
| Check system load | `uptime` or `top` |
| View disk usage | `df -h` |
| Update packages | `sudo apt update && sudo apt upgrade` |

### Docker Commands

| Task | Command |
|------|---------|
| List all containers | `docker ps -a` |
| Stop a container | `docker stop <container>` |
| Start a container | `docker start <container>` |
| Restart a container | `docker restart <container>` |
| View logs | `docker logs <container>` |

### Common Problems

- **Can't access Foundry in the browser?**
  - Make sure the `cloudflared` tunnel is running
  - Confirm your domain resolves correctly (check [whatsmydns.net](https://www.whatsmydns.net/#A/))
  - Try restarting your Docker container

- **Port 30000 already in use?**
  - Run: `lsof -i :30000` to see what’s using it
  - You may need to stop an old container: `docker ps -a`, then `docker stop <name>`

---

## 📚 Resources

- [FoundryVTT](https://foundryvtt.com/)
- [FoundryVTT Discord](https://discord.gg/foundryvtt)
- [Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Cloudflare DNS](https://developers.cloudflare.com/dns/)
- [Cloudflared (Debian Package)](https://pkg.cloudflare.com/)