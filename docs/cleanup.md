# Cleaning up

```bash
./typo3-ddev-setup.sh --cleanup
```

Scans the current directory (or `--path=DIR`) for instances the script created and shows an interactive checklist:

```
Select instances to delete (Up/Down move, Space toggle, Enter confirm, q abort):
> [ ] TYPO3 V12.4.45 | typo3-v12-5aae
  [x] TYPO3 V13.4.1  | typo3-v13-6235
```

- `↑` / `↓` — move
- `Space` — toggle selection
- `Enter` — delete everything selected
- `q` — abort, nothing is touched

Instances are recognized by the marker files this script always creates — `.ddev/config.yaml` and `typo3-credentials.txt` in the project folder — not by the folder name. So instances started with a custom `--name=` show up here too, same as auto-generated ones.

The version shown is read straight out of each instance's `composer.lock` (the exact `typo3/cms-core` version), not just the major version encoded in the folder name.

For every selected instance it runs `ddev delete -Oy` (removes containers, DB volumes, the DDEV project listing, and the hosts file entry) and only deletes the project folder itself once that succeeded — if `ddev delete` fails for some reason, the folder is left in place so nothing gets silently lost.

`--cleanup` needs an interactive terminal (arrow keys / space / enter) — it won't run in a non-interactive shell or CI.
