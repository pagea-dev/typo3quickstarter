#!/usr/bin/env bash
set -euo pipefail

# Bumped only as part of a GitHub release, not per commit - see CHANGELOG.md.
SCRIPT_VERSION="0.5.0"

# --- Colors -------------------------------------------------------------------
# Whether stdout is a real terminal, captured now - before --verbose (parsed
# below) later wraps it in a `tee` pipe, which would always fail this check.
# The actual C_* variables are set further down, once --verbose is known.
IS_TTY=0
[[ -t 1 ]] && IS_TTY=1

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
WITH_GIT=0
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
                          --c all targets every instance found under --path: skips the checklist
                          and asks once to confirm removing all of them.
  --list                  List all instances this script created (scans --path, non-interactive)
  -v, --verbose           Also write the full console output to verbose.log in the project
                          directory (chmod 600, like typo3-credentials.txt - it can contain
                          the admin password printed at the end of a run)
  --with-git              After setup, ask (needs an interactive terminal) whether to put the
                          whole project under git version control, or scaffold a brand-new
                          extension under packages/<name> and version that alone instead.
                          See docs/with-git.md.
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
    --with-git)
      CURRENT_OPTION=""
      WITH_GIT=1
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
      echo "${C_RED}Unknown option: $arg${C_RESET}" >&2
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
          echo "${C_RED}Unexpected argument: $arg${C_RESET}" >&2
          usage
          exit 1
          ;;
      esac
      ;;
  esac
done

# Colors stay off entirely under --verbose, so escape codes never end up in
# verbose.log - the `tee` pipe it wraps stdout in would force every later
# `-t 1` check to fail anyway, silently losing color from the live terminal too.
if [[ "$IS_TTY" -eq 1 ]] && [[ "$VERBOSE" -eq 0 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_CYAN=$'\033[36m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
else
  C_RESET="" C_BOLD="" C_CYAN="" C_GREEN="" C_YELLOW="" C_RED=""
fi

# --- check if extension paths exist ------------------------------------------
for i in "${!EXTENSION_PATHS[@]}"; do
  EXTENSION_PATHS[$i]="$(realpath "${EXTENSION_PATHS[$i]}")"

  if [[ ! -d "${EXTENSION_PATHS[$i]}" ]]; then
    echo "${C_RED}Extension path does not exist: ${EXTENSION_PATHS[$i]}${C_RESET}" >&2
    exit 1
  fi

  if [[ ! -f "${EXTENSION_PATHS[$i]}/composer.json" ]]; then
    echo "${C_RED}Extension does not contain a composer.json: ${EXTENSION_PATHS[$i]}${C_RESET}" >&2
    exit 1
  fi
done

command -v docker >/dev/null 2>&1 || { echo "${C_RED}Error: docker is not installed or not in PATH.${C_RESET}" >&2; exit 1; }
command -v ddev >/dev/null 2>&1 || { echo "${C_RED}Error: ddev is not installed or not in PATH.${C_RESET}" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "${C_RED}Error: docker daemon is not running.${C_RESET}" >&2; exit 1; }
if [[ "$WITH_GIT" -eq 1 ]]; then
  command -v git >/dev/null 2>&1 || { echo "${C_RED}Error: --with-git needs git, which is not installed or not in PATH.${C_RESET}" >&2; exit 1; }
  [[ -t 0 ]] || { echo "${C_RED}Error: --with-git needs an interactive terminal to ask what to version.${C_RESET}" >&2; exit 1; }
fi

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
# instances started with --name=custom are found too. The setup marker is
# written right after "ddev config", before anything that could still fail,
# so a run that dies partway (Composer, TYPO3 setup, ...) is still found here
# instead of leaving an orphaned DDEV project outside the tool's reach -
# typo3-credentials.txt alone only proves the run finished successfully. The
# project-root marker path is still accepted for instances created with 0.4.0,
# which wrote it there before it moved into .ddev/.
find_instances() {
  local scan_dir="$1"
  local dir name
  for dir in "$scan_dir"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ -f "$dir/.ddev/config.yaml" ]] || continue
    [[ -f "$dir/.ddev/.typo3-ddev-setup-marker" || -f "$dir/.typo3-ddev-setup-marker" || -f "$dir/typo3-credentials.txt" ]] || continue
    printf '%s\t%s\n' "$name" "$(get_typo3_version "$dir")"
  done
}

run_list() {
  local scan_dir="${BASE_PATH%/}"
  [[ -d "$scan_dir" ]] || { echo "${C_RED}Error: '$scan_dir' does not exist.${C_RESET}" >&2; exit 1; }

  local -a NAMES=() VERSIONS=()
  local name version
  while IFS=$'\t' read -r name version; do
    NAMES+=("$name")
    VERSIONS+=("$version")
  done < <(find_instances "$scan_dir")

  if [[ ${#NAMES[@]} -eq 0 ]]; then
    echo "${C_YELLOW}No typo3-ddev-setup instances found in '${scan_dir}'.${C_RESET}"
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

# Like confirm(), but only the word "yes" written out in full counts as a yes -
# a bare "y" does not. Used before deleting an instance that has a .git
# directory in it, so an accidental keystroke can't wipe out real work.
confirm_exact_yes() {
  local answer
  read -rp "$1 " answer
  [[ "$answer" =~ ^[Yy][Ee][Ss]$ ]]
}

abort() {
  echo "${C_YELLOW}Aborted, nothing deleted.${C_RESET}"
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

  echo "${C_CYAN}Select instances to delete (Up/Down move, Space toggle, Enter confirm, q abort):${C_RESET}"
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
  [[ -d "$scan_dir" ]] || { echo "${C_RED}Error: '$scan_dir' does not exist.${C_RESET}" >&2; exit 1; }

  local -a NAMES=() ITEMS=()
  local name version
  while IFS=$'\t' read -r name version; do
    NAMES+=("$name")
    ITEMS+=("TYPO3 V${version} | ${name}")
  done < <(find_instances "$scan_dir")

  # "all" (used alone) means every instance found under $scan_dir - skips the
  # substring filter below entirely, so it can't accidentally be narrowed by an
  # instance that happens to have "all" in its name.
  local ALL_TARGET=0
  if [[ ${#CLEANUP_TARGETS[@]} -eq 1 ]] && [[ "${CLEANUP_TARGETS[0]}" == "all" ]]; then
    ALL_TARGET=1
  # Otherwise, if one or more targets were given (--c ID [ID...]), narrow down to
  # instances whose name contains any of them - e.g. the 4-char suffix of an
  # auto-generated name - instead of showing everything found under $scan_dir.
  elif [[ ${#CLEANUP_TARGETS[@]} -gt 0 ]]; then
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
      echo "${C_YELLOW}No instance matching ${CLEANUP_TARGETS[*]} found in '${scan_dir}'.${C_RESET}"
    else
      echo "${C_YELLOW}No typo3-ddev-setup instances found in '${scan_dir}'.${C_RESET}"
    fi
    exit 0
  fi

  if [[ ! -t 0 ]]; then
    echo "${C_RED}Error: --cleanup needs an interactive terminal (arrow keys / space / enter).${C_RESET}" >&2
    exit 1
  fi

  local -a TO_DELETE=()

  # "all" skips the checklist entirely and goes straight to one confirmation
  # listing every instance that would be removed.
  if [[ "$ALL_TARGET" -eq 1 ]]; then
    TO_DELETE=("${NAMES[@]}")
    echo "${C_YELLOW}Are you sure you want to remove ALL of the following instances?${C_RESET}"
    printf '  - %s\n' "${ITEMS[@]}"
    confirm "${C_YELLOW}Proceed?${C_RESET}" || abort
  # Only one candidate - no point showing a single-item checklist, just confirm it.
  elif [[ ${#NAMES[@]} -eq 1 ]]; then
    echo "Found: ${ITEMS[0]}"
    confirm "${C_YELLOW}Are you sure you want to remove it?${C_RESET}" || abort
    TO_DELETE=("${NAMES[0]}")
  else
    select_via_checklist

    if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
      echo "${C_YELLOW}Nothing selected, nothing deleted.${C_RESET}"
      exit 0
    fi

    echo "${C_YELLOW}Are you sure you want to remove the following instances?${C_RESET}"
    printf '  - %s\n' "${TO_DELETE[@]}"
    confirm "${C_YELLOW}Proceed?${C_RESET}" || abort
  fi

  echo
  local proj
  for proj in "${TO_DELETE[@]}"; do
    # A .git directory anywhere inside means real, version-controlled work
    # could be sitting in there (--with-git, or something unrelated entirely) -
    # deleting the project directory would wipe it out unrecoverably, so this
    # needs a harder, deliberate confirmation than the one already given above.
    if find "${scan_dir}/${proj}" -type d -name .git -print -quit 2>/dev/null | grep -q .; then
      echo "${C_RED}${C_BOLD}WARNING: found a .git directory inside ${proj} - there's version-controlled work in there that would be permanently lost.${C_RESET}"
      if ! confirm_exact_yes "${C_RED}Type 'yes' (not just 'y') to delete ${proj} anyway - this cannot be undone:${C_RESET}"; then
        echo "${C_YELLOW}Skipping ${proj}.${C_RESET}"
        continue
      fi
    fi

    echo "${C_CYAN}==> Removing DDEV project (containers, volumes, DB, hosts entry): ${proj}${C_RESET}"
    if ddev delete -Oy "$proj"; then
      echo "${C_CYAN}==> Removing project directory: ${scan_dir}/${proj}${C_RESET}"
      rm -rf "${scan_dir:?}/${proj:?}"
    else
      echo "${C_YELLOW}Warning: 'ddev delete' failed for ${proj} - directory left in place, check manually.${C_RESET}" >&2
    fi
  done

  echo "${C_GREEN}Cleanup done.${C_RESET}"
}

if [[ "$LIST" -eq 1 ]]; then
  run_list
  exit 0
fi

if [[ "$CLEANUP" -eq 1 ]]; then
  run_cleanup
  exit 0
fi

echo "${C_BOLD}${C_CYAN}typo3quickstarter${C_RESET} ${C_GREEN}v${SCRIPT_VERSION}${C_RESET} ${C_YELLOW}by Pagea Development${C_RESET}"
echo "${C_CYAN}https://github.com/pagea-dev/typo3quickstarter${C_RESET} · ${C_CYAN}https://pagea.dev/${C_RESET}"
echo

# --- Version map --------------------------------------------------------
# Ordered lowest to highest. Add further versions here once verified with this script.
SUPPORTED_VERSIONS=(11 12 13 14)

if [[ -z "$T3_VERSION" ]]; then
  T3_VERSION="${SUPPORTED_VERSIONS[${#SUPPORTED_VERSIONS[@]}-1]}"
  echo "${C_CYAN}==> No --release given, defaulting to highest supported version: ${T3_VERSION}${C_RESET}"
fi

# Accept a bare major version (12), or a pinned minor/patch release (12.4, 12.4.20).
if [[ "$T3_VERSION" =~ ^([0-9]+)(\.[0-9]+){0,2}$ ]]; then
  T3_MAJOR="${BASH_REMATCH[1]}"
else
  echo "${C_RED}Error: '--release' must be a version like 12, 12.4 or 12.4.20.${C_RESET}" >&2
  exit 1
fi

case "$T3_MAJOR" in
  11) PHP_VERSION="8.1"; COMPOSER_CONSTRAINT="^11.5" ;;
  12) PHP_VERSION="8.2"; COMPOSER_CONSTRAINT="^12.4" ;;
  13) PHP_VERSION="8.3"; COMPOSER_CONSTRAINT="^13.4" ;;
  14) PHP_VERSION="8.4"; COMPOSER_CONSTRAINT="^14.3" ;;
  *)
    echo "${C_RED}Error: TYPO3 version '$T3_VERSION' is not supported yet (currently: ${SUPPORTED_VERSIONS[*]}).${C_RESET}" >&2
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
  echo "${C_RED}Error: directory '$PROJECT_DIR' already exists.${C_RESET}" >&2
  exit 1
fi

echo "${C_CYAN}==> Creating TYPO3 ${T3_VERSION} project '${PROJECT_NAME}' in ${PROJECT_DIR}${C_RESET}"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

if [[ "$VERBOSE" -eq 1 ]]; then
  # 'ddev composer create-project' refuses to run unless the project directory is
  # empty (bar a small whitelist), so the log can't live in there yet. Write it one
  # level up for now and move it in once composer is done - see below.
  VERBOSE_LOG_TMP="$(mktemp ../.verbose-log.XXXXXX)"
  exec > >(tee -a "$VERBOSE_LOG_TMP") 2>&1
  echo "${C_CYAN}==> Verbose logging enabled - full output also written to ${PROJECT_DIR}/verbose.log${C_RESET}"
fi

# --- DDEV setup --------------------------------------------------------------
# TYPO3_CONTEXT=Development: these are disposable local instances, never anything
# running under Production - Development context relaxes error output, disables
# production-only caches, and is what the debug settings further down expect.
ddev config \
  --project-type=typo3 \
  --project-name="$PROJECT_NAME" \
  --docroot=public \
  --create-docroot \
  --php-version="$PHP_VERSION" \
  --web-environment-add="TYPO3_CONTEXT=Development"

# Written as early as possible, before anything that could still fail (Composer,
# TYPO3 setup, ...) - --list/--cleanup key off this, not typo3-credentials.txt
# alone, so a run that dies partway still leaves a project --cleanup can find
# and remove instead of an orphaned DDEV project stuck outside the tool's reach.
# It lives inside .ddev/ on purpose: 'ddev composer create-project' below refuses
# to run on a project directory containing anything outside a small whitelist,
# and .ddev/ is one of the few directories it skips over entirely.
touch .ddev/.typo3-ddev-setup-marker

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

# --- Database collation -------------------------------------------------------
# DDEV's db-container init creates the database with an explicit "CHARACTER SET
# utf8mb4" and no COLLATE, which picks MariaDB/MySQL's built-in default for that
# charset (utf8mb4_general_ci) - setting collation-server in a custom my.cnf has
# no effect here, since that only applies when a CREATE DATABASE/TABLE statement
# omits the charset too. TYPO3 configures utf8mb4_unicode_ci for all its tables,
# so every column not explicitly set otherwise permanently shows up as a pending
# "CHANGE COLUMN" diff in the backend's Database Analyzer - which no CLI command
# can apply (extension:setup only adds, never changes). Match the collation new
# tables inherit by default before any get created.
ddev mysql -e "ALTER DATABASE db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# --- TYPO3 installation via composer ------------------------------------------
# Composer refuses by default to install any package version flagged by a known
# security advisory - increasingly likely to hit even a plain, unpinned install,
# since some package in a TYPO3 release line is pretty much always affected by
# something at any given time. These are disposable local test instances, never
# anything running in production, so that block is bypassed throughout on purpose
# (also needed to intentionally reproduce a bug against an old pinned release).
echo "${C_CYAN}==> Installing with --no-security-blocking: disposable test instances, not production${C_RESET}"

# Scaffold the base distribution's composer.json without installing yet, so the
# extra core packages below (and the version pin, if any) land in the same single
# install/lock-solve instead of a separate one after the fact.
ddev composer create-project "typo3/cms-base-distribution:${COMPOSER_CONSTRAINT}" --no-interaction --no-install

# typo3/cms-extensionmanager already ships with the base distribution - required
# again explicitly so it keeps working the same way even if that ever changes.
# typo3/cms-scheduler doesn't ship by default and is added for the same reason:
# a disposable test instance is a lot more useful with the Scheduler module and
# a working Extensions module available out of the box.
ddev composer require \
  "typo3/cms-scheduler:${COMPOSER_CONSTRAINT}" \
  "typo3/cms-extensionmanager:${COMPOSER_CONSTRAINT}" \
  --no-interaction --no-install --no-security-blocking

if [[ -z "$T3_PIN" ]]; then
  ddev composer install --no-interaction --no-security-blocking
else
  echo "${C_CYAN}==> Pinning all TYPO3 core packages to exact version ${T3_PIN}${C_RESET}"
  # Literal (non-glob) replace: swap every "^X.Y" requirement for the pinned exact version.
  COMPOSER_JSON="$(cat composer.json)"
  COMPOSER_JSON="${COMPOSER_JSON//\"$COMPOSER_CONSTRAINT\"/\"$T3_PIN\"}"
  printf '%s\n' "$COMPOSER_JSON" > composer.json
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
        echo "${C_RED}Could not determine Composer package name for ${EXTENSION_PATHS[$i]}${C_RESET}" >&2
        exit 1
    fi

    ddev composer config "repositories.local-extension-${i}" path "$mount_path"
    ddev composer require "$package_name:@dev" --no-interaction --no-security-blocking
done

# --- Additional composer packages ------------------------------------------
if [[ ${#COMPOSER_REQUIREMENTS[@]} -gt 0 ]]; then
  echo "${C_CYAN}==> Installing additional Composer requirements:${C_RESET}"
  printf '    - %s\n' "${COMPOSER_REQUIREMENTS[@]}"

  ddev composer require \
    "${COMPOSER_REQUIREMENTS[@]}" \
    --no-interaction --no-security-blocking
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

# --- Extension setup (database schema update + cache flush) -------------------
# Required after composer-requiring extensions above: their DB tables don't exist yet
# and TYPO3 won't pick up ext_localconf/ext_tables changes until caches are cleared.
ddev exec ./vendor/bin/typo3 extension:setup --no-interaction

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

# --- Debug settings ---------------------------------------------------------
# Same reasoning as TYPO3_CONTEXT=Development above: this is a disposable local
# instance, so trade production-safe defaults for maximum visibility into what's
# actually happening. Rewrites via PHP (not a string search/replace like above)
# since 'BE'/'FE' aren't guaranteed to already be top-level keys in settings.php.
if [[ -f "$SETTINGS_FILE" ]]; then
  ddev exec --raw php -r '
      $file = $argv[1];
      $config = require $file;
      $config["BE"]["debug"] = true;
      $config["FE"]["debug"] = true;
      // Empty string disables TYPO3'"'"'s own exception handling entirely, so
      // PHP'"'"'s raw error output/stack trace shows instead.
      $config["SYS"]["debugExceptionHandler"] = "";
      file_put_contents($file, "<?php\nreturn " . var_export($config, true) . ";\n");
  ' "$SETTINGS_FILE"
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

# --- --with-git: optional version control setup -------------------------------
if [[ "$WITH_GIT" -eq 1 ]]; then
  echo
  echo "${C_CYAN}==> --with-git: what should be put under version control?${C_RESET}"
  echo "  1) The whole TYPO3 project"
  echo "  2) A new extension only (scaffolded fresh under packages/<name>)"
  GIT_CHOICE=""
  read -rp "Choice [1/2]: " GIT_CHOICE

  if [[ "$GIT_CHOICE" == "1" ]]; then
    echo "${C_CYAN}==> Initializing git for the whole project${C_RESET}"
    git init >/dev/null
    # typo3/cms-base-distribution already ships a .gitignore covering vendor/,
    # var/ (except var/labels), and most of public/ - append what it doesn't:
    # DDEV's own project config, credentials/logs, and settings.php (DB password,
    # encryptionKey in plaintext). packages/ is deliberately left trackable.
    {
      echo ""
      echo "# Added by typo3-ddev-setup.sh --with-git"
      echo "/.ddev/" # also covers .ddev/.typo3-ddev-setup-marker
      echo "/${CREDENTIALS_FILE}"
      echo "/verbose.log"
      echo "/${SETTINGS_FILE}"
    } >> .gitignore
    git add -A
    if git commit -m "Initial commit" >/dev/null 2>&1; then
      echo "${C_GREEN}Git repository initialized and committed at ${PROJECT_DIR}${C_RESET}"
    else
      echo "${C_YELLOW}Git repository initialized, but the initial commit failed - configure git's user.name/user.email if you want one. Changes are staged.${C_RESET}"
    fi
  elif [[ "$GIT_CHOICE" == "2" ]]; then
    # friendsoftypo3/kickstarter has no TYPO3 11 release (0.1.x targets ^12.4.8,
    # up to 0.4.x/main targeting ^14) - see https://github.com/FriendsOfTYPO3/kickstarter.
    if [[ "$T3_MAJOR" -eq 11 ]]; then
      echo "${C_YELLOW}--with-git: the TYPO3 extension kickstarter needs TYPO3 12+ (this instance is TYPO3 11), skipping.${C_RESET}"
    else
      echo "${C_CYAN}==> Installing friendsoftypo3/kickstarter (dev dependency)${C_RESET}"
      if ddev composer require --dev friendsoftypo3/kickstarter --no-interaction --no-security-blocking; then
        ddev exec ./vendor/bin/typo3 extension:setup --no-interaction

        mkdir -p packages
        # Point the kickstarter at packages/ instead of its typo3temp/ext-kickstarter/
        # default - its own README recommends this for Composer setups, since
        # typo3temp/ is regenerable/untracked scratch space, not real project code.
        # Extension key is "ext_kickstarter", not "kickstarter" - the composer.json
        # inside the friendsoftypo3/kickstarter package itself still says
        # stefanfroemken/ext-kickstarter (its pre-adoption name).
        ddev exec --raw php -r '
            $file = $argv[1];
            $config = require $file;
            $config["EXTENSIONS"]["ext_kickstarter"]["exportDirectory"] = "packages/";
            file_put_contents($file, "<?php\nreturn " . var_export($config, true) . ";\n");
        ' "$SETTINGS_FILE"

        # No flag/non-interactive mode exists for make:extension - it only knows
        # how to ask. Diff packages/ before and after to find what it created,
        # since there's no other way to learn the extension key it was given.
        EXT_DIRS_BEFORE="$(find packages -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)"
        echo "${C_CYAN}==> Launching the TYPO3 extension kickstarter - follow the prompts${C_RESET}"
        if ddev exec ./vendor/bin/typo3 make:extension; then
          EXT_DIRS_AFTER="$(find packages -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)"
          NEW_EXT_DIR="$(comm -13 <(echo "$EXT_DIRS_BEFORE") <(echo "$EXT_DIRS_AFTER"))"

          if [[ -z "$NEW_EXT_DIR" ]] || [[ "$(wc -l <<< "$NEW_EXT_DIR")" -ne 1 ]]; then
            echo "${C_YELLOW}Could not tell which extension the kickstarter created - nothing to put under git, check packages/ and run 'git init' there yourself if you want one.${C_RESET}"
          else
            # Same registration --extension already does for a mounted extension:
            # a Composer path repository, then require it at :@dev.
            package_name="$(
              ddev exec --raw php -r '
                  $composer = json_decode(file_get_contents($argv[1]), true);
                  echo $composer["name"] ?? "";
              ' "${NEW_EXT_DIR}/composer.json"
            )"
            if [[ -n "$package_name" ]]; then
              echo "${C_CYAN}==> Registering ${NEW_EXT_DIR} (${package_name}) with Composer${C_RESET}"
              ddev composer config "repositories.$(basename "$NEW_EXT_DIR")" path "$NEW_EXT_DIR"
              ddev composer require "${package_name}:@dev" --no-interaction --no-security-blocking
              ddev exec ./vendor/bin/typo3 extension:setup --no-interaction
            fi

            (
              cd "$NEW_EXT_DIR"
              git init >/dev/null
              git add -A
              if git commit -m "Initial commit" >/dev/null 2>&1; then
                echo "${C_GREEN}Git repository initialized and committed at ${PROJECT_DIR}/${NEW_EXT_DIR}${C_RESET}"
              else
                echo "${C_YELLOW}Git repository initialized, but the initial commit failed - configure git's user.name/user.email if you want one. Changes are staged.${C_RESET}"
              fi
            )
          fi
        else
          echo "${C_YELLOW}Kickstarter run failed or was cancelled - nothing to put under git.${C_RESET}"
        fi
      else
        echo "${C_YELLOW}Could not install friendsoftypo3/kickstarter, skipping.${C_RESET}"
      fi
    fi
  else
    echo "${C_YELLOW}--with-git: invalid choice, skipping.${C_RESET}"
  fi
fi

echo
echo "${C_GREEN}${C_BOLD}==> Done.${C_RESET}"
echo "${C_BOLD}URL:${C_RESET}         https://${PROJECT_NAME}.ddev.site"
echo "${C_BOLD}Backend:${C_RESET}     https://${PROJECT_NAME}.ddev.site/typo3"
echo "${C_BOLD}Admin:${C_RESET}       ${ADMIN_USER}"
echo "${C_BOLD}Password:${C_RESET}    ${ADMIN_PASSWORD}"
echo "${C_BOLD}Credentials:${C_RESET} ${PROJECT_DIR}/${CREDENTIALS_FILE}"
if [[ "$VERBOSE" -eq 1 ]]; then
  echo "${C_BOLD}Verbose log:${C_RESET} ${PROJECT_DIR}/${VERBOSE_LOG}"
fi
echo "To clean up this instance: ./typo3-ddev-setup.sh --c ${SUFFIX:-$PROJECT_NAME}"

echo
ddev describe

ddev launch /typo3 >/dev/null 2>&1 || echo "Note: could not auto-open the browser, open the backend URL above manually."
