# migrate-vps

A bash tool to move **files and directories** between Linux servers in one shot. Rsync transfer, MD5 integrity check, and auto-install for Node/Python projects on the destination side.

Useful when you're hopping VPS providers and don't want to babysit `scp`, then re-run `npm install` and `pip install` by hand. Ship a `.tar.gz` backup, a single shell script, or a whole project directory — all in the same run.

## Quickstart

```bash
# Interactive mode — it'll ask you everything
bash migrate-server.sh

# Or pass flags directly (mix files and directories freely)
bash migrate-server.sh \
  -p /root/bot \
  -p /root/backup.tar.gz \
  -p /root/setup.sh \
  -u ubuntu \
  -i 13.236.147.204 \
  -k /root/key.pem
```

## Flags

| Flag | What it does |
| --- | --- |
| `-p, --path PATH` | File or directory to transfer. Repeat for multiple items. |
| `-d, --dir PATH` | Alias for `--path`. Kept for backward compatibility. |
| `-u, --user USER` | Username on the destination server. |
| `-i, --ip IP` | Destination server IP. |
| `-k, --key FILE` | SSH private key. Leave empty for password auth. |
| `-b, --base-dir DIR` | Where to drop the items on the destination (default `/home/USER`). |
| `-e, --exclude PATTERN` | Extra rsync exclude pattern. Applied to directories only. Repeat for multiple. |
| `--skip-deps` | Don't run `npm install` / `pip install` on the destination. |
| `--skip-verify` | Skip the MD5 integrity check after transfer. |
| `--dry-run` | Show the plan without actually doing anything. |
| `-h, --help` | Print usage. |

Default excludes (directories only): `node_modules`, `.git`, `__pycache__`, `*.pyc`, `.venv`. Single files always transfer as-is — exclude patterns don't apply to them.

## Supported items

Anything that's a regular file or a directory works. Examples:

- Project directories: `/root/bot`, `~/myapp`
- Archives: `.tar`, `.tar.gz`, `.tgz`, `.zip`, `.7z`
- Scripts: `.sh`, `.py`, `.js`
- Configs: `.env`, `.yaml`, `.json`, `.conf`
- Binaries / blobs: any single file rsync can read

Symlinks, sockets, and device files aren't supported — the script only accepts paths that are either a file or a directory.

## How it works

The script walks through these steps in order. Anything missing gets prompted interactively.

1. **Collect server details.** IP, username, SSH key path, and the base directory on the destination.
2. **Pick items to transfer.** Either via `-p` flags or interactively. Each path is checked for existence and classified as `file` or `directory`. Sizes are shown up front.
3. **Show the transfer plan.** You get a summary (source → destination, items, sizes, kinds, excludes) and a Y/n confirm before anything happens.
4. **Validate.** Checks the SSH key file exists, fixes its permissions to `600`, then opens a test SSH connection to the destination. Bails early if anything's off.
5. **Ensure remote base dir.** Runs `mkdir -p` on the destination so single-file transfers don't fail when the base path doesn't exist yet.
6. **Transfer.** Runs rsync per item:
   - **Directory** → `rsync -avz --progress <excludes> source/ user@host:dest/`
   - **File** → `rsync -avz --progress source user@host:dest/filename` (no excludes)
   Each item lands at `<base-dir>/<basename>` on the destination.
7. **Verify integrity.** MD5 checksums on both sides:
   - **Files** → single `md5sum` compared end-to-end.
   - **Directories** → `find ... -exec md5sum` on both sides, sorted, diffed. Small differences in `.log` / `.cache` / `.tmp` files are flagged as warnings, not failures.
8. **Install dependencies.** Only runs against directories (files are skipped). For each transferred dir:
   - If `package.json` exists → `npm install` on the destination.
   - If `requirements.txt` exists and there's no `venv/` folder → `pip install -r requirements.txt`.
9. **Print summary.** Final report of where each item ended up, with file/dir icons.

You can skip steps 7 and 8 with `--skip-verify` and `--skip-deps`.

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
- File mode and ownership are preserved by rsync's `-a` flag. If the destination user differs from the source, ownership lands as the destination user.
