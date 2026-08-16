# `--with-git`: version control for what you just built

```bash
./typo3-ddev-setup.sh --release=13 --with-git
```

After the instance is fully set up (right before the "Done" summary), asks what should be put under git version control - needs a real terminal, same as `--cleanup`.

```
==> --with-git: what should be put under version control?
  1) The whole TYPO3 project
  2) A new extension only (scaffolded fresh under packages/<name>)
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

Prompts for an extension key (lowercase, e.g. `my_extension`), then scaffolds a bare-minimum extension under `packages/<key>` - just a `composer.json` (package name `local/<key-with-dashes>`, PSR-4 autoloading under `Local\<StudlyCaseKey>\`) and an `ext_emconf.php`. Registers it as a Composer path repository, requires it at `:@dev`, and runs `extension:setup` so it's active - the same mechanics as `--extension`, minus needing an existing extension to point at.

`git init` then runs inside `packages/<key>` itself, not the project root - so the extension gets its own independent history, ready to be pushed to its own repository later, while the rest of the TYPO3 instance around it stays a disposable throwaway.
