# TYPO3 versions

## Selecting a version

```bash
./typo3-ddev-setup.sh --release=13
```

`-r`/`--release` accepts either a bare major version or a pinned minor/patch release:

| Form | Example | Result |
|---|---|---|
| Major only | `--release=12` | Newest release on that major's LTS line |
| Minor | `--release=12.4` | Same as above for the current major versions (each major only has one LTS minor line) |
| Exact patch | `--release=12.4.20` | Exactly that release, pinned |

No `--release` at all? It defaults to the newest supported major version.

Currently supported major versions:

| `--release` | PHP | Composer constraint |
|---|---|---|
| 11 | 8.1 | `^11.5` |
| 12 | 8.2 | `^12.4` |
| 13 | 8.3 | `^13.4` |
| 14 | 8.4 | `^14.3` |

Only one release line is wired up per major version — extending the version map to a new TYPO3 release is a one-line addition in the script.

> Project folder/DDEV names are always based on the major version (e.g. `typo3-v12-a1b2`), even if you pinned an exact patch release with `--release=12.4.20`.

## Pinning an exact patch release

`typo3/cms-base-distribution` — the meta-package the script installs — only has a couple of releases of its own (`v12.4.0`, `v12.4.1`, ...). It just bundles the real `typo3/cms-*` packages via the constraints in the table above. So pinning e.g. `--release=12.4.20` can't be done by requesting that version of the distribution package directly — it doesn't exist.

Instead, the script:

1. Scaffolds the project via the normal `^X.Y` constraint with `composer create-project ... --no-install` (files only, no packages installed yet).
2. Rewrites `composer.json`, replacing every `typo3/cms-*` package's `^X.Y` constraint with the exact pinned version.
3. Runs `composer install` to install that exact, fully pinned set of packages.

## ⚠️ Security note: `--no-security-blocking`

Every Composer install/require in this script passes `--no-security-blocking`, printed once up front:

```
==> Installing with --no-security-blocking: disposable test instances, not production
```

Composer normally refuses to install any package version flagged by a known security advisory - and since there's essentially always something flagged somewhere in a TYPO3 release line, this can otherwise block even a completely plain, unpinned `--release=13` the moment Composer has to freshly resolve the full dependency tree (e.g. nothing yet locked, as right after `create-project`). Pinning an old patch release on purpose to reproduce a bug is the most common reason you'd actually want an affected version installed, but the block is bypassed unconditionally rather than only when pinning, since it would otherwise resurface unpredictably. These are disposable local test instances, never anything running in production, so that trade-off is fine here.

## TYPO3 v11 note

TYPO3 v11's native `typo3 setup` CLI command crashes on fresh installs ([TYPO3 Forge #105452](https://forge.typo3.org/issues/105452), closed won't-fix since v11 is EOL). For `--release=11` the script automatically falls back to the legacy `typo3cms install:setup` installer instead, which doesn't have this bug.
