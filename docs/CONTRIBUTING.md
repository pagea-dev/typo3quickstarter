# Contributing

Thanks for considering a PR. This is a small single-file script, so a few practical rules keep things easy to review and merge.

## Before you start

- **Branch from the current version branch, not `main`.** Development happens on a branch named after the in-progress version (e.g. `0.4.0`) - check the repo's branch list for the highest version number and base your PR on that, not on `main`. `main` only moves forward once that version is actually released via its own PR; it doesn't carry in-progress work, and **PRs opened against `main` are ignored**.
- **One feature/fix per PR.** Keeps review focused and makes it easier to cut a clean changelog entry.

## Before you open the PR

- **Test it for real**, not just a read-through of the diff: run the script end-to-end with Docker + DDEV running (`./typo3-ddev-setup.sh --release=...`), and use `--list`/`--cleanup` afterwards so you don't leave stray DDEV projects around.
- **Keep the executable bit.** `git diff` shouldn't show a `mode change 100755 => 100644` for `typo3-ddev-setup.sh` - that happens easily when editing through a web UI. Run `chmod +x typo3-ddev-setup.sh` and check `git status`/`git diff --stat` before committing if unsure.
- **No leftover debug code.** Remove `echo`/print debugging (commented-out or not) before opening the PR rather than just silencing it.
- **Reuse existing helpers instead of duplicating logic** - e.g. validation that already happens once shouldn't happen again later in the script.
- **Update docs for user-facing changes.** New or changed flags need: an entry in `usage()` in `typo3-ddev-setup.sh`, the relevant page under `docs/`, the `Options` table in [README.md](../README.md), and a bullet under `[Unreleased]` in [CHANGELOG.md](../CHANGELOG.md).

## Style

- Plain `bash` with `set -euo pipefail`, no external dependencies beyond `docker` and `ddev`. Keep it that way - the whole point is a script you can `curl` and run with nothing else installed.
- Prefer portable constructs over GNU-only ones (e.g. avoid `sed -i` without a backup suffix, which behaves differently on BSD/macOS `sed`) where practical.
