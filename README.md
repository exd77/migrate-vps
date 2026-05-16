# migrate-vps

A bash tool to move directories between Linux servers in one shot. Rsync transfer, MD5 integrity check, and auto-install for Node/Python projects on the destination side.

Useful when you're hopping VPS providers and don't want to babysit `scp`, then re-run `npm install` and `pip install` by hand.

## Quickstart

```bash
# Interactive mode — it'll ask you everything
bash migrate-server.sh

# Or pass flags directly
bash migrate-server.sh \
  -d /root/bot \
  -d /root/discord \
  -u ubuntu \
  -i 13.236.147.204 \
  -k /root/key.pem
```

## Flags

| Flag | What it does |
| --- | --- |
| `-d, --dir DIR` | Directory to transfer. Repeat for multiple dirs. |
| `-u, --user USER` | Username on the destination server. |
| `-i, --ip IP` | Destination server IP. |
| `-k, --key FILE` | SSH private key. Leave empty for password auth. |
| `-b, --base-dir DIR` | Where to drop the dirs on the destination (default `/home/USER`). |
| `-e, --exclude PATTERN` | Extra rsync exclude pattern. Repeat for multiple. |
| `--skip-deps` | Don't run `npm install` / `pip install` on the destination. |
| `--skip-verify` | Skip the MD5 integrity check after transfer. |
| `--dry-run` | Show the plan without actually doing anything. |
| `-h, --help` | Print usage. |

Default excludes: `node_modules`, `.git`, `__pycache__`, `*.pyc`, `.venv`.

## How it works

The script walks through these steps in order. Anything missing gets prompted interactively.

1. **Collect server details.** IP, username, SSH key path, and the base directory on the destination.
2. **Pick directories to transfer.** Either via `-d` flags or interactively. Each dir is checked for existence and size.
3. **Show the transfer plan.** You get a summary (source → destination, dirs, sizes, excludes) and a Y/n confirm before anything happens.
4. **Validate.** Checks the SSH key file exists, fixes its permissions to `600`, then opens a test SSH connection to the destination. Bails early if anything's off.
5. **Transfer.** Runs `rsync -avz --progress` for each directory with the configured excludes. Each dir lands at `<base-dir>/<dir-name>` on the destination.
6. **Verify integrity.** Runs `md5sum` on every file on both sides, compares the lists, and reports any mismatches. Small differences in `.log` / `.cache` / `.tmp` files are flagged as warnings, not failures.
7. **Install dependencies.** For each transferred dir:
   - If `package.json` exists → `npm install` on the destination.
   - If `requirements.txt` exists and there's no `venv/` folder → `pip install -r requirements.txt`.
8. **Print summary.** Final report of where each directory ended up.

You can skip steps 6 and 7 with `--skip-verify` and `--skip-deps`.

## SSH options used

The script always passes these to ssh and rsync, so you don't get tripped up by host key prompts on a fresh server:

```
-o StrictHostKeyChecking=no
-o UserKnownHostsFile=/dev/null
-o LogLevel=ERROR
```

If you'd rather verify host keys properly, edit `build_ssh_opts()` near the top.

## Notes

- Run the script on the **source** server. It pushes outward.
- The destination needs `rsync`, `ssh`, plus `npm` or `python3` if you want auto dependency install.
- For Python projects with a committed `venv/` folder, the script skips `pip install` since you're presumably moving the venv along. That's usually a bad idea across distros — prefer leaving `venv` out and letting the script rebuild it.
- The MD5 verification step can be slow on huge trees. Use `--skip-verify` if you trust rsync's own checks.
