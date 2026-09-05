# Database GUI (phpMyAdmin)

Every instance comes with **phpMyAdmin**, so looking into the database is one click away instead of a detour through `ddev add-on get` and a restart.

It is DDEV's official [`ddev/ddev-phpmyadmin`](https://github.com/ddev/ddev-phpmyadmin) add-on — this script only installs it for you, at the right moment.

## Where it is

```
https://<project>.ddev.site:8037
```

The URL is printed in the final summary and written to `typo3-credentials.txt` next to the backend login. There is **no login screen**: the add-on passes the database credentials to phpMyAdmin itself, so the link opens straight into the `db` database.

From inside the project directory, DDEV also gives you a shortcut that opens the same thing in your browser:

```bash
ddev phpmyadmin
```

Port `8036` serves the plain HTTP version, `8037` the HTTPS one. `ddev describe` lists both.

## `--no-pma`: leave it out

```bash
./typo3-ddev-setup.sh --release=13 --no-pma
```

Skips the add-on entirely. The instance is identical otherwise — you just don't get the extra container, and the summary and credentials file don't mention phpMyAdmin.

Nothing is lost permanently: it can be added to an existing instance at any time, from inside the project directory.

```bash
ddev add-on get ddev/ddev-phpmyadmin
ddev restart
```

The other direction works the same way:

```bash
ddev add-on remove phpmyadmin
ddev restart
```

## Notes

- The add-on is installed between `ddev config` and the first `ddev start`, so phpMyAdmin comes up together with the rest of the instance. Installed into an already running project it would only take effect after a `ddev restart` — which is exactly the step this saves.
- Installing it needs network access, since it is fetched from GitHub. If that fails, the setup **continues without it** and says so — an instance without a database GUI is still a perfectly usable instance.
- `ddev add-on get` needs DDEV v1.23.5 or newer; on older versions the script falls back to the deprecated `ddev get`.
- The add-on writes its files into `.ddev/` and marks them `#ddev-generated`. They are not yours to edit, and `--with-git` keeps `.ddev/` out of the repository anyway.
- phpMyAdmin talks to the database as `root`, so it sees every database in the container, not just TYPO3's `db`.
- If you prefer a desktop client, nothing changes: `ddev describe` still prints the host port for direct MySQL connections, and `ddev mysql` still opens a shell.
