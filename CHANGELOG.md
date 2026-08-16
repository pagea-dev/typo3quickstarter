# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.4.0] - 2026-08-16

### Added

- Colored output based on message status: progress steps in cyan, errors in red, warnings in yellow, the final success summary in green. Auto-disables when stdout isn't a terminal (piping, `--list` in scripts/CI) or `--verbose` is set (keeps `verbose.log` free of escape codes), and can be forced off with `NO_COLOR=1`.
- A welcome banner (tool name, version, author, repo link) before every actual install run.
- [docs/examples.md](docs/examples.md) - practical recipes for common scenarios (pinning a patch release, custom admin logins, extensions, cleanup, and more), linked from the README.

### Fixed

- Composer-required extensions (`--require`/`--extension`) never got their database tables created or caches cleared, since nothing ran `extension:setup` after `composer require`. Now runs automatically after the TYPO3 install step, before the backend opens.
- The backend's Database Analyzer permanently showed pending "CHANGE COLUMN" diffs for every table: DDEV creates its database with an explicit `utf8mb4` charset and no collation, which defaults to `utf8mb4_general_ci`, while TYPO3 configures all its tables for `utf8mb4_unicode_ci` - and no CLI command can apply that class of schema change after the fact. Now sets the database's default collation to match right after `ddev start`, before any tables exist.

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
