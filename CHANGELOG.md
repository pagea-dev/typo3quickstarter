# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
