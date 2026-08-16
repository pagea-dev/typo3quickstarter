# Script versioning

```bash
./typo3-ddev-setup.sh --version
```

Prints the script's own version (currently embedded as `SCRIPT_VERSION` near the top of `typo3-ddev-setup.sh`, not in a separate file — that would break the "just grab the single file" install path).

This version is bumped only as part of a GitHub release, not per commit. The release process:

1. Move the relevant [CHANGELOG.md](../CHANGELOG.md) entries out of `[Unreleased]` into a new `## [X.Y.Z] - YYYY-MM-DD` section.
2. Bump `SCRIPT_VERSION` in `typo3-ddev-setup.sh` to match.
3. Commit, then create the GitHub release.

See [CHANGELOG.md](../CHANGELOG.md) for what changed in each version.
