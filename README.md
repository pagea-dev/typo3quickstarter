# typo3quickstarter

One-command bash script that spins up disposable TYPO3 instances on [DDEV](https://ddev.com). Pick a version (or let it grab the latest), and it configures DDEV, installs TYPO3 via Composer, sets up the database and an admin user, drops the credentials into a local file, and opens the backend in your browser.

Built because roughly half of all TYPO3 sites out there are still running on old major versions — this makes it trivial to spin up several versions side by side and see what actually changed.

![typo3quickstarter demo](demo.gif)

## Why

- **One command, zero clicking through the install wizard.** No more re-typing DB credentials or admin passwords by hand.
- **Test against multiple TYPO3 versions in parallel.** Each instance gets its own name, its own DDEV project, its own URL.
- **Disposable by design.** Spin one up, break it, tear it down. `--cleanup` gets rid of the mess for you.

## Prerequisites

- [Docker](https://www.docker.com/)
- [DDEV](https://ddev.com/get-started/) (v1.22+)

The script checks for both and bails out early with a clear error if either is missing or Docker isn't running.

## Installation

```bash
git clone https://github.com/pagea-dev/typo3quickstarter.git
cd typo3quickstarter
chmod +x typo3-ddev-setup.sh
```

Or just grab the single file — it has no other dependencies beyond `bash`, `docker`, and `ddev`.

## Usage

### Spin up an instance

```bash
./typo3-ddev-setup.sh --v=13
```

Want a specific minor or patch release instead of the newest one on that line? Pin it directly:

```bash
./typo3-ddev-setup.sh --v=12.4.20
```

No `--v`? It defaults to the newest supported major version:

```bash
./typo3-ddev-setup.sh
```

That's it. The script will:

1. Create a project folder named e.g. `typo3-v13-a1b2` (or use `--name` if you gave one)
2. Run `ddev config` with the right PHP version for that TYPO3 release
3. Install TYPO3 via `ddev composer create`
4. Run the non-interactive TYPO3 setup (database, admin user, default site)
5. Write the login details to `typo3-credentials.txt` in the project folder
6. Open `/typo3` (the backend) in your browser via `ddev launch`

At the end you'll see something like:

```
==> Done.
URL:         https://typo3-v13-a1b2.ddev.site
Backend:     https://typo3-v13-a1b2.ddev.site/typo3
Admin:       admin
Password:    Ddev-482913605-Aa1
Credentials: /home/you/projects/typo3-v13-a1b2/typo3-credentials.txt
```

> The very first time DDEV adds a new `*.ddev.site` hostname to your system, it needs `sudo` to update `/etc/hosts` — you'll get a normal password prompt for that. It only happens once per hostname.

### Options

| Flag | Description | Default |
|---|---|---|
| `--v=N` | TYPO3 version to install — a major version (`12`) or a pinned minor/patch release (`12.4`, `12.4.20`) | highest supported |
| `--name=NAME` | DDEV project name | auto-generated, e.g. `typo3-v13-a1b2` |
| `--path=DIR` | Where the project folder is created (also used by `--cleanup`) | current directory |
| `--admin-user=USER` | Backend admin username | `admin` |
| `--admin-password=PASS` | Backend admin password | randomly generated |
| `--admin-email=MAIL` | Backend admin email | `admin@<project>.ddev.site` |
| `--cleanup` | Interactively remove previously created instances | — |
| `-h`, `--help` | Show usage | — |

Currently supported TYPO3 versions:

| `--v` | PHP | Composer constraint |
|---|---|---|
| 11 | 8.1 | `^11.5` |
| 12 | 8.2 | `^12.4` |
| 13 | 8.3 | `^13.4` |
| 14 | 8.4 | `^14.3` |

> Project folder/DDEV names are always based on the major version (e.g. `typo3-v12-a1b2`), even if you pinned an exact patch release with `--v=12.4.20`.

> **Pinning a patch release:** `typo3/cms-base-distribution` (the meta-package the script installs) only has a couple of releases of its own — it just bundles the real `typo3/cms-*` packages via the constraints above. So pinning e.g. `--v=12.4.20` can't be done by requesting that version of the distribution package directly; the script installs via the normal constraint first and then re-pins every `typo3/cms-*` package to the exact version. Older patch releases are often flagged by Composer's security-advisory check — since pinning one is a deliberate choice here, the script installs it anyway with `--no-security-blocking`.

> **v11 note:** TYPO3 v11's native `typo3 setup` CLI command crashes on fresh installs ([TYPO3 Forge #105452](https://forge.typo3.org/issues/105452), closed won't-fix since v11 is EOL). For `--v=11` the script automatically falls back to the legacy `typo3cms install:setup` installer instead, which doesn't have this bug.

### Cleaning up

```bash
./typo3-ddev-setup.sh --cleanup
```

Scans the current directory for instances the script created and shows an interactive checklist:

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

## Notes

- `typo3-credentials.txt` is written outside the `public/` docroot, so it's never reachable over HTTP, and it gets `chmod 600` plus an entry in `.gitignore` automatically.
- Only one major version is wired up per `--v` for now (see the table above) — extending the version map to a new TYPO3 release is a one-line addition in the script.

## Versioning

`./typo3-ddev-setup.sh --version` prints the current script version. It's bumped only as part of a GitHub release (not per commit) — see [CHANGELOG.md](CHANGELOG.md) for what changed in each version.

## License

MIT — see [LICENSE](LICENSE).
