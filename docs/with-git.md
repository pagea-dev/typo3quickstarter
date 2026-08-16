# `--with-git`: version control for what you just built

```bash
./typo3-ddev-setup.sh --release=13 --with-git
```

After the instance is fully set up (right before the "Done" summary), asks what should be put under git version control - needs a real terminal, same as `--cleanup`.

```
==> --with-git: what should be put under version control?
  1) The whole TYPO3 project
  2) A new extension only (via the TYPO3 extension kickstarter)
Choice [1/2]:
```

## Option 1: the whole project

Runs `git init` in the project root and commits everything except the generated/sensitive stuff. `typo3/cms-base-distribution` already ships a `.gitignore` covering `vendor/`, `var/` (except `var/labels`), and most of `public/` - this appends what it doesn't cover:

```
/.ddev/
/typo3-credentials.txt
/verbose.log
/config/system/settings.php
```

`.ddev/` is excluded because these are throwaway test instances, not something meant to be shared as a team project - if you actually want to keep the DDEV config under version control too, remove that line from `.gitignore` before committing further. `settings.php` is excluded because it holds the database password and `encryptionKey` in plaintext - standard practice for any TYPO3 project, composer-mode or not. `packages/` is deliberately left trackable, so any local extensions living there are versioned right along with everything else.

If git isn't configured with a `user.name`/`user.email` yet, the repository is still initialized and everything staged - you'll just need to configure git and commit manually afterwards.

## Option 2: a new extension only

Rather than hand-rolling a scaffold, this installs and runs [friendsoftypo3/kickstarter](https://github.com/FriendsOfTYPO3/kickstarter) - the community/FriendsOfTYPO3 extension kickstarter - and hands control to its own interactive `make:extension` wizard:

```bash
==> Installing friendsoftypo3/kickstarter (dev dependency)
==> Launching the TYPO3 extension kickstarter - follow the prompts
```

Requires TYPO3 12+ (the kickstarter has no TYPO3 11 release - `--with-git` skips this option with a note if the instance is v11). Installed as a `--dev` Composer requirement, since it's a scaffolding tool, not something the resulting extension needs at runtime. Composer resolves whichever kickstarter release matches the installed core automatically (`^0.1` for TYPO3 12, `^0.3` for TYPO3 13, `^0.4`+ for TYPO3 14) - no version needs pinning by hand.

Before launching it, the kickstarter's own `exportDirectory` setting (extension key `ext_kickstarter` - its composer.json still carries the pre-FriendsOfTYPO3-adoption name `stefanfroemken/ext-kickstarter`) is set to `packages/` in `settings.php`, matching what its own README recommends for Composer setups - its default, `typo3temp/ext-kickstarter/`, is regenerable scratch space, not somewhere you'd want to keep real extension code.

There's no non-interactive flag on `make:extension` - it only knows how to ask, so whatever extension key/vendor/namespace you give it during the wizard is what you get. Since there's no other way to learn what it created, `packages/` is diffed before and after the wizard runs to find the new directory. Once found, it's registered with Composer exactly like `--extension` registers a mounted one (path repository + `require ...:@dev` + `extension:setup`), and `git init` runs inside that extension's own directory - not the project root - so it gets its own independent history from the start, ready to be pushed to its own repository later, while the rest of the instance around it stays a disposable throwaway.

If the wizard is cancelled, fails, or its result can't be identified (e.g. it created more than one new directory), nothing is registered or versioned - you'd need to sort out `packages/` and run `git init` there yourself.
