# Troubleshooting

## Permission Error on Updates
```bash
Error: You do not have permission to write files in your Foundry Virtual Tabletop installation location. You may need to run the application as an Administrator to perform an update.
```

### Description
Our install script should assign the correct permissions inside the Docker container based on the current user ID. However, if there is an error, you can do the following to diagnose and fix.

### Step 1: Check current permissions
Note: Adjust `foundryvtt-v13` to match current version

```bash
# Check what user the container is running as
docker exec foundryvtt-v13 whoami

# Check ownership of /foundry directory
docker exec foundryvtt-v13 ls -la /foundry | head -10

# Check if foundry can write to /foundry
docker exec foundryvtt-v13 touch /foundry/test-write.txt
docker exec foundryvtt-v13 rm /foundry/test-write.txt
```
NOTE: If the `touch` command fails, that's our problem.

### Step 2: Quick Fix
Do the following if the `touch` command fails. 
```bash
# Fix ownership as root
docker exec -u root foundryvtt-v13 chown -R foundry:foundry /foundry

# Verify it worked
docker exec foundryvtt-v13 touch /foundry/test-write.txt && echo "✅ Write permissions OK"
```