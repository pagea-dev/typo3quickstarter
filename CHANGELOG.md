# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `--release` (`-r`) selects the TYPO3 version to install, now accepting a specific minor/patch release (e.g. `12.4.20`) in addition to a bare major version. Renamed from `--v`, which collided with the new `--version` flag.

- `--beuser`/`--bepass`/`--bemail` create an additional admin backend user after setup, via TYPO3's `backend:user:create` (not available for `--release=11`, which fails fast with a clear error). See [docs/backend-users.md](docs/backend-users.md).
- `--require` installs extra Composer packages after setup; `--extension` mounts a local extension directory and requires it at `:@dev` for development. Both accept several values after one occurrence of the flag. See [docs/composer-packages.md](docs/composer-packages.md).
- `docs/` folder with per-topic documentation (TYPO3 versions, backend users, Composer packages/extensions, cleanup, script versioning), split out of README.md.

### Changed

- Pinning an exact minor/patch release installs it with Composer's `--no-security-blocking`, since older patch releases are commonly flagged by Composer's security-advisory check. The script now prints a warning when this applies.
- `--cleanup` now recognizes instances by the marker files this script always creates (`.ddev/config.yaml`, `typo3-credentials.txt`) instead of matching the folder name against the auto-generated naming pattern - instances started with a custom `--name=` are now found too.

### Fixed

- Restored the script's executable bit (accidentally committed as non-executable by an external contribution).
- Removed duplicate extension-path validation and leftover dead debug code from the `--extension` implementation.

## [0.1.0] - 2026-08-16

### Added

- Initial release: one-command DDEV + Composer setup for TYPO3 11-14, with `--cleanup` and credential file generation.
