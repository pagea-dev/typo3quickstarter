# `--create-extension`: scaffold a new extension with the kickstarter

```bash
./typo3-ddev-setup.sh --release=13 --create-extension
```

After the instance is fully set up (right before the "Done" summary), installs [friendsoftypo3/kickstarter](https://github.com/FriendsOfTYPO3/kickstarter) and hands the terminal to its interactive `make:extension` wizard - needs a real terminal, same as `--cleanup` and `--with-git`.

```
==> Installing friendsoftypo3/kickstarter (dev dependency)
==> Launching the TYPO3 extension kickstarter - follow the prompts
...
==> Registering packages/my_extension (vendor/my-extension) with Composer
Extension created at typo3-v13-.../packages/my_extension and installed
```

Requires TYPO3 12+: the kickstarter has no release for the older lines, so `--create-extension` together with `--release=9`, `10` or `11` is refused right away instead of after the install. It is installed as a `--dev` Composer requirement, since it's a scaffolding tool, not something the resulting extension needs at runtime. Composer picks whichever kickstarter release matches the installed core.

## What happens after the wizard

The kickstarter always writes into `public/typo3temp/` (`kickstarter/` from its 0.3.5 release on, `ext-kickstarter/` before that). That is regenerable scratch space, not somewhere real extension code should live, so once the wizard is done:

1. The new directory is found by comparing the export directory before and after the wizard - `make:extension` has no non-interactive mode and doesn't report the key it was given.
2. It is copied to `packages/<extension_key>`. Keep in mind that `packages/` belongs to the instance, so `--cleanup` removes it together with everything else - push or copy the extension somewhere else first if you want to keep it.
3. It is registered with Composer exactly like `--extension` registers a mounted one: a path repository, `composer require vendor/package:@dev`, then `extension:setup`.

The original under `public/typo3temp/` stays where it is. Further kickstarter commands (`make:model`, `make:controller`, ...) work on that copy, so if you use them later, copy the result over to `packages/` again.

If the wizard is cancelled or fails, if its result can't be identified (e.g. more than one new directory), or if `packages/<extension_key>` already exists, nothing is copied or registered - the instance itself is still complete.

## Together with `--with-git`

`--create-extension` runs before the `--with-git` question, so both answers make sense:

- **1) The whole TYPO3 project** - the new extension is part of the initial commit.
- **2) A new extension only** - the extension `--create-extension` just made gets its own repository; the wizard is not started a second time.

See [with-git.md](with-git.md).
