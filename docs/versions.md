# TYPO3 versions

## Selecting a version

```bash
./typo3-ddev-setup.sh --release=13
```

`-r`/`--release` accepts either a bare major version or a pinned minor/patch release:

| Form | Example | Result |
|---|---|---|
| Major only | `--release=12` | Newest release on that major's LTS line |
| Minor | `--release=12.4` | Same as above for the current major versions (each major only has one LTS minor line) |
| Exact patch | `--release=12.4.20` | Exactly that release, pinned |

No `--release` at all? It defaults to the newest supported major version.

Currently supported major versions:

| `--release` | PHP | Composer constraint |
|---|---|---|
| 9  | 7.4 | `^9.5` |
| 10 | 7.4 | `^10.4` |
| 11 | 8.1 | `^11.5` |
| 12 | 8.2 | `^12.4` |
| 13 | 8.3 | `^13.4` |
| 14 | 8.4 | `^14.3` |

Only one release line is wired up per major version — extending the version map to a new TYPO3 release is a one-line addition in the script.

The PHP column is only the default - see [Choosing PHP and the database](#choosing-php-and-the-database).

> Project folder/DDEV names are always based on the major version (e.g. `typo3-v12-101`), even if you pinned an exact patch release with `--release=12.4.20`.

## Pre-releases (TYPO3 15)

| `--release` | PHP | Composer constraint |
|---|---|---|
| 15 | 8.5 | `dev-main` |

TYPO3 15 has no release yet. It's developed on `main`, and neither `typo3/cms-core` nor `typo3/cms-base-distribution` publish a `15.x` branch on Packagist — `dev-main` (branch alias `15.0.x-dev`) is the only thing that resolves. `--release=15` installs exactly that:

```bash
./typo3-ddev-setup.sh --release=15
```

```
==> TYPO3 15 has no release yet - installing the development branch (dev-main).
    Expect breakage, and expect two installs made on different days to differ.
```

Three things follow from it being a development branch:

- **It's never the default.** Leaving out `--release` still gives you the highest *released* version. You have to ask for 15 by name.
- **It can't be pinned.** `--release=15.0` or `--release=15.0.1` is rejected up front, because there is no such release to pin to — better than failing minutes later inside Composer.
- **It needs PHP 8.5**, which the script sets for you like every other version. Your DDEV has to know that PHP version; if it's too old, `ddev config` says so and updating DDEV fixes it.

The script fixes up two things in the scaffolded `composer.json` before installing:

- **`minimum-stability: dev` plus `prefer-stable: true`.** The base distribution's `main` branch requires every `typo3/cms-*` at `dev-main` but sets no `minimum-stability` of its own, so anything added afterwards — the core extras the script requires, and your own `--require` packages — would be judged against the default `stable` and refused. `prefer-stable` keeps unrelated third-party packages on their stable releases regardless.
- **`config.platform.php` is removed** - as on every version, see [The `config.platform.php` pin](#the-configplatformphp-pin). On this branch it matters most: it still pins `8.2.0`, left over from the 14 line, while the `cms-core` it pulls in already requires `^8.5`, so Composer ends up rejecting its own packages:

  ```
  typo3/cms-core[dev-main, 15.0.x-dev] require php ^8.5 -> your php version
  (8.2.0; overridden via config.platform, actual: 8.5.7) does not satisfy that requirement.
  ```

Once 15.0 is actually released, it moves from the pre-release list into the table above and gets a normal `^15.0` constraint.

## Choosing PHP and the database

```bash
./typo3-ddev-setup.sh --release=13 --php-version=8.4 --database=mysql:8.0
```

- **`--php-version=X.Y`** replaces the PHP from the table above. It is not checked against what that TYPO3 version supports - if it doesn't fit, Composer says so during the install. Your DDEV has to know that PHP version.
- **`--database=TYPE:VERSION`** picks the database server, with the same values `ddev config --database` takes: `mariadb:<version>` or `mysql:<version>`. Without it you get DDEV's default (currently MariaDB). PostgreSQL isn't offered, since the setup is MySQL/MariaDB-specific.

Only the format is checked up front; whether DDEV has that exact image is up to `ddev config`.

## The `config.platform.php` pin

Several base distributions pin `config.platform.php` below the PHP the container runs:

| `--release` | `config.platform.php` | Default PHP in the container |
|---|---|---|
| 9, 10 | `7.2` | 7.4 |
| 11 | `7.4.1` | 8.1 |
| 15 | `8.2.0` | 8.5 |

That pin wins over the PHP that's actually installed, so Composer resolves everything against it and refuses packages that would install fine - typically tooling like Rector or PHPStan you'd add to an old instance to plan an upgrade, and it would make `--php-version` pointless. The script removes the pin on every version right after scaffolding, so Composer sees the container's real PHP.

The trade-off: the pin is also upstream's way of keeping dependencies installable on the minimum PHP. Without it, the resulting `composer.lock` may pick versions that need the container's newer PHP - fine for a disposable instance, but not representative of what a production server on the minimum PHP would resolve.

## Pinning an exact patch release

`typo3/cms-base-distribution` — the meta-package the script installs — only has a couple of releases of its own (`v12.4.0`, `v12.4.1`, ...). It just bundles the real `typo3/cms-*` packages via the constraints in the table above. So pinning e.g. `--release=12.4.20` can't be done by requesting that version of the distribution package directly — it doesn't exist.

Instead, the script:

1. Scaffolds the project via the normal `^X.Y` constraint with `composer create-project ... --no-install` (files only, no packages installed yet).
2. Rewrites `composer.json`, replacing every `typo3/cms-*` package's `^X.Y` constraint with the exact pinned version.
3. Runs `composer install` to install that exact, fully pinned set of packages.

## ⚠️ Security note: `--no-security-blocking`

Every Composer install/require in this script passes `--no-security-blocking`, printed once up front:

```
==> Installing with --no-security-blocking: disposable test instances, not production
```

Composer normally refuses to install any package version flagged by a known security advisory - and since there's essentially always something flagged somewhere in a TYPO3 release line, this can otherwise block even a completely plain, unpinned `--release=13` the moment Composer has to freshly resolve the full dependency tree (e.g. nothing yet locked, as right after `create-project`). Pinning an old patch release on purpose to reproduce a bug is the most common reason you'd actually want an affected version installed, but the block is bypassed unconditionally rather than only when pinning, since it would otherwise resurface unpredictably. These are disposable local test instances, never anything running in production, so that trade-off is fine here.

## The old ones: 9, 10 and 11

TYPO3 9.5, 10.4 and 11.5 are all long past end of life. They're here for one reason: getting an old extension in front of a running instance of the version it was written for, so you can start moving it forward. Everything the script does works the same way on them — `--extension`, `--require`, `--with-git`, cleanup — but a few things are worth knowing.

**They install differently.** None of them uses TYPO3's own `typo3 setup`: 9 and 10 have no such command at all, and v11's crashes on fresh CLI installs ([TYPO3 Forge #105452](https://forge.typo3.org/issues/105452), closed won't-fix since v11 is EOL). All three are set up with the legacy `typo3cms install:setup` from [TYPO3 Console](https://github.com/TYPO3-Console/typo3_console), which ships with their base distribution anyway.

**They run on PHP 7.4.** Their `typo3/cms-core` requires PHP `^7.2`, so 7.4 is the newest they run on (9 and 10; 11 defaults to 8.1). DDEV still ships that image, but expect your IDE and any modern tooling to complain about the language level.

**9 and 10 still have `PackageStates.php`.** Extensions added with `--require`/`--extension` only become active once that file is regenerated, so the script runs `install:generatepackagestates` before setting the extensions up (with `extension:setupactive` — TYPO3 Console's own `extension:setup` wants an explicit list of extension keys). From v11 on, that file is gone.

**Their `allow-plugins` list is out of date.** Both distributions ship a Composer `allow-plugins` list from before TYPO3 Console's plugin had to be on it, and Composer 2.2+ doesn't skip a plugin that's missing from it — it aborts the whole install. The script adds the entry before installing.

**TYPO3 9 needs its site base repaired.** The `--site-base-url` option only arrived with TYPO3 Console 6 (TYPO3 10); on 9 it aborts the install outright, and TYPO3 9 then derives the base from the current request — which on the CLI doesn't exist, leaving a nonsense `base: ht/` behind that no request can match. The script writes the real URL into `config/sites/*/config.yaml` afterwards, so the frontend comes up like on any other version.

**The extension kickstarter needs 12+.** `--with-git` still versions the whole project on 9, 10 and 11, but the "scaffold a new extension" option is skipped with a note.
