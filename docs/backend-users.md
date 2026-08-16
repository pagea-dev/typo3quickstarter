# Backend users

## The primary admin user

Every instance gets one admin backend user, created as part of the non-interactive TYPO3 setup:

| Flag | Description | Default |
|---|---|---|
| `--admin-user=USER` | Backend admin username | `admin` |
| `--admin-password=PASS` | Backend admin password | randomly generated |
| `--admin-email=MAIL` | Backend admin email | `admin@<project>.ddev.site` |

```bash
./typo3-ddev-setup.sh --release=13 --admin-user=lukas --admin-password='Correct-Horse-1' --admin-email=lukas@example.com
```

## Additional backend users

Pass `--beuser` to create a second (or third, ...) admin backend user right after setup, e.g. for a personal login separate from the generic `admin` account:

| Flag | Description | Default |
|---|---|---|
| `--beuser=USER` | Username of the additional backend user. Set this to trigger creation — omit it and nothing extra happens. | — |
| `--bepass=PASS` | Password for `--beuser` | randomly generated |
| `--bemail=MAIL` | Email for `--beuser` | `<beuser>@<project>.ddev.site` |

```bash
./typo3-ddev-setup.sh --release=13 --beuser=jon --bepass='aSdF1"3' --bemail=jon@doe.tld
```

This runs `typo3 backend:user:create --username=... --password=... --email=... --admin --no-interaction` in the container after the regular setup finishes. The user is always created **with admin privileges** — there's currently no flag for a restricted (non-admin) role.

Both the primary admin and any `--beuser` account end up in `typo3-credentials.txt` in the project folder.

### Not supported on TYPO3 v11

`backend:user:create` was only introduced in TYPO3 core 12.2 — v11 has no equivalent CLI command (see [TYPO3-Console/TYPO3-Console#608](https://github.com/TYPO3-Console/TYPO3-Console/issues/608)). Combining `--release=11` with `--beuser` fails fast with a clear error before any containers are even started. Create additional backend users through the TYPO3 backend UI instead for v11 instances.
