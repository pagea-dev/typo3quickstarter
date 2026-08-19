

<div align="center">
  
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20this%20project-FF5E5B?logo=kofi&logoColor=white)](https://ko-fi.com/pageadev)
[![TYPO3 11.5](https://img.shields.io/badge/TYPO3-11.5-9f9f9f?maxAge=3600&logo=typo3)](https://get.typo3.org/)
[![TYPO3 12.4](https://img.shields.io/badge/TYPO3-12.4-ff8700?maxAge=3600&logo=typo3)](https://get.typo3.org/)
[![TYPO3 13.4](https://img.shields.io/badge/TYPO3-13.4-ff8700?maxAge=3600&logo=typo3)](https://get.typo3.org/)
[![TYPO3 14.3](https://img.shields.io/badge/TYPO3-14.3-ff8700?maxAge=3600&logo=typo3)](https://get.typo3.org/)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-required-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![DDEV](https://img.shields.io/badge/DDEV-required-02A8D3?logo=ddev&logoColor=white)](https://ddev.com/)

# typo3quickstarter

One-command bash script that spins up disposable TYPO3 instances on [DDEV](https://ddev.com). Pick a version (or let it grab the latest), and it configures DDEV, installs TYPO3 via Composer, sets up the database and an admin user, drops the credentials into a local file, and opens the backend in your browser.

Built because roughly half of all TYPO3 sites out there are still running on old major versions — this makes it trivial to spin up several versions side by side and see what actually changed.

Got an idea for a feature, or found a bug? [Open an issue](https://github.com/pagea-dev/typo3quickstarter/issues) - feature requests are welcome, not just bug reports.<br><br>

![typo3quickstarter demo](demo.gif)

### ☕ Enjoying typo3quickstarter?

Support the development and keep the updates coming. Even 1€ helps :)

<a href="https://ko-fi.com/pageadev">
  <img src="https://storage.ko-fi.com/cdn/kofi6.png?v=6" alt="Buy me a coffee at ko-fi.com" height="45">
</a>

</div>


## Prerequisites

- [Docker](https://www.docker.com/)
- [DDEV](https://ddev.com/get-started/) (v1.22+)

The script checks for both and bails out early with a clear error if either is missing or Docker isn't running.

## Installation

Grab the latest release — it's a single file with no other dependencies beyond `bash`, `docker`, and `ddev`:

```shell
curl -LO https://github.com/pagea-dev/typo3quickstarter/releases/latest/download/typo3-ddev-setup.sh
chmod +x typo3-ddev-setup.sh
```

Or clone the repo instead if you also want `docs/`, `CHANGELOG.md`, etc.:

```shell
git clone https://github.com/pagea-dev/typo3quickstarter.git
cd typo3quickstarter
chmod +x typo3-ddev-setup.sh
```

## Usage

```shell
./typo3-ddev-setup.sh --release=13
```

No `--release`? It defaults to the newest supported major version:

```shell
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
To clean up this instance: ./typo3-ddev-setup.sh --c a1b2
```

> The very first time DDEV adds a new `*.ddev.site` hostname to your system, it needs `sudo` to update `/etc/hosts` — you'll get a normal password prompt for that. It only happens once per hostname.

### Options

| Flag | Description | Default |
|---|---|---|
| `-r=N`, `--release=N` | TYPO3 version to install — see [docs/versions.md](docs/versions.md) | highest supported |
| `--name=NAME` | DDEV project name | auto-generated, e.g. `typo3-v13-a1b2` |
| `--path=DIR` | Where the project folder is created (also used by `--cleanup`) | current directory |
| `--admin-user`, `--admin-password`, `--admin-email` | Admin backend user — see [docs/backend-users.md](docs/backend-users.md) | `admin` / random / `admin@<project>.ddev.site` |
| `--require=PKG` | Install extra Composer packages after setup — see [docs/composer-packages.md](docs/composer-packages.md) | — |
| `--extension=PATH` | Mount and require a local extension for development — see [docs/composer-packages.md](docs/composer-packages.md) | — |
| `--list` | List all instances this script created — see [docs/instances.md](docs/instances.md) | — |
| `--cleanup`, `--clear`, `--c` [TARGET...] | Interactively remove previously created instances, optionally narrowed down to name/ID matches — see [docs/instances.md](docs/instances.md) | — |
| `-v`, `--verbose` | Also write the full console output to `verbose.log` — see [docs/verbose-logging.md](docs/verbose-logging.md) | — |
| `--with-git` | After setup, ask whether to `git init` the whole project or scaffold and version a new extension — see [docs/with-git.md](docs/with-git.md) | — |
| `-h`, `--help` | Show usage | — |
| `--version` | Show the script's own version — see [docs/information.md](docs/information.md) | — |

### More examples

Latest TYPO3 14 with a couple of extensions and a personal admin login, in one command:

```shell
./typo3-ddev-setup.sh --release=14 --require=b13/container georgringer/news --admin-user=lukas --admin-password='Correct-Horse-1' --admin-email=lukas@example.com
```

An exact TYPO3 12 patch release, plus a specific version of an extension (`--require` takes any Composer constraint, same as `composer require vendor/package:constraint`):

```shell
./typo3-ddev-setup.sh --release=12.4.20 --require=georgringer/news:^11.0
```

Kickstart a brand-new extension against the newest TYPO3, then put just that extension under git once it's created:

```shell
./typo3-ddev-setup.sh --with-git
```

Pick option 2 when asked, follow the kickstarter's prompts, and you'll have a working TYPO3 instance plus a freshly versioned extension - see [docs/with-git.md](docs/with-git.md).

## Why

- **One command, zero clicking through the install wizard.** No more re-typing DB credentials or admin passwords by hand.
- **Test against multiple TYPO3 versions in parallel.** Each instance gets its own name, its own DDEV project, its own URL.
- **Disposable by design.** Spin one up, break it, tear it down. `--cleanup` gets rid of the mess for you.
- **Kickstart a brand-new extension and have it under git from the first commit.** `--with-git` runs the official [TYPO3 extension kickstarter](https://github.com/FriendsOfTYPO3/kickstarter), then initializes a repository right where it just created your extension - a working TYPO3 instance, a scaffolded extension, and its own git history, from a single command. See [docs/with-git.md](docs/with-git.md).

## Documentation

- [docs/examples.md](docs/examples.md) — practical recipes for common scenarios: pinning a patch release, custom admin logins, extensions, cleanup, and more
- [docs/versions.md](docs/versions.md) — selecting a version, pinning an exact patch release, the `--no-security-blocking` security note, TYPO3 v11 quirks
- [docs/backend-users.md](docs/backend-users.md) — the admin backend user
- [docs/composer-packages.md](docs/composer-packages.md) — extra Composer packages via `--require` and local extension development via `--extension`
- [docs/development-settings.md](docs/development-settings.md) — the always-on extras every instance gets: Scheduler/Extensions core extensions, `TYPO3_CONTEXT=Development`, debug settings
- [docs/with-git.md](docs/with-git.md) — `--with-git`: version the whole project or scaffold and version a new extension
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

## Special thanks

This project stands entirely on the shoulders of others' work:

- [DDEV](https://ddev.com) — the local dev environment this whole script is built around.
- [Docker](https://www.docker.com/) — the container runtime underneath DDEV.
- [TYPO3](https://typo3.org) — the CMS this exists to spin up.
- [TYPO3 Extension Kickstarter](https://github.com/FriendsOfTYPO3/kickstarter) — the interactive extension scaffolding used by `--with-git` (see [docs/with-git.md](docs/with-git.md)).

Thanks to everyone building and maintaining these projects.

## License

MIT — see [LICENSE](LICENSE).
