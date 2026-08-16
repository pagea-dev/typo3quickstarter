# Script version info

```bash
./typo3-ddev-setup.sh --version
```

Prints the script's own version (currently embedded as `SCRIPT_VERSION` near the top of `typo3-ddev-setup.sh`, not in a separate file — that would break the "just grab the single file" install path).

This version is bumped only as part of a GitHub release, not per commit. The release process:

1. Move the relevant [CHANGELOG.md](../CHANGELOG.md) entries out of `[Unreleased]` into a new `## [X.Y.Z] - YYYY-MM-DD` section.
2. Bump `SCRIPT_VERSION` in `typo3-ddev-setup.sh` to match.
3. Commit, then create the GitHub release with a tag matching the version (e.g. `0.2.0`) - attach `typo3-ddev-setup.sh` itself as a release asset, so `.../releases/latest/download/typo3-ddev-setup.sh` (used in the README's install instructions) always resolves to that version's script.

See [CHANGELOG.md](../CHANGELOG.md) for what changed in each version, or the [Releases page](https://github.com/pagea-dev/typo3quickstarter/releases) on GitHub.
