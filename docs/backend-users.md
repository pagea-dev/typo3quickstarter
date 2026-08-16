# Backend users

Every instance gets one admin backend user, created as part of the non-interactive TYPO3 setup:

| Flag | Description | Default |
|---|---|---|
| `--admin-user=USER` | Backend admin username | `admin` |
| `--admin-password=PASS` | Backend admin password | randomly generated |
| `--admin-email=MAIL` | Backend admin email | `admin@<project>.ddev.site` |

```bash
./typo3-ddev-setup.sh --release=13 --admin-user=lukas --admin-password='Correct-Horse-1' --admin-email=lukas@example.com
```

This is the only backend user the script creates — there's no separate flag for a second account. The credentials also end up in `typo3-credentials.txt` in the project folder.
