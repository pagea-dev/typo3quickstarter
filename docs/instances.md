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

If there's only one instance, there's nothing to pick from — it just asks you to confirm removing that one:

```
Found: TYPO3 V12.4.45 | typo3-v12-5aae
Are you sure you want to remove it? [y/N]
```

With more than one, you get an interactive checklist instead:

```
Select instances to delete (Up/Down move, Space toggle, Enter confirm, q abort):
> [ ] TYPO3 V12.4.45 | typo3-v12-5aae
  [x] TYPO3 V13.4.1  | typo3-v13-6235
```

- `↑` / `↓` — move
- `Space` — toggle selection
- `Enter` — confirm the selection
- `q` — abort, nothing is touched

Confirming the selection doesn't delete anything right away — it lists exactly what you picked and asks once more:

```
Are you sure you want to remove the following instances?
  - typo3-v12-5aae
  - typo3-v13-6235
Proceed? [y/N]
```

Only on `y`/`yes` does it actually run `ddev delete -Oy` for each one (removes containers, DB volumes, the DDEV project listing, and the hosts file entry) and only deletes the project folder itself once that succeeded — if `ddev delete` fails for some reason, the folder is left in place so nothing gets silently lost.

`--cleanup` needs an interactive terminal (arrow keys / space / enter) — it won't run in a non-interactive shell or CI. Use `--list` there instead.

## Targeting a specific instance

Every "Done" summary prints a ready-to-use cleanup command for the instance you just created:

```
To clean up this instance: ./typo3-ddev-setup.sh --c 5aae
```

`--c`/`--clear`/`--cleanup` can take one or more name/ID substrings, space-separated (same multi-value syntax as `--require`/`--extension`). Only instances whose name contains at least one of them are considered:

```bash
./typo3-ddev-setup.sh --c 5aae
```

For an auto-generated name like `typo3-v12-5aae`, the 4-character suffix alone is enough and is what the hint prints — it's short and, in practice, unique. For a custom `--name=`, there's no separate suffix, so the hint prints the full name instead.

If the filter narrows things down to exactly one instance, it skips straight to the single-instance confirmation (`Found: ... Are you sure you want to remove it?`); with more than one match it still shows the checklist, just restricted to those. No match prints `No instance matching <target> found in '<path>'.` instead of the usual empty-scan message.
