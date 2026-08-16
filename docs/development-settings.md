# Development settings

Every instance gets a handful of opinionated defaults on top of the plain TYPO3 install - there's no flag for any of these, they're just always on, since every instance this script creates is a disposable local one, never anything running in production.

## Always-installed core extensions

Beyond whatever `typo3/cms-base-distribution` bundles by default, every instance also gets:

- **`typo3/cms-scheduler`** - not part of the base distribution by default. The Scheduler backend module needs it, useful for testing anything cron/task-related.
- **`typo3/cms-extensionmanager`** - already part of the base distribution as of this writing, required again explicitly so the Extensions backend module keeps working the same way even if that ever changes upstream.

Both are pulled in as part of the same install as everything else, so they're pinned along with the rest of the core packages when you use an exact patch release (`--release=12.4.20`) - see [versions.md](versions.md).

## `TYPO3_CONTEXT=Development`

Set via `ddev config --web-environment-add`, so it's available to the web container from the very first `ddev start` - before TYPO3 is even installed. Switches TYPO3 out of the default `Production` application context, which relaxes production-safe defaults (more verbose error output, some caches skipped) in favor of visibility into what's actually happening.

```bash
ddev exec ./vendor/bin/typo3 --version
```

```
TYPO3 CMS 13.4.34 (Application Context: Development) - PHP 8.3
```

## Debug settings in `settings.php`

Written right after the TYPO3 install, alongside the `trustedHostsPattern` fix (see the script's `# --- Trusted hosts pattern` section):

| Setting | Value | Effect |
|---|---|---|
| `BE/debug` | `true` | Extra debug output in the backend |
| `FE/debug` | `true` | Extra debug output on the frontend |
| `SYS/debugExceptionHandler` | `''` (empty) | Disables TYPO3's own exception handler entirely - an uncaught exception shows PHP's raw error output/stack trace instead of TYPO3's formatted debug page |

The empty `debugExceptionHandler` is the one worth calling out: it's a deliberate downgrade from TYPO3's already-verbose Development-context error page to PHP's own raw output, for cases where you need to see exactly what PHP itself is doing - e.g. when TYPO3's own exception handler is what's misbehaving, or you just want the unfiltered stack trace.

These are written by reading `settings.php` as PHP and re-exporting the merged array (not a plain text search/replace), so they land correctly whether or not `BE`/`FE` already exist as top-level keys.
