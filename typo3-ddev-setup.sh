#!/usr/bin/env bash
set -euo pipefail

# Bumped only as part of a GitHub release, not per commit - see CHANGELOG.md.
SCRIPT_VERSION="0.3.0"

# --- Defaults ---------------------------------------------------------------
T3_VERSION=""
PROJECT_NAME=""
BASE_PATH="."
ADMIN_USER="admin"
ADMIN_PASSWORD=""
ADMIN_EMAIL=""
CLEANUP=0
LIST=0
VERBOSE=0
COMPOSER_REQUIREMENTS=()
EXTENSION_PATHS=()
CLEANUP_TARGETS=()
CURRENT_OPTION=""

usage() {
  cat <<'EOF'
Usage: typo3-ddev-setup.sh --release=<version> [options]
       typo3-ddev-setup.sh --cleanup [--path=DIR]
       typo3-ddev-setup.sh --list [--path=DIR]

Options:
  -r=N, --release=N      TYPO3 version to install (currently supported major versions: 11, 12, 13, 14;
                          defaults to the highest supported version if omitted).
                          Pass just a major version (e.g. 12) to get the newest release on that
                          line, or pin an exact minor/patch release (e.g. 12.4 or 12.4.20). Pinning
                          an older patch release installs it even if Composer flags it as insecure -
                          see docs/versions.md.
  --name=NAME             DDEV project name (default: auto-generated, e.g. typo3-v12-a1b2)
  --path=DIR              Directory the project folder is created in / scanned in for --cleanup (default: current dir)
  --admin-user=USER       Backend admin username (default: admin)
  --admin-password=PASS   Backend admin password (default: randomly generated)
  --admin-email=MAIL      Backend admin email (default: admin@<project>.ddev.site)
  --require=PKG           Install an extra Composer package after setup. Repeat the flag or
                          list several packages after one occurrence, space-separated.
  --extension=PATH        Mount a local extension directory and require it at :@dev for
                          development (see docs/composer-packages.md). Same multi-value syntax
                          as --require.
  --c, --clear, --cleanup Interactively pick previously created instances and remove them completely
                          (Docker containers/volumes, DDEV project listing, hosts entry, project directory).
                          Optionally followed by one or more name/ID substrings to only consider
                          matching instances, e.g. --c 0392 to target the instance whose auto-generated
                          name ends in 0392 directly (skips the checklist if that's the only match).
  --list                  List all instances this script created (scans --path, non-interactive)
  -v, --verbose           Also write the full console output to verbose.log in the project
                          directory (chmod 600, like typo3-credentials.txt - it can contain
                          the admin password printed at the end of a run)
  -h, --help              Show this help
  --version               Show script version

See docs/ for detailed documentation on versions, backend users, Composer packages/extensions, and listing/cleanup.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --release=*|-r=*)
      CURRENT_OPTION=""
      T3_VERSION="${arg#*=}"
      ;;
    --name=*)
      CURRENT_OPTION=""
      PROJECT_NAME="${arg#*=}"
      ;;
    --path=*)
      CURRENT_OPTION=""
      BASE_PATH="${arg#*=}"
      ;;
    --admin-user=*)
      CURRENT_OPTION=""
      ADMIN_USER="${arg#*=}"
      ;;
    --admin-password=*)
      CURRENT_OPTION=""
      ADMIN_PASSWORD="${arg#*=}"
      ;;
    --admin-email=*)
      CURRENT_OPTION=""
      ADMIN_EMAIL="${arg#*=}"
      ;;
    --require=*)
      CURRENT_OPTION="require"
      COMPOSER_REQUIREMENTS+=("${arg#*=}")
      ;;
    --extension=*)
      CURRENT_OPTION="extension"
      EXTENSION_PATHS+=("${arg#*=}")
      ;;
    --cleanup|--clear|--c)
      CURRENT_OPTION="cleanup_target"
      CLEANUP=1
      ;;
    --list)
      CURRENT_OPTION=""
      LIST=1
      ;;
    -v|--verbose)
      CURRENT_OPTION=""
      VERBOSE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --version)
      echo "$SCRIPT_VERSION"
      exit 0
      ;;
    --*)
      echo "Unknown option: $arg" >&2
      usage
      exit 1
      ;;
    *)
      case "$CURRENT_OPTION" in
        require)
          COMPOSER_REQUIREMENTS+=("$arg")
          ;;
        extension)
          EXTENSION_PATHS+=("$arg")
          ;;
        cleanup_target)
          CLEANUP_TARGETS+=("$arg")
          ;;
        *)
          echo "Unexpected argument: $arg" >&2
          usage
          exit 1
          ;;
      esac
      ;;
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

PASSWORD_CHARS_UPPER='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
PASSWORD_CHARS_LOWER='abcdefghijklmnopqrstuvwxyz'
PASSWORD_CHARS_DIGIT='0123456789'
PASSWORD_CHARS_SPECIAL='#*%-_'
PASSWORD_CHARS="${PASSWORD_CHARS_UPPER}${PASSWORD_CHARS_LOWER}${PASSWORD_CHARS_DIGIT}${PASSWORD_CHARS_SPECIAL}"
generate_password() {
  local length=20
  local -a chars=()
  local i j tmp

  # TYPO3's default password policy requires at least one upper/lower/digit/special
  # character. A uniform draw over the full charset can miss a class by chance
  # (~20% odds of no special char in 20 draws) and TYPO3 then rejects it outright,
  # so guarantee one of each first and fill/shuffle the rest.
  chars+=("${PASSWORD_CHARS_UPPER:RANDOM % ${#PASSWORD_CHARS_UPPER}:1}")
  chars+=("${PASSWORD_CHARS_LOWER:RANDOM % ${#PASSWORD_CHARS_LOWER}:1}")
  chars+=("${PASSWORD_CHARS_DIGIT:RANDOM % ${#PASSWORD_CHARS_DIGIT}:1}")
  chars+=("${PASSWORD_CHARS_SPECIAL:RANDOM % ${#PASSWORD_CHARS_SPECIAL}:1}")
  for ((i = ${#chars[@]}; i < length; i++)); do
    chars+=("${PASSWORD_CHARS:RANDOM % ${#PASSWORD_CHARS}:1}")
  done

  for ((i = length - 1; i > 0; i--)); do
    j=$((RANDOM % (i + 1)))
    tmp="${chars[$i]}"
    chars[$i]="${chars[$j]}"
    chars[$j]="$tmp"
  done

  printf '%s' "${chars[@]}"
}

# Locks a file down like typo3-credentials.txt: not group/world-readable, and
# git-ignored if the project has a .gitignore. Used for anything that can end up
# containing the credentials printed at the end of a run.
secure_file() {
  chmod 600 "$1"
  if [[ -f .gitignore ]] && ! grep -qxF "$1" .gitignore; then
    echo "$1" >> .gitignore
  fi
}

# --- cleanup mode -------------------------------------------------------------
# Reads the exact TYPO3 core version out of composer.lock so the list shows
# e.g. "12.4.45" instead of just the major version encoded in the folder name.
get_typo3_version() {
  local lock="$1/composer.lock"
  local v=""
  if [[ -f "$lock" ]]; then
    v="$(grep -A2 '"name": *"typo3/cms-core"' "$lock" | grep '"version"' | head -1 | sed -E 's/.*"version": *"([^"]+)".*/\1/')"
    v="${v#v}" # composer.lock stores it as e.g. "v13.4.34" (git-tag style)
  fi
  echo "${v:-unknown}"
}

# Prints one "name<TAB>version" line per instance found under $1. Recognizes an
# instance by the markers this script always creates - not by folder name - so
# instances started with --name=custom are found too.
find_instances() {
  local scan_dir="$1"
  local dir name
  for dir in "$scan_dir"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ -f "$dir/.ddev/config.yaml" ]] || continue
    [[ -f "$dir/typo3-credentials.txt" ]] || continue
    printf '%s\t%s\n' "$name" "$(get_typo3_version "$dir")"
  done
}

run_list() {
  local scan_dir="${BASE_PATH%/}"
  [[ -d "$scan_dir" ]] || { echo "Error: '$scan_dir' does not exist." >&2; exit 1; }

  local -a NAMES=() VERSIONS=()
  local name version
  while IFS=$'\t' read -r name version; do
    NAMES+=("$name")
    VERSIONS+=("$version")
  done < <(find_instances "$scan_dir")

  if [[ ${#NAMES[@]} -eq 0 ]]; then
    echo "No typo3-ddev-setup instances found in '${scan_dir}'."
    exit 0
  fi

  local i
  for i in "${!NAMES[@]}"; do
    printf 'TYPO3 V%-10s %-24s https://%s.ddev.site\n' "${VERSIONS[$i]}" "${NAMES[$i]}" "${NAMES[$i]}"
  done
}

confirm() {
  local answer
  read -rp "$1 [y/N] " answer
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

abort() {
  echo "Aborted, nothing deleted."
  exit 0
}

# Runs the interactive multi-select checklist over the caller's ITEMS/NAMES
# arrays and appends the chosen names to the caller's TO_DELETE array (same
# dynamic-scoping convention as draw_menu/restore_tty below - all three expect
# the caller's locals, not their own copies). Called directly rather than via
# command/process substitution so 'q' can abort the whole script, not just a
# subshell. Requires a real terminal.
select_via_checklist() {
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
        abort
        ;;
    esac
    printf "\033[%dA" "$total"
    draw_menu
  done

  restore_tty
  trap - EXIT

  for i in "${!ITEMS[@]}"; do
    [[ "${SELECTED[$i]}" == "1" ]] && TO_DELETE+=("${NAMES[$i]}")
  done

  # Without this, a run where nothing got selected ends on a failed [[ ]] (the
  # last loop iteration), and under `set -e` a function call - unlike the same
  # loop written inline - aborts the whole script on that non-zero return.
  return 0
}

run_cleanup() {
  local scan_dir="${BASE_PATH%/}"
  [[ -d "$scan_dir" ]] || { echo "Error: '$scan_dir' does not exist." >&2; exit 1; }

  local -a NAMES=() ITEMS=()
  local name version
  while IFS=$'\t' read -r name version; do
    NAMES+=("$name")
    ITEMS+=("TYPO3 V${version} | ${name}")
  done < <(find_instances "$scan_dir")

  # If one or more targets were given (--c ID [ID...]), narrow down to instances
  # whose name contains any of them - e.g. the 4-char suffix of an auto-generated
  # name - instead of showing everything found under $scan_dir.
  if [[ ${#CLEANUP_TARGETS[@]} -gt 0 ]]; then
    local -a matched_names=() matched_items=()
    local target matched i
    for i in "${!NAMES[@]}"; do
      matched=0
      for target in "${CLEANUP_TARGETS[@]}"; do
        [[ "${NAMES[$i]}" == *"$target"* ]] && matched=1 && break
      done
      [[ "$matched" -eq 1 ]] && matched_names+=("${NAMES[$i]}") && matched_items+=("${ITEMS[$i]}")
    done
    NAMES=("${matched_names[@]}")
    ITEMS=("${matched_items[@]}")
  fi

  if [[ ${#NAMES[@]} -eq 0 ]]; then
    if [[ ${#CLEANUP_TARGETS[@]} -gt 0 ]]; then
      echo "No instance matching ${CLEANUP_TARGETS[*]} found in '${scan_dir}'."
    else
      echo "No typo3-ddev-setup instances found in '${scan_dir}'."
    fi
    exit 0
  fi

  if [[ ! -t 0 ]]; then
    echo "Error: --cleanup needs an interactive terminal (arrow keys / space / enter)." >&2
    exit 1
  fi

  local -a TO_DELETE=()

  # Only one candidate - no point showing a single-item checklist, just confirm it.
  if [[ ${#NAMES[@]} -eq 1 ]]; then
    echo "Found: ${ITEMS[0]}"
    confirm "Are you sure you want to remove it?" || abort
    TO_DELETE=("${NAMES[0]}")
  else
    select_via_checklist

    if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
      echo "Nothing selected, nothing deleted."
      exit 0
    fi

    echo "Are you sure you want to remove the following instances?"
    printf '  - %s\n' "${TO_DELETE[@]}"
    confirm "Proceed?" || abort
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

if [[ "$LIST" -eq 1 ]]; then
  run_list
  exit 0
fi

if [[ "$CLEANUP" -eq 1 ]]; then
  run_cleanup
  exit 0
fi

# --- Version map --------------------------------------------------------
# Ordered lowest to highest. Add further versions here once verified with this script.
SUPPORTED_VERSIONS=(11 12 13 14)

if [[ -z "$T3_VERSION" ]]; then
  T3_VERSION="${SUPPORTED_VERSIONS[${#SUPPORTED_VERSIONS[@]}-1]}"
  echo "==> No --release given, defaulting to highest supported version: ${T3_VERSION}"
fi

# Accept a bare major version (12), or a pinned minor/patch release (12.4, 12.4.20).
if [[ "$T3_VERSION" =~ ^([0-9]+)(\.[0-9]+){0,2}$ ]]; then
  T3_MAJOR="${BASH_REMATCH[1]}"
else
  echo "Error: '--release' must be a version like 12, 12.4 or 12.4.20." >&2
  exit 1
fi

case "$T3_MAJOR" in
  11) PHP_VERSION="8.1"; COMPOSER_CONSTRAINT="^11.5" ;;
  12) PHP_VERSION="8.2"; COMPOSER_CONSTRAINT="^12.4" ;;
  13) PHP_VERSION="8.3"; COMPOSER_CONSTRAINT="^13.4" ;;
  14) PHP_VERSION="8.4"; COMPOSER_CONSTRAINT="^14.3" ;;
  *)
    echo "Error: TYPO3 version '$T3_VERSION' is not supported yet (currently: ${SUPPORTED_VERSIONS[*]})." >&2
    exit 1
    ;;
esac

# typo3/cms-base-distribution itself only gets a handful of releases (it just bundles
# the real typo3/cms-* packages via "$COMPOSER_CONSTRAINT"), so it can't be pinned to
# an exact minor/patch version directly. If the user asked for one, install via the
# normal constraint first and pin every typo3/cms-* package afterwards (see below).
T3_PIN=""
if [[ "$T3_VERSION" != "$T3_MAJOR" ]]; then
  T3_PIN="$T3_VERSION"
fi

# --- Derived values --------------------------------------------------------
if [[ -z "$PROJECT_NAME" ]]; then
  SUFFIX="$(printf '%04x' "$RANDOM")"
  PROJECT_NAME="typo3-v${T3_MAJOR}-${SUFFIX}"
fi

if [[ -z "$ADMIN_PASSWORD" ]]; then
  ADMIN_PASSWORD="$(generate_password)"
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

if [[ "$VERBOSE" -eq 1 ]]; then
  # 'ddev composer create-project' refuses to run unless the project directory is
  # empty (bar a small whitelist), so the log can't live in there yet. Write it one
  # level up for now and move it in once composer is done - see below.
  VERBOSE_LOG_TMP="$(mktemp ../.verbose-log.XXXXXX)"
  exec > >(tee -a "$VERBOSE_LOG_TMP") 2>&1
  echo "==> Verbose logging enabled - full output also written to ${PROJECT_DIR}/verbose.log"
fi

# --- DDEV setup --------------------------------------------------------------
ddev config \
  --project-type=typo3 \
  --project-name="$PROJECT_NAME" \
  --docroot=public \
  --create-docroot \
  --php-version="$PHP_VERSION"

# --- Mount extension paths into docker ------------------------------------------
# EXTENSION_PATHS entries are already resolved to absolute paths and validated above.
if [[ ${#EXTENSION_PATHS[@]} -gt 0 ]]; then
    {
        echo "services:"
        echo "  web:"
        echo "    volumes:"

        for i in "${!EXTENSION_PATHS[@]}"; do
            echo "      - ${EXTENSION_PATHS[$i]}:/mnt/extension-${i}"
        done
    } > .ddev/docker-compose.extensions.yaml
fi

ddev start

# --- TYPO3 installation via composer ------------------------------------------
if [[ -z "$T3_PIN" ]]; then
  ddev composer create-project "typo3/cms-base-distribution:${COMPOSER_CONSTRAINT}" --no-interaction
else
  echo "==> Pinning all TYPO3 core packages to exact version ${T3_PIN}"
  ddev composer create-project "typo3/cms-base-distribution:${COMPOSER_CONSTRAINT}" --no-interaction --no-install
  # Literal (non-glob) replace: swap every "^X.Y" requirement for the pinned exact version.
  COMPOSER_JSON="$(cat composer.json)"
  COMPOSER_JSON="${COMPOSER_JSON//\"$COMPOSER_CONSTRAINT\"/\"$T3_PIN\"}"
  printf '%s\n' "$COMPOSER_JSON" > composer.json
  # Composer refuses by default to install versions flagged by security advisories,
  # which an intentionally pinned old patch release commonly is - that's expected here.
  echo "==> Installing with --no-security-blocking: an older pinned release may be flagged"
  echo "    by Composer's security-advisory check, and that block is bypassed on purpose here."
  ddev composer install --no-interaction --no-security-blocking
fi

if [[ "$VERBOSE" -eq 1 ]]; then
  VERBOSE_LOG="verbose.log"
  mv "$VERBOSE_LOG_TMP" "$VERBOSE_LOG"
fi

# --- Add mounted extension paths to composer.json packages ------------------------------------------
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
if [[ "$T3_MAJOR" -eq 11 ]]; then
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

# --- Trusted hosts pattern -------------------------------------------------------
# TYPO3's default trustedHostsPattern ('SERVER_NAME') requires SERVER_PORT to match
# the port implied by the HTTPS flag. DDEV's router terminates TLS and proxies to the
# web container over plain HTTP, so PHP sees HTTPS=on but SERVER_PORT=80 - a mismatch
# that makes every request 500 with "does not match the configured trusted hosts
# pattern". Allow all hosts instead; this is a disposable local instance, not exposed
# to the internet.
SETTINGS_FILE="config/system/settings.php"
if [[ -f "$SETTINGS_FILE" ]]; then
  SETTINGS_PHP="$(cat "$SETTINGS_FILE")"
  SEARCH="'SYS' => ["
  REPLACE="'SYS' => [
        'trustedHostsPattern' => '.*',"
  SETTINGS_PHP="${SETTINGS_PHP/$SEARCH/$REPLACE}"
  printf '%s\n' "$SETTINGS_PHP" > "$SETTINGS_FILE"
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

secure_file "$CREDENTIALS_FILE"

if [[ "$VERBOSE" -eq 1 ]]; then
  # verbose.log can contain the passwords printed below, same sensitivity as
  # typo3-credentials.txt - lock it down the same way.
  secure_file "$VERBOSE_LOG"
fi

echo
echo "==> Done."
echo "URL:         https://${PROJECT_NAME}.ddev.site"
echo "Backend:     https://${PROJECT_NAME}.ddev.site/typo3"
echo "Admin:       ${ADMIN_USER}"
echo "Password:    ${ADMIN_PASSWORD}"
echo "Credentials: ${PROJECT_DIR}/${CREDENTIALS_FILE}"
if [[ "$VERBOSE" -eq 1 ]]; then
  echo "Verbose log: ${PROJECT_DIR}/${VERBOSE_LOG}"
fi
echo "To clean up this instance: ./typo3-ddev-setup.sh --c ${SUFFIX:-$PROJECT_NAME}"

ddev launch /typo3 >/dev/null 2>&1 || echo "Note: could not auto-open the browser, open the backend URL above manually."
