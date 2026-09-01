#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Cue"
DEBUG_BUNDLE_NAME="Cue Debug"
RELEASE_BUNDLE_IDENTIFIER="com.mourato.cue"
DEBUG_BUNDLE_IDENTIFIER="com.mourato.cue.debug"
SCHEME="Cue"
PROJECT="Cue.xcodeproj"
LOG_SUBSYSTEM="${LOG_SUBSYSTEM:-Cue}"
# The existing local development identity shared with Vozinha. Override this for
# a different local keychain identity without changing project settings.
LOCAL_CODE_SIGN_IDENTITY="${LOCAL_CODE_SIGN_IDENTITY:-Prisma Local Code Signing}"
LOCAL_ENABLE_HARDENED_RUNTIME="${LOCAL_ENABLE_HARDENED_RUNTIME:-NO}"
APPLICATIONS_DIR="${APPLICATIONS_DIR:-/Applications}"

MODE="run"
CONFIGURATION="${CONFIGURATION:-Debug}"
LOG_LEVEL="${LOG_LEVEL:-default,error,fault}"
SHUTDOWN_TIMEOUT_SECONDS="${SHUTDOWN_TIMEOUT_SECONDS:-15}"
STARTUP_TIMEOUT_SECONDS="${STARTUP_TIMEOUT_SECONDS:-15}"
CLEAN=0
QUIET=1
FORCE_TERMINATE=0
NO_INTERACTIVE=0
# Local script builds include the Video module unless explicitly disabled.
ENABLE_VIDEO_MODULE="${ENABLE_VIDEO_MODULE:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build/xcode-derived-data}"

if [[ -t 1 ]]; then
  BLUE=$'\033[0;34m'
  GREEN=$'\033[0;32m'
  RED=$'\033[0;31m'
  BOLD=$'\033[1m'
  NC=$'\033[0m'
else
  BLUE=""
  GREEN=""
  RED=""
  BOLD=""
  NC=""
fi

info() { printf "%sinfo:%s %s\n" "$BLUE$BOLD" "$NC" "$1"; }
success() { printf "%ssuccess:%s %s\n" "$GREEN$BOLD" "$NC" "$1"; }
fail() {
  printf "%serror:%s %s\n" "$RED$BOLD" "$NC" "$1" >&2
  exit 1
}

usage() {
  cat <<USAGE
${BOLD}Usage:${NC} $0 [run|--logs|--telemetry|--debug|--verify] [options]

${BOLD}Modes:${NC}
  run                 Stop, build, and launch only the new app bundle (default)
  --logs, logs        Launch then stream unified logs for process == "Cue"
  --telemetry         Launch then stream unified logs for subsystem == "$LOG_SUBSYSTEM"
  --debug, debug      Build then launch the app binary under lldb
  --verify, verify    Launch and confirm the Notinhas process is running

${BOLD}Options:${NC}
  --configuration C   Build configuration. Local builds use LOCAL_CODE_SIGN_IDENTITY.
  --derived-data PATH Build DerivedData path. Default: .build/xcode-derived-data
  --log-level LEVELS  default,info,debug,error,fault,all. Default: default,error,fault
  --shutdown-timeout SECONDS
                      Wait time for existing instances to exit. Default: 15.
  --startup-timeout SECONDS
                      Wait time for the expected executable to start. Default: 15.
  --force-terminate   Allow SIGTERM after graceful shutdown timeout.
  --no-interactive    Never prompt; use the supplied configuration.
  --video-module      Build with the Video module (recording + video editor; default).
  --no-video-module   Build without the Video module.
  --clean             Clean before building
  --verbose           Show full xcodebuild output (warnings, notes, progress)
  --help, -h          Show this help

${BOLD}Environment:${NC}
  ENABLE_VIDEO_MODULE Set to 1 (default) or 0 to enable/disable the Video module
                      non-interactively.
  SHUTDOWN_TIMEOUT_SECONDS
                      Graceful shutdown wait. Default: 15.
  STARTUP_TIMEOUT_SECONDS
                      Launch verification wait. Default: 15.

${BOLD}Examples:${NC}
  $0
  $0 --verify
  $0 --logs --log-level all
  $0 --configuration Release
  $0 --no-video-module
  ENABLE_VIDEO_MODULE=0 $0
USAGE
}

apply_video_module_settings() {
  if [[ "${ENABLE_VIDEO_MODULE:-0}" == "1" ]]; then
    SCHEME="Cue Video"
    case "$CONFIGURATION" in
      Debug)
        CONFIGURATION="Debug+Video"
        ;;
      Release)
        CONFIGURATION="Release+Video"
        ;;
    esac
  else
    SCHEME="Cue"
  fi
}

require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "This script only supports macOS."
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

configure_interactive_build() {
  while true; do
    printf "\nChoose a local build:\n"
    printf "  1) Debug — build and open Cue Debug.app\n"
    printf "  2) Release — build signed Cue.app, then choose what to do with it\n"
    printf "  3) Exit\n"
    printf "Choose [1-3]: "

    local choice
    read -r choice || exit 0
    case "$choice" in
      1)
        CONFIGURATION="Debug"
        break
        ;;
      2)
        CONFIGURATION="Release"
        break
        ;;
      3)
        exit 0
        ;;
      *)
        info "Please enter a number from 1 to 3."
        ;;
    esac
  done

  printf "Clean previous build artifacts first? [Y/n]: "
  local clean_choice
  read -r clean_choice || exit 0
  case "$clean_choice" in
    ""|y|Y|yes|YES)
      CLEAN=1
      ;;
    n|N|no|NO)
      CLEAN=0
      ;;
  esac

  printf "Include Video module (recording + video editor)? [Y/n]: "
  local video_choice
  read -r video_choice || exit 0
  case "$video_choice" in
    ""|y|Y|yes|YES)
      ENABLE_VIDEO_MODULE=1
      ;;
    n|N|no|NO)
      ENABLE_VIDEO_MODULE=0
      ;;
    *)
      ENABLE_VIDEO_MODULE=1
      ;;
  esac
  apply_video_module_settings
}

parse_args() {
  local argument_count=$#

  while [[ $# -gt 0 ]]; do
    case "$1" in
      run)
        MODE="run"
        shift
        ;;
      --logs|logs)
        MODE="logs"
        shift
        ;;
      --telemetry|telemetry)
        MODE="telemetry"
        shift
        ;;
      --debug|debug)
        MODE="debug"
        shift
        ;;
      --verify|verify)
        MODE="verify"
        shift
        ;;
      --configuration)
        [[ $# -ge 2 ]] || fail "--configuration requires a value."
        CONFIGURATION="$2"
        shift 2
        ;;
      --derived-data|--derived-data-path)
        [[ $# -ge 2 ]] || fail "--derived-data requires a path."
        DERIVED_DATA_PATH="$2"
        shift 2
        ;;
      --log-level)
        [[ $# -ge 2 ]] || fail "--log-level requires a value."
        LOG_LEVEL="$2"
        shift 2
        ;;
      --shutdown-timeout)
        [[ $# -ge 2 ]] || fail "--shutdown-timeout requires a value."
        SHUTDOWN_TIMEOUT_SECONDS="$2"
        shift 2
        ;;
      --startup-timeout)
        [[ $# -ge 2 ]] || fail "--startup-timeout requires a value."
        STARTUP_TIMEOUT_SECONDS="$2"
        shift 2
        ;;
      --force-terminate)
        FORCE_TERMINATE=1
        shift
        ;;
      --no-interactive)
        NO_INTERACTIVE=1
        shift
        ;;
      --clean)
        CLEAN=1
        shift
        ;;
      --video-module)
        ENABLE_VIDEO_MODULE=1
        shift
        ;;
      --no-video-module)
        ENABLE_VIDEO_MODULE=0
        shift
        ;;
      --verbose)
        QUIET=0
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        fail "Unknown option: $1"
      ;;
    esac
  done

  if [[ "$argument_count" -eq 0 && "$NO_INTERACTIVE" -eq 0 && -t 0 && -t 1 ]]; then
    configure_interactive_build
  else
    apply_video_module_settings
  fi
}

message_type_predicate() {
  local levels="$1"
  local type_clauses=""

  if [[ "$levels" == "all" ]]; then
    printf ""
    return
  fi

  IFS=',' read -r -a level_array <<<"$levels"
  for level in "${level_array[@]}"; do
    level="${level//[[:space:]]/}"
    case "$level" in
      default|info|debug|error|fault)
        if [[ -n "$type_clauses" ]]; then
          type_clauses="$type_clauses OR messageType == $level"
        else
          type_clauses="messageType == $level"
        fi
        ;;
      *)
        fail "Invalid log level: '$level'. Use default, info, debug, error, fault, or all."
        ;;
    esac
  done

  printf " AND (%s)" "$type_clauses"
}

process_log_predicate() {
  printf "process == \"%s\"" "$APP_NAME"
  message_type_predicate "$LOG_LEVEL"
}

telemetry_log_predicate() {
  printf "subsystem == \"%s\"" "$LOG_SUBSYSTEM"
  message_type_predicate "$LOG_LEVEL"
}

build_products_dir() {
  printf "%s/Build/Products/%s" "$DERIVED_DATA_PATH" "$CONFIGURATION"
}

app_bundle_path() {
  local bundle_name="$APP_NAME"
  if [[ "$CONFIGURATION" == "Debug" || "$CONFIGURATION" == "Debug+Video" ]]; then
    bundle_name="$DEBUG_BUNDLE_NAME"
  fi

  printf "%s/%s.app" "$(build_products_dir)" "$bundle_name"
}

app_binary_path() {
  printf "%s/Contents/MacOS/%s" "$(app_bundle_path)" "$APP_NAME"
}

require_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]] || fail "Timeout must be a positive integer: $1"
}

expected_bundle_identifier() {
  if [[ "$(basename "$1")" == "$DEBUG_BUNDLE_NAME.app" ]]; then
    printf '%s\n' "$DEBUG_BUNDLE_IDENTIFIER"
  else
    printf '%s\n' "$RELEASE_BUNDLE_IDENTIFIER"
  fi
}

validate_app_bundle() {
  local bundle="$1" identifier expected_identifier
  [[ -d "$bundle" ]] || return 1
  [[ "$(basename "$bundle")" == "$APP_NAME.app" || "$(basename "$bundle")" == "$DEBUG_BUNDLE_NAME.app" ]] || return 1
  [[ -f "$bundle/Contents/Info.plist" ]] || return 1
  [[ -x "$bundle/Contents/MacOS/$APP_NAME" ]] || return 1
  identifier="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$bundle/Contents/Info.plist" 2>/dev/null || true)"
  expected_identifier="$(expected_bundle_identifier "$bundle")"
  [[ "$identifier" == "$expected_identifier" ]] || return 1
  /usr/bin/codesign --verify --deep --strict "$bundle" >/dev/null 2>&1
}

installed_release_app_path() {
  printf "%s/%s.app" "$APPLICATIONS_DIR" "$APP_NAME"
}

app_process_pids() {
  pgrep -x "$APP_NAME" 2>/dev/null || true
}

stop_app() {
  local pids reply deadline bundle_identifier
  pids="$(app_process_pids)"
  [[ -n "$pids" ]] || return 0

  info "Requesting graceful shutdown for existing $APP_NAME process(es)..."
  for bundle_identifier in "$RELEASE_BUNDLE_IDENTIFIER" "$DEBUG_BUNDLE_IDENTIFIER"; do
    /usr/bin/osascript -e "tell application id \"$bundle_identifier\" to quit" >/dev/null 2>&1 || true
  done

  deadline=$((SECONDS + SHUTDOWN_TIMEOUT_SECONDS))
  while [[ "$SECONDS" -lt "$deadline" ]]; do
    [[ -z "$(app_process_pids)" ]] && return 0
    sleep 1
  done

  if [[ "$FORCE_TERMINATE" -ne 1 && -t 0 && -t 1 ]]; then
    read -r -p "Graceful shutdown timed out. Stop exact process(es) now? [y/N]: " reply < /dev/tty || reply=""
    case "$reply" in
      y|Y|yes|YES) FORCE_TERMINATE=1 ;;
    esac
  fi

  [[ "$FORCE_TERMINATE" -eq 1 ]] || fail "$APP_NAME did not terminate within ${SHUTDOWN_TIMEOUT_SECONDS}s; rerun with --force-terminate."
  info "Graceful shutdown timed out; sending SIGTERM to PID(s): $pids"
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && kill -TERM "$pid" 2>/dev/null || true
  done <<< "$pids"

  deadline=$((SECONDS + SHUTDOWN_TIMEOUT_SECONDS))
  while [[ "$SECONDS" -lt "$deadline" ]]; do
    [[ -z "$(app_process_pids)" ]] && return 0
    sleep 1
  done

  fail "$APP_NAME remained running after SIGTERM."
}

process_uses_binary() {
  local pid="$1"
  local expected_binary="$2"

  /usr/sbin/lsof -a -p "$pid" -d txt -Fn 2>/dev/null \
    | awk -v expected="n$expected_binary" '$0 == expected { found = 1 } END { exit !found }'
}

wait_for_app_binary() {
  local expected_binary="$1"
  local pid deadline

  deadline=$((SECONDS + STARTUP_TIMEOUT_SECONDS))
  while [[ "$SECONDS" -lt "$deadline" ]]; do
    while IFS= read -r pid; do
      [[ -n "$pid" ]] || continue
      if process_uses_binary "$pid" "$expected_binary"; then
        printf '%s\n' "$pid"
        return 0
      fi
    done < <(app_process_pids)
    sleep 1
  done

  printf 'error: Launched %s, but no process is running the expected binary within %ss: %s\n' "$APP_NAME" "$STARTUP_TIMEOUT_SECONDS" "$expected_binary" >&2
  return 1
}

filter_xcodebuild_output() {
  local warning_count=0
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      *" error:"*|error:*|"clang: error:"*|*"ld: error:"*)
        printf '%s\n' "$line"
        ;;
      *"warning:"*)
        warning_count=$((warning_count + 1))
        ;;
      *"** BUILD FAILED **"*|*"** BUILD SUCCEEDED **"*)
        printf '%s\n' "$line"
        ;;
    esac
  done

  if [[ "$warning_count" -gt 0 ]]; then
    info "Build finished with $warning_count compiler warning(s). Re-run with --verbose to see them."
  fi
}

run_xcodebuild() {
  local action="$1"
  local args=(
    xcodebuild
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -derivedDataPath "$DERIVED_DATA_PATH"
  )

  # The project targets an unavailable legacy development team. Use the shared
  # Vozinha identity for local app bundles instead. Its local, team-less
  # certificate is intended for local builds, so hardened runtime is disabled
  # by default. A trusted Apple distribution identity can opt in with
  # LOCAL_ENABLE_HARDENED_RUNTIME=YES.
  args+=(
    "CODE_SIGN_STYLE=Manual"
    "CODE_SIGN_IDENTITY=$LOCAL_CODE_SIGN_IDENTITY"
    "DEVELOPMENT_TEAM="
    "ENABLE_HARDENED_RUNTIME=$LOCAL_ENABLE_HARDENED_RUNTIME"
  )
  if [[ "$CONFIGURATION" != Debug* ]]; then
    # Xcode 17's Swift 6.3.3 whole-module optimizer crashes while compiling
    # this project. Keep Release optimization enabled while disabling only the
    # failing SIL performance pass.
    args+=('OTHER_SWIFT_FLAGS=$(inherited) -Xfrontend -disable-sil-perf-optzns')
  fi

  args+=("$action")

  if [[ "$QUIET" -eq 1 ]]; then
    args+=(-quiet)
    local build_log
    build_log="$(mktemp "${TMPDIR:-/tmp}/notinhas-xcodebuild.XXXXXX.log")"

    set +e
    "${args[@]}" 2>&1 | tee "$build_log" | filter_xcodebuild_output
    local exit_code=${PIPESTATUS[0]}
    set -e

    if [[ "$exit_code" -ne 0 ]]; then
      cat "$build_log" >&2
      rm -f "$build_log"
      fail "xcodebuild $action failed with exit code $exit_code."
    fi

    rm -f "$build_log"
    return 0
  fi

  "${args[@]}"
}

build_app() {
  cd "$ROOT_DIR"

  if [[ "$CLEAN" -eq 1 ]]; then
    info "Cleaning $SCHEME ($CONFIGURATION)..."
    run_xcodebuild clean
  fi

  info "Building $SCHEME ($CONFIGURATION)..."
  run_xcodebuild build

  local app_bundle
  app_bundle="$(app_bundle_path)"
  validate_app_bundle "$app_bundle" || fail "Built app bundle failed validation: $app_bundle"

  success "Build ready: $app_bundle"
}

launch_app_bundle() {
  local app_bundle="$1"
  local expected_binary="$app_bundle/Contents/MacOS/$APP_NAME"
  local pid

  validate_app_bundle "$app_bundle" || fail "App bundle failed validation: $app_bundle"

  # Stop again immediately before launch; a long build can outlive the initial stop.
  stop_app
  info "Launching $app_bundle..."
  /usr/bin/open -n "$app_bundle"
  if ! pid="$(wait_for_app_binary "$expected_binary")"; then
    fail "Launched $APP_NAME, but it did not remain running from the expected binary."
  fi
  success "Launched $app_bundle (pid $pid)"
}

open_app() {
  launch_app_bundle "$(app_bundle_path)"
}

install_release_app() {
  local source_app destination_app stage backup_directory had_backup=0
  source_app="$(app_bundle_path)"
  destination_app="$(installed_release_app_path)"
  stage="${destination_app}.stage.$$"

  [[ -d "$APPLICATIONS_DIR" ]] || fail "Applications directory was not found: $APPLICATIONS_DIR"
  [[ -w "$APPLICATIONS_DIR" ]] || fail "Applications directory is not writable: $APPLICATIONS_DIR"
  validate_app_bundle "$source_app" || fail "Release app bundle failed validation: $source_app"

  # Do not replace an app bundle whose old executable is still running.
  stop_app

  backup_directory="$(mktemp -d "${TMPDIR:-/tmp}/${APP_NAME}.install-backup.XXXXXX")"
  rm -rf "$stage"
  if [[ -e "$destination_app" ]]; then
    info "Replacing existing $destination_app..."
    mv "$destination_app" "$backup_directory/$APP_NAME.app" || {
      rmdir "$backup_directory" 2>/dev/null || true
      fail "Could not back up the existing $APP_NAME app."
    }
    had_backup=1
  fi

  if /usr/bin/ditto "$source_app" "$stage" && mv "$stage" "$destination_app" && validate_app_bundle "$destination_app" && "$ROOT_DIR/scripts/clean-launch-services.sh" "$destination_app"; then
    rm -rf "$backup_directory"
    success "Installed and validated: $destination_app"
  else
    rm -rf "$stage" "$destination_app"
    if [[ "$had_backup" -eq 1 && -e "$backup_directory/$APP_NAME.app" ]]; then
      mv "$backup_directory/$APP_NAME.app" "$destination_app"
    fi
    rmdir "$backup_directory" 2>/dev/null || true
    fail "Could not install $APP_NAME. The previous app was restored."
  fi
}

open_installed_release_app() {
  launch_app_bundle "$(installed_release_app_path)"
}

release_post_build_menu() {
  [[ "$NO_INTERACTIVE" -eq 1 || ! -t 0 || ! -t 1 ]] && {
    info "Release app is ready: $(app_bundle_path)"
    return
  }

  while true; do
    printf "\nRelease build completed. What would you like to do?\n"
    printf "  1) Install the current .app in %s and open it (recommended)\n" "$APPLICATIONS_DIR"
    printf "  2) Install the current .app in %s\n" "$APPLICATIONS_DIR"
    printf "  3) Open the current .app from the build folder\n"
    printf "  4) Exit\n"
    printf "Choose [1-4]: "

    local choice
    read -r choice
    case "$choice" in
      1)
        install_release_app
        open_installed_release_app
        return
        ;;
      2)
        install_release_app
        return
        ;;
      3)
        open_app
        return
        ;;
      4)
        info "Release app remains at: $(app_bundle_path)"
        return
        ;;
      *)
        info "Please enter a number from 1 to 4."
        ;;
    esac
  done
}

verify_app() {
  open_app
}

stream_logs() {
  local predicate="$1"

  open_app

  cleanup_stream() {
    printf "\n"
    stop_app
    success "App stopped."
  }
  trap cleanup_stream INT TERM

  info "Streaming logs for predicate: $predicate"
  /usr/bin/log stream --info --debug --style compact --predicate "$predicate"
}

launch_debugger() {
  require_command lldb
  info "Launching under lldb..."
  exec lldb -o run -- "$(app_binary_path)"
}

main() {
  parse_args "$@"
  require_macos
  require_command xcodebuild
  require_command pgrep
  require_command lsof
  require_command osascript
  require_positive_integer "$SHUTDOWN_TIMEOUT_SECONDS"
  require_positive_integer "$STARTUP_TIMEOUT_SECONDS"
  [[ -x /usr/sbin/lsof ]] || fail "Missing required command: /usr/sbin/lsof"

  cd "$ROOT_DIR"
  stop_app
  build_app

  if [[ "$CONFIGURATION" == Release* && "$MODE" == "run" ]]; then
    release_post_build_menu
    return
  fi

  case "$MODE" in
    run)
      open_app
      ;;
    logs)
      stream_logs "$(process_log_predicate)"
      ;;
    telemetry)
      stream_logs "$(telemetry_log_predicate)"
      ;;
    verify)
      verify_app
      ;;
    debug)
      launch_debugger
      ;;
    *)
      fail "Unsupported mode: $MODE"
      ;;
  esac
}

main "$@"
