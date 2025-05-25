



## Cron Setup

🕒 Example Cron Entry

### Automate Restic Backups
```bash
# Runs daily at 2am

```

### Automate Restic Pruning
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


Yes, after running the setup script, **you can simplify your `restic` commands** by using the environment variable `RESTIC_REPOSITORY_FILE` (or `RESTIC_REPOSITORY`) and `RESTIC_PASSWORD_FILE`.

---

### ✅ After Setup

Your `~/.bashrc` or `.bash_profile` will automatically have:

```bash
export RESTIC_REPOSITORY_FILE="$HOME/FoundryVTT-Backups/restic-repo/.repo"
export RESTIC_PASSWORD_FILE="$HOME/.restic-password.txt"
```

And `FoundryVTT-Backups/restic-repo/.repo` will contain the actual repo path (e.g., `/home/ubuntu/FoundryVTT-Backups/restic-repo`).

These are set automatically by the `restic-setup.sh` script.

---

### ✅ You can now run:

```bash
restic snapshots
```

Or:

```bash
restic ls latest
```

Or to see metadata for a specific snapshot:

```bash
restic snapshots --json | jq .
```

And all commands will automatically use:

* the path defined in `.repo` (via `RESTIC_REPOSITORY_FILE`)
* the password stored in `~/.restic-password.txt`

---

### ✅ Summary

| Command                                           | What it does                              |
| ------------------------------------------------- | ----------------------------------------- |
| `restic snapshots`                                | List available snapshots                  |
| `restic ls latest`                                | Show contents of the most recent snapshot |
| `restic restore <snapshot-id> --target /some/dir` | Restore snapshot to target                |
| `restic forget --prune ...`                       | Apply retention and prune                 |
| `restic check`                                    | Verify repo integrity                     |

You don’t need to provide `--repo` or `--password-file` again because they are read from the environment.

Let me know if you'd like a `list-snapshots.sh` helper.
