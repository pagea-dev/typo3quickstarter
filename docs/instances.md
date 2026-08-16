# Managing your instances

`--list` and `--cleanup` both scan a directory (current directory, or `--path=DIR`) for instances this script created. They recognize an instance by the marker files it always writes — `.ddev/config.yaml` and `typo3-credentials.txt` in the project folder — not by the folder name. So instances started with a custom `--name=` are found just as reliably as auto-generated ones.

The TYPO3 version shown is read straight out of each instance's `composer.lock` (the exact `typo3/cms-core` version), not just the major version encoded in the folder name.

## `--list`: see what's there

```bash
./typo3-ddev-setup.sh --list
```

```
TYPO3 V12.4.45    typo3-v12-5aae           https://typo3-v12-5aae.ddev.site
TYPO3 V13.4.1     typo3-v13-6235           https://typo3-v13-6235.ddev.site
```

Non-interactive, plain output — safe to run in scripts or CI. Prints nothing to delete or select, just what's currently on disk under the scanned path.

## `--cleanup`: get rid of it

```bash
./typo3-ddev-setup.sh --cleanup
```

`--clear` and `--c` are exact aliases for `--cleanup`, in case that's easier to remember or type.

Shows the same instances as `--list`, but as an interactive checklist:

```
Select instances to delete (Up/Down move, Space toggle, Enter confirm, q abort):
> [ ] TYPO3 V12.4.45 | typo3-v12-5aae
  [x] TYPO3 V13.4.1  | typo3-v13-6235
```

- `↑` / `↓` — move
- `Space` — toggle selection
- `Enter` — delete everything selected
- `q` — abort, nothing is touched

For every selected instance it runs `ddev delete -Oy` (removes containers, DB volumes, the DDEV project listing, and the hosts file entry) and only deletes the project folder itself once that succeeded — if `ddev delete` fails for some reason, the folder is left in place so nothing gets silently lost.

`--cleanup` needs an interactive terminal (arrow keys / space / enter) — it won't run in a non-interactive shell or CI. Use `--list` there instead.
