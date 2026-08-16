# Examples

Practical recipes for common scenarios. Each links to the fuller flag-by-flag doc if you want the details behind it.

## Quickstart: just give me a TYPO3

```bash
./typo3-ddev-setup.sh
```

No flags at all. Installs the newest supported TYPO3 major version, generates a project name and admin password, and opens the backend when it's done.

## Reproduce a bug against an exact patch release

```bash
./typo3-ddev-setup.sh --release=12.4.20
```

`--release` also accepts a bare major (`--release=12`, newest patch on that line) or a minor (`--release=12.4`, same thing right now since each major only has one LTS line). An exact patch like `12.4.20` pins that precise release instead — useful for reproducing an issue that was fixed in a later patch, or checking whether an extension breaks on an older core. See [versions.md](versions.md) for how the pinning works and the `--no-security-blocking` note that comes with it (Composer normally refuses to install versions flagged by a security advisory - this script bypasses that check throughout, not just when pinning).

## A specific login instead of the generated one

```bash
./typo3-ddev-setup.sh --admin-user=lukas --admin-password='Correct-Horse-1' --admin-email=lukas@example.com
```

Without these, you still get a working admin account — username `admin`, a random generated password, email `admin@<project>.ddev.site` — all written to `typo3-credentials.txt` in the project folder either way. Use these flags when you want a login you'll actually remember, e.g. for an instance you're going to keep open for a while. See [backend-users.md](backend-users.md).

## Install extra Composer packages

```bash
./typo3-ddev-setup.sh --release=13 --require=georgringer/news b13/container
```

Runs `composer require` for each package right after the base install. Repeat `--require=` or list several packages after one occurrence (as above) - both work the same.

## Test whether your extension supports a given TYPO3 version

```bash
./typo3-ddev-setup.sh --release=12 --extension=/home/me/extensions/my-extension
```

For an extension that lives as a local checkout, not (yet) on Packagist. Mounts the directory into the container and `composer require`s it at `:@dev`, so any code change you make locally is picked up immediately without reinstalling. Combine with `--release` to check compatibility against a version your extension doesn't officially declare support for yet.

> If the extension's own `composer.json` requires a TYPO3 version your `--release` doesn't satisfy, Composer will refuse the install with a conflict - that's a real constraint check, not something this script can override. See [composer-packages.md](composer-packages.md) for the mechanics, and the note there on the one syntax gotcha when combining `--require`/`--extension` with other flags.

## Everything in one command

```bash
./typo3-ddev-setup.sh --release=14 --require=b13/container georgringer/news --admin-user=lukas --admin-password='Correct-Horse-1' --admin-email=lukas@example.com --name=news-demo
```

All of the above compose freely: a pinned/major release, several Composer packages, a custom admin login, and a fixed project name instead of an auto-generated one.

## See what's currently on disk

```bash
./typo3-ddev-setup.sh --list
```

```
TYPO3 V12.4.45    typo3-v12-5aae           https://typo3-v12-5aae.ddev.site
TYPO3 V13.4.1     typo3-v13-6235           https://typo3-v13-6235.ddev.site
```

Non-interactive and safe for scripts/CI - scans `--path` (current directory by default) for instances this script created. See [instances.md](instances.md).

## Clean up one instance you just created

Every "Done" summary prints a ready-to-use command for exactly that instance:

```bash
./typo3-ddev-setup.sh --c 5aae
```

`--c`/`--clear`/`--cleanup` accept one or more name/ID substrings to target directly - skips the checklist if that narrows it down to a single match, and asks for confirmation before deleting anything either way.

## Clean up everything

```bash
./typo3-ddev-setup.sh --cleanup
```

With no target given, shows every instance found under `--path` in an interactive checklist (`Space` to toggle, `Enter` to confirm), then asks you to confirm the whole batch before actually removing anything. Needs a real terminal - use `--list` instead in scripts/CI. See [instances.md](instances.md) for the full walkthrough.

## Debug a run that failed partway through

```bash
./typo3-ddev-setup.sh --release=13 --require=some/broken-package --verbose
```

Writes the full console output (including everything Composer and DDEV printed) to `verbose.log` in the project folder, in addition to showing it live. Handy when something fails deep inside a Composer/DDEV call and the summary at the top of your terminal has already scrolled away. See [verbose-logging.md](verbose-logging.md).
