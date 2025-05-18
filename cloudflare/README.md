## Cloudflare Tunnel Setup Notes

### Reinstalling or Encountering Errors?

If the setup script reports:
- **"Tunnel already exists"**
- **"Missing credentials for tunnel"**
- **"Port XXXX already in use"**

You may need to clean up stale tunnels or free the local port.

#### 🧹 Clean Up a Tunnel
If your tunnel exists remotely but has no working config:

1. **List tunnels**:
   ```bash
   cloudflared tunnel list
````

2. **Clean up stale connections**:

   ```bash
   cloudflared tunnel cleanup <uuid>
   ```

3. **Delete tunnel**:

   ```bash
   cloudflared tunnel delete <name>
   ```

Or run our script:

```bash
./cloudflare/tools/cloudflare-tunnel-teardown.sh
```

#### 🛑 Port Already in Use?

Ensure:

* No other Foundry instance or docker container is running
* You free the port using `docker stop` or the teardown script

---

