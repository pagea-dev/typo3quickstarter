# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `--release` (`-r`) selects the TYPO3 version to install, now accepting a specific minor/patch release (e.g. `12.4.20`) in addition to a bare major version. Renamed from `--v`, which collided with the new `--version` flag.

- `--beuser`/`--bepass`/`--bemail` create an additional admin backend user after setup, via TYPO3's `backend:user:create` (not available for `--release=11`, which fails fast with a clear error). See [docs/backend-users.md](docs/backend-users.md).
- `docs/` folder with per-topic documentation (TYPO3 versions, backend users, cleanup, script versioning), split out of README.md.

### Changed

- Pinning an exact minor/patch release installs it with Composer's `--no-security-blocking`, since older patch releases are commonly flagged by Composer's security-advisory check. The script now prints a warning when this applies.

## [0.1.0] - 2026-08-16

### Added

- Initial release: one-command DDEV + Composer setup for TYPO3 11-14, with `--cleanup` and credential file generation.
