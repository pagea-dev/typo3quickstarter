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

Grab the latest release — it's a single file with no other dependencies beyond `bash`, `docker`, and `ddev`:

```bash
curl -LO https://github.com/pagea-dev/typo3quickstarter/releases/latest/download/typo3-ddev-setup.sh
chmod +x typo3-ddev-setup.sh
```

Or clone the repo instead if you also want `docs/`, `CHANGELOG.md`, etc.:

```bash
git clone https://github.com/pagea-dev/typo3quickstarter.git
cd typo3quickstarter
chmod +x typo3-ddev-setup.sh
```

## Usage

```bash
./typo3-ddev-setup.sh --release=13
```

No `--release`? It defaults to the newest supported major version:

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
| `-r=N`, `--release=N` | TYPO3 version to install — see [docs/versions.md](docs/versions.md) | highest supported |
| `--name=NAME` | DDEV project name | auto-generated, e.g. `typo3-v13-a1b2` |
| `--path=DIR` | Where the project folder is created (also used by `--cleanup`) | current directory |
| `--admin-user`, `--admin-password`, `--admin-email` | Primary admin backend user — see [docs/backend-users.md](docs/backend-users.md) | `admin` / random / `admin@<project>.ddev.site` |
| `--beuser`, `--bepass`, `--bemail` | Create an additional admin backend user — see [docs/backend-users.md](docs/backend-users.md) | — |
| `--require=PKG` | Install extra Composer packages after setup — see [docs/composer-packages.md](docs/composer-packages.md) | — |
| `--extension=PATH` | Mount and require a local extension for development — see [docs/composer-packages.md](docs/composer-packages.md) | — |
| `--list` | List all instances this script created — see [docs/instances.md](docs/instances.md) | — |
| `--cleanup`, `--clear`, `--c` | Interactively remove previously created instances — see [docs/instances.md](docs/instances.md) | — |
| `-v`, `--verbose` | Also write the full console output to `verbose.log` — see [docs/verbose-logging.md](docs/verbose-logging.md) | — |
| `-h`, `--help` | Show usage | — |
| `--version` | Show the script's own version — see [docs/information.md](docs/information.md) | — |

## Documentation

- [docs/versions.md](docs/versions.md) — selecting a version, pinning an exact patch release, the `--no-security-blocking` security note, TYPO3 v11 quirks
- [docs/backend-users.md](docs/backend-users.md) — the primary admin user and additional backend users via `--beuser`
- [docs/composer-packages.md](docs/composer-packages.md) — extra Composer packages via `--require` and local extension development via `--extension`
- [docs/instances.md](docs/instances.md) — listing (`--list`) and removing (`--cleanup`) instances
- [docs/verbose-logging.md](docs/verbose-logging.md) — `--verbose`/`verbose.log`
- [docs/information.md](docs/information.md) — the script's own `--version` and the release process
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — guidelines for PRs
- [CHANGELOG.md](CHANGELOG.md) — what changed in each version

## Contributing

Sending a PR? Please read [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) first - in short: branch from an up-to-date `main`, test the script for real before opening the PR, and keep the executable bit intact.

## Compatibility

Actively tested on Ubuntu-based Linux (e.g. Zorin OS) and Windows via WSL. Should work anywhere `bash`, `docker`, and `ddev` do, but hasn't been verified elsewhere.

macOS isn't tested or supported yet - happy to take a PR from someone who wants to develop and test it there (see [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)).

## Notes

- `typo3-credentials.txt` is written outside the `public/` docroot, so it's never reachable over HTTP, and it gets `chmod 600` plus an entry in `.gitignore` automatically. `verbose.log` (with `--verbose`) gets the same treatment.

## License

MIT — see [LICENSE](LICENSE).
