#!/usr/bin/env bash
set -euo pipefail

# --- Defaults ---------------------------------------------------------------
T3_VERSION=""
PROJECT_NAME=""
BASE_PATH="."
ADMIN_USER="admin"
ADMIN_PASSWORD=""
ADMIN_EMAIL=""
CLEANUP=0
COMPOSER_REQUIREMENTS=()
EXTENSION_PATHS=()

usage() {
  cat <<'EOF'
Usage: typo3-ddev-setup.sh --v=<version> [options]
       typo3-ddev-setup.sh --cleanup [--path=DIR]

Options:
  --v=N                   TYPO3 major version to install (currently supported: 11, 12, 13, 14;
                          defaults to the highest supported version if omitted)
  --name=NAME             DDEV project name (default: auto-generated, e.g. typo3-v12-a1b2)
  --path=DIR              Directory the project folder is created in / scanned in for --cleanup (default: current dir)
  --admin-user=USER       Backend admin username (default: admin)
  --admin-password=PASS   Backend admin password (default: randomly generated)
  --admin-email=MAIL      Backend admin email (default: admin@<project>.ddev.site)
  --cleanup               Interactively pick previously created instances and remove them completely
                          (Docker containers/volumes, DDEV project listing, hosts entry, project directory)
  -h, --help              Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --v=*) T3_VERSION="${arg#*=}" ;;
    --name=*) PROJECT_NAME="${arg#*=}" ;;
    --path=*) BASE_PATH="${arg#*=}" ;;
    --admin-user=*) ADMIN_USER="${arg#*=}" ;;
    --admin-password=*) ADMIN_PASSWORD="${arg#*=}" ;;
    --admin-email=*) ADMIN_EMAIL="${arg#*=}" ;;
    --require=*) COMPOSER_REQUIREMENTS+=("${arg#*=}") ;;
    --extension=*) EXTENSION_PATHS+=("${arg#*=}") ;;
    --cleanup) CLEANUP=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 1 ;;
  esac
done

# --- check if extension paths exist ------------------------------------------
for i in "${!EXTENSION_PATHS[@]}"; do
  EXTENSION_PATHS[$i]="$(realpath "${EXTENSION_PATHS[$i]}")"

  if [[ ! -d "${EXTENSION_PATHS[$i]}" ]]; then
    echo "Extension path does not exist: ${EXTENSION_PATHS[$i]}" >&2
    exit 1
  fi

  if [[ ! -f "${EXTENSION_PATHS[$i]}/composer.json" ]]; then
    echo "Extension does not contain a composer.json: ${EXTENSION_PATHS[$i]}" >&2
    exit 1
  fi
done

command -v docker >/dev/null 2>&1 || { echo "Error: docker is not installed or not in PATH." >&2; exit 1; }
command -v ddev >/dev/null 2>&1 || { echo "Error: ddev is not installed or not in PATH." >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "Error: docker daemon is not running." >&2; exit 1; }

# --- cleanup mode -------------------------------------------------------------
# Reads the exact TYPO3 core version out of composer.lock so the list shows
# e.g. "12.4.45" instead of just the major version encoded in the folder name.
get_typo3_version() {
  local lock="$1/composer.lock"
  local v=""
  if [[ -f "$lock" ]]; then
    v="$(grep -A2 '"name": *"typo3/cms-core"' "$lock" | grep '"version"' | head -1 | sed -E 's/.*"version": *"([^"]+)".*/\1/')"
  fi
  echo "${v:-unknown}"
}

run_cleanup() {
  local scan_dir="${BASE_PATH%/}"
  [[ -d "$scan_dir" ]] || { echo "Error: '$scan_dir' does not exist." >&2; exit 1; }

  local -a NAMES=() ITEMS=()
  local dir name version

  for dir in "$scan_dir"/typo3-v*-*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ "$name" =~ ^typo3-v[0-9]+-[0-9a-f]{4}$ ]] || continue
    [[ -f "$dir/.ddev/config.yaml" ]] || continue
    version="$(get_typo3_version "$dir")"
    NAMES+=("$name")
    ITEMS+=("TYPO3 V${version} | ${name}")
  done

  if [[ ${#NAMES[@]} -eq 0 ]]; then
    echo "No typo3-ddev-setup instances found in '${scan_dir}'."
    exit 0
  fi

  if [[ ! -t 0 ]]; then
    echo "Error: --cleanup needs an interactive terminal (arrow keys / space / enter)." >&2
    exit 1
  fi

  local total=${#ITEMS[@]}
  local -a SELECTED=()
  local i CURSOR=0
  for i in "${!ITEMS[@]}"; do SELECTED[$i]=0; done

  draw_menu() {
    local j marker prefix
    for j in "${!ITEMS[@]}"; do
      marker=" "
      [[ "${SELECTED[$j]}" == "1" ]] && marker="x"
      prefix="  "
      [[ $j -eq $CURSOR ]] && prefix="> "
      printf "\033[K%s[%s] %s\n" "$prefix" "$marker" "${ITEMS[$j]}"
    done
  }

  echo "Select instances to delete (Up/Down move, Space toggle, Enter confirm, q abort):"
  draw_menu

  local old_stty
  old_stty="$(stty -g)"
  restore_tty() { stty "$old_stty" 2>/dev/null || true; tput cnorm 2>/dev/null || true; }
  trap restore_tty EXIT
  stty -icanon -echo min 1 time 0
  tput civis 2>/dev/null || true

  local key rest
  while true; do
    IFS= read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
      IFS= read -rsn2 -t 0.05 rest || true
      key+="$rest"
    fi
    case "$key" in
      $'\x1b[A')
        ((CURSOR--)) || true
        ((CURSOR < 0)) && CURSOR=$((total - 1))
        ;;
      $'\x1b[B')
        ((CURSOR++)) || true
        ((CURSOR >= total)) && CURSOR=0
        ;;
      ' ')
        if [[ "${SELECTED[$CURSOR]}" == "1" ]]; then SELECTED[$CURSOR]=0; else SELECTED[$CURSOR]=1; fi
        ;;
      ""|$'\n'|$'\r')
        break
        ;;
      q|Q)
        restore_tty
        trap - EXIT
        echo "Aborted, nothing deleted."
        exit 0
        ;;
    esac
    printf "\033[%dA" "$total"
    draw_menu
  done

  restore_tty
  trap - EXIT

  local -a TO_DELETE=()
  for i in "${!ITEMS[@]}"; do
    [[ "${SELECTED[$i]}" == "1" ]] && TO_DELETE+=("${NAMES[$i]}")
  done

  if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
    echo "Nothing selected, nothing deleted."
    exit 0
  fi

  echo
  local proj
  for proj in "${TO_DELETE[@]}"; do
    echo "==> Removing DDEV project (containers, volumes, DB, hosts entry): ${proj}"
    if ddev delete -Oy "$proj"; then
      echo "==> Removing project directory: ${scan_dir}/${proj}"
      rm -rf "${scan_dir:?}/${proj:?}"
    else
      echo "Warning: 'ddev delete' failed for ${proj} - directory left in place, check manually." >&2
    fi
  done

  echo "Cleanup done."
}

if [[ "$CLEANUP" -eq 1 ]]; then
  run_cleanup
  exit 0
fi

# --- Version map --------------------------------------------------------
# Ordered lowest to highest. Add further versions here once verified with this script.
SUPPORTED_VERSIONS=(11 12 13 14)

if [[ -z "$T3_VERSION" ]]; then
  T3_VERSION="${SUPPORTED_VERSIONS[${#SUPPORTED_VERSIONS[@]}-1]}"
  echo "==> No --v given, defaulting to highest supported version: ${T3_VERSION}"
fi

case "$T3_VERSION" in
  11)
    PHP_VERSION="8.1"
    COMPOSER_CONSTRAINT="^11.5"
    ;;
  12)
    PHP_VERSION="8.2"
    COMPOSER_CONSTRAINT="^12.4"
    ;;
  13)
    PHP_VERSION="8.3"
    COMPOSER_CONSTRAINT="^13.4"
    ;;
  14)
    PHP_VERSION="8.4"
    COMPOSER_CONSTRAINT="^14.3"
    ;;
  *)
    echo "Error: TYPO3 version '$T3_VERSION' is not supported yet (currently: ${SUPPORTED_VERSIONS[*]})." >&2
    exit 1
    ;;
esac

# --- Derived values --------------------------------------------------------
if [[ -z "$PROJECT_NAME" ]]; then
  SUFFIX="$(printf '%04x' "$RANDOM")"
  PROJECT_NAME="typo3-v${T3_VERSION}-${SUFFIX}"
fi

if [[ -z "$ADMIN_PASSWORD" ]]; then
  ADMIN_PASSWORD="Ddev-$(( RANDOM * 32768 + RANDOM ))-Aa1"
fi

if [[ -z "$ADMIN_EMAIL" ]]; then
  ADMIN_EMAIL="admin@${PROJECT_NAME}.ddev.site"
fi

PROJECT_DIR="${BASE_PATH%/}/${PROJECT_NAME}"

if [[ -e "$PROJECT_DIR" ]]; then
  echo "Error: directory '$PROJECT_DIR' already exists." >&2
  exit 1
fi

echo "==> Creating TYPO3 ${T3_VERSION} project '${PROJECT_NAME}' in ${PROJECT_DIR}"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# --- DDEV setup --------------------------------------------------------------
ddev config \
  --project-type=typo3 \
  --project-name="$PROJECT_NAME" \
  --docroot=public \
  --create-docroot \
  --php-version="$PHP_VERSION"

# --- Mount extension paths into docker ------------------------------------------
if [[ ${#EXTENSION_PATHS[@]} -gt 0 ]]; then
    {
        echo "services:"
        echo "  web:"
        echo "    volumes:"

        for i in "${!EXTENSION_PATHS[@]}"; do
            extension_path="$(realpath "${EXTENSION_PATHS[$i]}")"

            if [[ ! -d "$extension_path" ]]; then
                echo "Extension path does not exist: $extension_path" >&2
                exit 1
            fi

            if [[ ! -f "$extension_path/composer.json" ]]; then
                echo "Extension does not contain a composer.json: $extension_path" >&2
                exit 1
            fi

            echo "      - ${extension_path}:/mnt/extension-${i}"
        done
    } > .ddev/docker-compose.extensions.yaml
fi

ddev start

# --- TYPO3 installation via composer ------------------------------------------
ddev composer create-project "typo3/cms-base-distribution:${COMPOSER_CONSTRAINT}" --no-interaction

# --- Add mounted extension paths to composer.json packages ------------------------------------------
#debug: check mounted paths
#for i in "${!EXTENSION_PATHS[@]}"; do
#    echo "==> Mounting extension: ${EXTENSION_PATHS[$i]}"
#    echo "      ${EXTENSION_PATHS[$i]}:/mnt/extension-${i}"
#    echo "      - ${EXTENSION_PATHS[$i]}:/mnt/extension-${i}"
#done

for i in "${!EXTENSION_PATHS[@]}"; do
    mount_path="/mnt/extension-${i}"

    package_name="$(
        ddev exec --raw php -r '
            $composer = json_decode(
                file_get_contents($argv[1]),
                true
            );

            echo $composer["name"] ?? "";
        ' "${mount_path}/composer.json"
    )"

    if [[ -z "$package_name" ]]; then
        echo "Could not determine Composer package name for ${EXTENSION_PATHS[$i]}" >&2
        exit 1
    fi

    ddev composer config "repositories.local-extension-${i}" path "$mount_path"
    ddev composer require "$package_name:@dev" --no-interaction
done

# --- Additional composer packages ------------------------------------------
if [[ ${#COMPOSER_REQUIREMENTS[@]} -gt 0 ]]; then
  echo "==> Installing additional Composer requirements:"
  printf '    - %s\n' "${COMPOSER_REQUIREMENTS[@]}"

  ddev composer require \
    "${COMPOSER_REQUIREMENTS[@]}" \
    --no-interaction
fi

# --- TYPO3 setup (database + admin user + site) -------------------------------
if [[ "$T3_VERSION" -eq 11 ]]; then
  # TYPO3 v11's native `typo3 setup` command crashes on fresh CLI installs
  # (GeneralUtility::$container is null when DataHandler touches the reference
  # index while creating the admin user - see https://forge.typo3.org/issues/105452).
  # v11 is EOL and this was closed as won't-fix, so use the legacy typo3-console
  # installer instead, which doesn't have this bug.
  ddev exec ./vendor/bin/typo3cms --no-ansi --no-interaction install:setup \
    --force \
    --database-driver=mysqli \
    --database-user-name=db \
    --database-user-password=db \
    --database-host-name=db \
    --database-port=3306 \
    --database-name=db \
    --use-existing-database \
    --admin-user-name="$ADMIN_USER" \
    --admin-password="$ADMIN_PASSWORD" \
    --site-name="$PROJECT_NAME" \
    --site-setup-type=site \
    --site-base-url="https://${PROJECT_NAME}.ddev.site/"
  # install:setup has no --admin-email flag, so set it separately.
  ADMIN_EMAIL_ESCAPED="${ADMIN_EMAIL//\'/\'\'}"
  ADMIN_USER_ESCAPED="${ADMIN_USER//\'/\'\'}"
  ddev mysql -e "UPDATE be_users SET email='${ADMIN_EMAIL_ESCAPED}' WHERE username='${ADMIN_USER_ESCAPED}';"
else
  ddev exec ./vendor/bin/typo3 setup \
    --driver=mysqli \
    --host=db \
    --port=3306 \
    --dbname=db \
    --username=db \
    --password=db \
    --admin-username="$ADMIN_USER" \
    --admin-user-password="$ADMIN_PASSWORD" \
    --admin-email="$ADMIN_EMAIL" \
    --project-name="$PROJECT_NAME" \
    --server-type=other \
    --create-site="https://${PROJECT_NAME}.ddev.site/" \
    --no-interaction \
    --force
fi

# --- Credentials file ---------------------------------------------------------
# Written at the project root (outside the "public" docroot) so it's never web-accessible.
CREDENTIALS_FILE="typo3-credentials.txt"
cat > "$CREDENTIALS_FILE" <<CREDS
TYPO3 ${T3_VERSION} - ${PROJECT_NAME}
Created: $(date '+%Y-%m-%d %H:%M:%S')

Frontend: https://${PROJECT_NAME}.ddev.site/
Backend:  https://${PROJECT_NAME}.ddev.site/typo3

Admin user:     ${ADMIN_USER}
Admin password: ${ADMIN_PASSWORD}
Admin email:    ${ADMIN_EMAIL}
CREDS
chmod 600 "$CREDENTIALS_FILE"

if [[ -f .gitignore ]] && ! grep -qxF "$CREDENTIALS_FILE" .gitignore; then
  echo "$CREDENTIALS_FILE" >> .gitignore
fi

echo
echo "==> Done."
echo "URL:         https://${PROJECT_NAME}.ddev.site"
echo "Backend:     https://${PROJECT_NAME}.ddev.site/typo3"
echo "Admin:       ${ADMIN_USER}"
echo "Password:    ${ADMIN_PASSWORD}"
echo "Credentials: ${PROJECT_DIR}/${CREDENTIALS_FILE}"

ddev launch /typo3 >/dev/null 2>&1 || echo "Note: could not auto-open the browser, open the backend URL above manually."
