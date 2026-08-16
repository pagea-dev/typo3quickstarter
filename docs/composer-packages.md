# Additional Composer packages & local extensions

Two flags let you get a fully-loaded TYPO3 instance — extensions and all — from a single command, instead of installing the base system and then `composer require`-ing everything by hand afterwards.

## `--require`: install extra packages from Packagist

```bash
./typo3-ddev-setup.sh --release=13 --require=georgringer/news --require=b13/container
```

Runs `composer require` for the given packages right after the base TYPO3 install. You can either repeat `--require=` for each package, or list several after one occurrence, separated by spaces:

```bash
./typo3-ddev-setup.sh --release=13 --require=georgringer/news b13/container
```

## `--extension`: mount a local extension for development

```bash
./typo3-ddev-setup.sh --release=13 --extension=/home/me/extensions/my-extension
```

For working on an extension that only exists as a local checkout (not published on Packagist yet). The script:

1. Bind-mounts the given path(s) into the web container (`.ddev/docker-compose.extensions.yaml`, one mount per path at `/mnt/extension-N`).
2. Reads the `name` field from each extension's `composer.json`.
3. Registers a Composer [path repository](https://getcomposer.org/doc/05-repositories.md#path) pointing at the mount, then `composer require`s the package at `:@dev`.

Each extension directory must exist on your machine and contain a `composer.json` with a `name` field — the script checks both and fails fast with a clear error otherwise. Like `--require`, you can pass several extensions after one `--extension=`, separated by spaces, or repeat the flag.

## Combining both, and the one syntax gotcha

```bash
./typo3-ddev-setup.sh --require=traw/video-vtt traw/container-wrap --extension=/home/me/ext-a /home/me/ext-b --release=13 --name=test123
```

Values without a `--flag=` prefix always attach to whichever of `--require`/`--extension` appeared most recently — so group each flag's values together (as above) rather than interleaving them. `--extension=/path/a --require=pkg --extension=/path/b` works fine (each `--extension=`/`--require=` resets which bucket bare values go into); a bare value straight after an unrelated flag like `--name=test123 /path/b` does not get picked up as an extension path.
