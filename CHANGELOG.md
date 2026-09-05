# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Every normal run now checks whether a newer release exists and prints a green one-line notice under the banner if it does, so an outdated copy no longer stays outdated just because nobody thought to run `typo3quickstarter update`. It only ever informs - nothing is asked and nothing is installed - and it stays silent when offline, without `curl`, or inside a git checkout, where `git pull` is the right tool. The check gives up after 3 seconds so it can't hold up a setup, and `TYPO3QUICKSTARTER_NO_UPDATE_CHECK=1` disables it entirely - see [docs/installation.md](docs/installation.md).
- `--require-dev=PKG` installs extra Composer packages as development dependencies, for everything that belongs in a test instance but not in a real project's `require` - Rector, Fractor, PHPStan and friends. Same repeat/space-separated syntax as `--require`, and it runs after the base install like that one does - see [docs/composer-packages.md](docs/composer-packages.md). Thanks to [@thomasrawiel](https://github.com/thomasrawiel) ([#18](https://github.com/pagea-dev/typo3quickstarter/pull/18)).
- `--release=15` installs the unreleased TYPO3 15 development branch, for trying out what's coming before there is anything to download. TYPO3 15 lives on `main` and has no `15.x` branch on Packagist, so it is installed from `dev-main` (branch alias `15.0.x-dev`) on PHP 8.5, with `minimum-stability: dev` and `prefer-stable: true` set on the project so the core extras and your own `--require` packages still resolve. It is never the default - leaving out `--release` keeps giving you the highest released version - and it cannot be pinned to a patch release, which is rejected up front rather than several minutes into Composer. The stale `config.platform.php` the base distribution still carries from the 14 line is dropped as well, since it made Composer judge TYPO3 15 against PHP 8.2 and reject its own packages - see [docs/versions.md](docs/versions.md) ([#19](https://github.com/pagea-dev/typo3quickstarter/issues/19)).

### Fixed

- `--release=11` produced an instance that answered every request with "The current host header value does not match the configured trusted hosts pattern". TYPO3 11 has no `config/system/settings.php` - it still keeps its configuration in `public/typo3conf/LocalConfiguration.php` - so the step that relaxes `trustedHostsPattern` found no file to edit and quietly did nothing. It is now written through typo3-console for that version line, which ships with the v11 base distribution anyway. Thanks to [@thomasrawiel](https://github.com/thomasrawiel) ([#25](https://github.com/pagea-dev/typo3quickstarter/pull/25), [#23](https://github.com/pagea-dev/typo3quickstarter/issues/23)).
- `typo3quickstarter uninstall` on a copy with no uninstaller next to it told you to delete the script and nothing else, quietly leaving the `t3quickstarter` alias behind as a symlink pointing at a file that no longer exists. It now lists every symlink in that directory pointing back at the running copy, so the printed commands actually remove all of it.

### Changed

- Auto-generated instance names now end in three digits (`typo3-v14-101`) instead of four hex characters (`typo3-v14-a1b2`), so the suffix the cleanup hint prints can be read off and typed back without picking letters out of a blob. The digits are checked before they're used - against the target directory and against DDEV, whose project names are global - so a name is never reused by an instance sitting in some other directory.
- The final summary no longer runs `ddev describe`. Its full-width table pushed the backend URL and the admin password off the screen, so the one thing you actually need right then had to be scrolled back to. The summary now points at `ddev describe` for ports, database and Mailpit details instead of printing them unasked.

## [0.5.0] - 2026-08-30

### Added

- `--xdebug` enables Xdebug for PHP step debugging right at `ddev config` time, so it's live from the first `ddev start` instead of needing a `ddev xdebug on` afterwards. Off by default, as in DDEV itself, since Xdebug costs performance on every request - see [docs/xdebug.md](docs/xdebug.md). Thanks to [@thomasrawiel](https://github.com/thomasrawiel) for the report ([#16](https://github.com/pagea-dev/typo3quickstarter/issues/16)).
- `update` and `uninstall` as subcommands of the installed command: `typo3quickstarter update` compares the running version against the latest release and installs it after asking, `typo3quickstarter uninstall` hands over to the installed uninstaller. `update` only moves forward (a build ahead of the release is left alone), refuses to touch a copy inside a git checkout, and stages the new version next to the old one before renaming it into place, so the running script is never overwritten underneath itself.
- `install.sh` installs the script as a system-wide command - `typo3quickstarter`, with `t3quickstarter` as a short alias - so instances can be created from any directory without keeping a copy of the script next to them. Installs to `~/.local/bin` by default (`--prefix=DIR` for anywhere else), with `uninstall.sh` as its counterpart, which the installer places next to the command as `typo3quickstarter-uninstall` so removing it never needs a checkout. Both refuse to overwrite or delete a same-named command they didn't install, and work both from a checkout and piped straight from `curl`. The usage text and the "To clean up this instance" hint now print whichever name the script was called under - see [docs/installation.md](docs/installation.md) ([#9](https://github.com/pagea-dev/typo3quickstarter/issues/9)).
- `--env=KEY=VALUE` sets arbitrary environment variables in the web container, in place before the install even starts. Same repeat/space-separated syntax as `--require`, and a variable the script sets itself (`TYPO3_CONTEXT`) is overridden rather than duplicated when you pass your own - see [docs/environment-variables.md](docs/environment-variables.md) ([#16](https://github.com/pagea-dev/typo3quickstarter/issues/16)).

### Fixed

- An unknown option or a stray argument aborted with `C_RED: unbound variable` instead of the intended error message and usage output: the colors are only defined after the argument loop that uses them, which `set -u` rejects. They now start out empty and are filled in once `--verbose` is known.

### Changed

- The final summary now prints absolute paths for the credentials file, the verbose log and the project directory. They used to be relative to wherever the script was started, which stops being useful once it's installed on `PATH` and run from arbitrary directories.
- README restructured: status badges (supported TYPO3 versions, Bash, Docker/DDEV, license, Ko-fi), a support section, and `shell` code fences throughout. No change to the script itself.

## [0.4.1] - 2026-08-18

### Fixed

- Every install run aborted at `ddev composer create-project` with "`.typo3-ddev-setup-marker` is not allowed to be present": `ddev composer create-project` refuses to run unless the project directory is empty apart from a small whitelist, and 0.4.0 wrote that marker file to the project root beforehand. The marker now lives in `.ddev/.typo3-ddev-setup-marker` - a directory `ddev` skips over during that check - so it is still written before anything that can fail, and `--list`/`--cleanup` keep finding partway-failed runs. Instances created with 0.4.0 are still recognized at the old path ([#8](https://github.com/pagea-dev/typo3quickstarter/issues/8)).

## [0.4.0] - 2026-08-16

### Added

- Colored output based on message status: progress steps in cyan, errors in red, warnings in yellow, the final success summary in green. Auto-disables when stdout isn't a terminal (piping, `--list` in scripts/CI) or `--verbose` is set (keeps `verbose.log` free of escape codes), and can be forced off with `NO_COLOR=1`.
- A welcome banner (tool name, version, author, repo link) before every actual install run.
- [docs/examples.md](docs/examples.md) - practical recipes for common scenarios (pinning a patch release, custom admin logins, extensions, cleanup, and more), linked from the README.
- `--c all`/`--clear all`/`--cleanup all` removes every instance found under `--path` in one go - skips the checklist and asks once to confirm removing all of them.
- Every instance now also gets `typo3/cms-scheduler` and `typo3/cms-extensionmanager`, runs under `TYPO3_CONTEXT=Development`, and has `BE/debug`, `FE/debug` on and `SYS/debugExceptionHandler` disabled - see [docs/development-settings.md](docs/development-settings.md).
- Runs `ddev describe` right before opening the backend, alongside the existing summary.
- `--with-git` asks, after setup, whether to `git init` the whole project (with a sensible `.gitignore` on top of the base distribution's own) or run the [TYPO3 extension kickstarter](https://github.com/FriendsOfTYPO3/kickstarter) to create a brand-new extension under `packages/` and version that alone (TYPO3 12+ only) - see [docs/with-git.md](docs/with-git.md).
- `--cleanup`/`--clear`/`--c` now refuses to silently delete an instance containing a `.git` directory anywhere inside it: a separate warning requires typing out `yes` in full (not just `y`) before it proceeds - see [docs/instances.md](docs/instances.md).

### Fixed

- Requiring `typo3/cms-scheduler`/`typo3/cms-extensionmanager` right after `create-project --no-install` could fail with "affected by security advisories" on a completely plain, unpinned `--release`, since Composer audits the whole dependency tree the moment it resolves it for the first time (nothing locked yet at that point) - not just when pinning an old patch release. `--no-security-blocking` is now used throughout instead of only for pinned installs - see [docs/versions.md](docs/versions.md).
- Composer-required extensions (`--require`/`--extension`) never got their database tables created or caches cleared, since nothing ran `extension:setup` after `composer require`. Now runs automatically after the TYPO3 install step, before the backend opens.
- The backend's Database Analyzer permanently showed pending "CHANGE COLUMN" diffs for every table: DDEV creates its database with an explicit `utf8mb4` charset and no collation, which defaults to `utf8mb4_general_ci`, while TYPO3 configures all its tables for `utf8mb4_unicode_ci` - and no CLI command can apply that class of schema change after the fact. Now sets the database's default collation to match right after `ddev start`, before any tables exist.
- `--list`/`--cleanup` required `typo3-credentials.txt` to recognize an instance, which is only written once a run finishes successfully - a run that failed partway (Composer, TYPO3 setup, ...) left an orphaned DDEV project neither command could find, let alone remove. A `.typo3-ddev-setup-marker` file is now written right after `ddev config`, before anything that could still fail, and either it or `typo3-credentials.txt` is now enough to be recognized.

## [0.3.0] - 2026-08-16

### Added

- `docs/CONTRIBUTING.md` with PR guidelines (branch from an up-to-date `main`, test the script for real, keep the executable bit, update docs/CHANGELOG for user-facing changes), linked from README.md.
- `-v`/`--verbose` writes the full console output to `verbose.log` in the project directory (`chmod 600` + `.gitignore`, same as `typo3-credentials.txt` - it can contain the same passwords). Starts logging once the project directory exists, and moves the log in from a temp location once Composer is done with it, since `ddev composer create-project` requires an empty target directory. See [docs/verbose-logging.md](docs/verbose-logging.md).
- Compatibility section in README.md: tested on Ubuntu-based Linux and WSL; macOS not yet supported.
- `--clear` and `--c` as aliases for `--cleanup`.
- `--cleanup`/`--clear`/`--c` now accept one or more name/ID substrings (e.g. `--c 0392`) to target specific instances directly, narrowing the checklist or skipping straight to the single-instance confirmation. Every "Done" summary now prints the ready-to-use command for the instance just created, e.g. `To clean up this instance: ./typo3-ddev-setup.sh --c 0392`.
- README "More examples" section: installing several Composer packages plus a custom admin login in one command, and pinning an exact TYPO3 patch release alongside a specific extension version.

### Changed

- `--cleanup` now asks for confirmation before deleting anything, instead of deleting as soon as you press Enter in the checklist. With exactly one instance found, it skips the checklist and asks "Are you sure you want to remove it?" directly; with more than one, confirming the checklist selection shows "Are you sure you want to remove the following instances?" with the list before proceeding.

### Fixed

- `generate_password` now guarantees at least one uppercase, lowercase, digit, and special character instead of drawing all 20 characters uniformly at random - the latter had roughly a 1-in-5 chance of producing a password with no special character, which TYPO3's default password policy rejects outright, failing the whole setup.
- `--list`/`--cleanup` showed a doubled "V" (e.g. "TYPO3 Vv13.4.34") for real instances, since `composer.lock` stores the version with a leading `v` (git-tag style) that wasn't stripped.

### Removed

- `--beuser`/`--bepass`/`--bemail` (added in 0.2.0). Both this and `--admin-user`/`--admin-password`/`--admin-email` created an admin backend user, and no non-admin/editor role was ever planned, so the two overlapping flag sets were pure duplication. `--admin-*` remains as the one way to control the backend user's credentials.

## [0.2.0] - 2026-08-16

### Added

- `--release` (`-r`) selects the TYPO3 version to install, now accepting a specific minor/patch release (e.g. `12.4.20`) in addition to a bare major version. Renamed from `--v`, which collided with the new `--version` flag.
- `--beuser`/`--bepass`/`--bemail` create an additional admin backend user after setup, via TYPO3's `backend:user:create` (not available for `--release=11`, which fails fast with a clear error). See [docs/backend-users.md](docs/backend-users.md).
- `--require` installs extra Composer packages after setup; `--extension` mounts a local extension directory and requires it at `:@dev` for development. Both accept several values after one occurrence of the flag. See [docs/composer-packages.md](docs/composer-packages.md).
- `--list` lists all instances this script created under `--path` (name, TYPO3 version, URL) - non-interactive, safe for scripts/CI. Shares instance detection with `--cleanup`. See [docs/instances.md](docs/instances.md) (renamed from `docs/cleanup.md`).
- `docs/` folder with per-topic documentation (TYPO3 versions, backend users, Composer packages/extensions, instance listing/cleanup, script versioning), split out of README.md.

### Changed

- Pinning an exact minor/patch release installs it with Composer's `--no-security-blocking`, since older patch releases are commonly flagged by Composer's security-advisory check. The script now prints a warning when this applies.
- `--cleanup` now recognizes instances by the marker files this script always creates (`.ddev/config.yaml`, `typo3-credentials.txt`) instead of matching the folder name against the auto-generated naming pattern - instances started with a custom `--name=` are now found too.
- Randomly generated admin/backend-user passwords now come from a 20-character mix of upper/lowercase letters, digits, and `#*%-_`, instead of the previous fixed `Ddev-<number>-Aa1` pattern.

### Fixed

- Restored the script's executable bit (accidentally committed as non-executable by an external contribution).
- Removed duplicate extension-path validation and leftover dead debug code from the `--extension` implementation.
- Every instance now gets `trustedHostsPattern` set to `.*` in `config/system/settings.php` right after setup. Without it, requests could fail with a 500 "does not match the configured trusted hosts pattern" error, because DDEV's router terminates TLS and proxies to the web container over plain HTTP, so PHP sees `HTTPS=on` but `SERVER_PORT=80` - a mismatch TYPO3's default `'SERVER_NAME'` pattern rejects. DDEV normally papers over this by auto-generating its own override, but only during a plain `composer create-project` - the pinned-version install path (`--release=X.Y.Z`) bypasses that, so it was hit every time.

## [0.1.0] - 2026-08-16

### Added

- Initial release: one-command DDEV + Composer setup for TYPO3 11-14, with `--cleanup` and credential file generation.
