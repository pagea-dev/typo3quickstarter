# Verbose logging

```bash
./typo3-ddev-setup.sh --release=13 --verbose
```

`-v`/`--verbose` writes the full console output (everything you'd see on screen from the DDEV setup onward) to `verbose.log` in the project directory, in addition to printing it as usual - useful for debugging a run after the fact, or attaching to a bug report.

A couple of things worth knowing:

- **Not the very first lines.** `ddev composer create-project` refuses to run unless the project directory is empty (aside from a small whitelist of files), so `verbose.log` can't be written into it until after Composer is done. The log therefore starts at `ddev config`/`ddev start`, not at the one or two setup messages printed before the project directory exists.
- **Treat it like `typo3-credentials.txt`.** The final summary (admin username/password, and the `--beuser` credentials if set) gets logged too, so `verbose.log` gets the same `chmod 600` and a `.gitignore` entry automatically.
