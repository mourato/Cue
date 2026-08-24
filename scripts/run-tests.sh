#!/bin/bash
# Run the Notinhas XCTest suite with CI-like local settings.
#
# Usage:
#   ./scripts/run-tests.sh
#   ./scripts/run-tests.sh --video-module
#   ./scripts/run-tests.sh --skip-visual
#   ./scripts/run-tests.sh --with-visual
#   ./scripts/run-tests.sh -only-testing:NotinhasTests/SomeTests
#   ./scripts/run-tests.sh --open-result

set -euo pipefail

PROJECT="${PROJECT:-Notinhas.xcodeproj}"
SCHEME="${SCHEME:-Notinhas}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DESTINATION="${DESTINATION:-platform=macOS}"
BUILD_DIR="${BUILD_DIR:-build}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${BUILD_DIR}/DerivedData}"
# Local builds use the same team-less development identity as build_and_run.sh.
# CI overrides these settings below with code signing disabled.
LOCAL_CODE_SIGN_IDENTITY="${LOCAL_CODE_SIGN_IDENTITY:-Prisma Local Code Signing}"
LOCAL_ENABLE_HARDENED_RUNTIME="${LOCAL_ENABLE_HARDENED_RUNTIME:-NO}"
# If running in CI, default to local package cache to avoid caching issues on CI runners.
# Otherwise, default to empty to let xcodebuild use the user's global SwiftPM cache for speed.
if [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" ]]; then
  SOURCE_PACKAGES_PATH="${SOURCE_PACKAGES_PATH:-${BUILD_DIR}/SourcePackages}"
else
  SOURCE_PACKAGES_PATH="${SOURCE_PACKAGES_PATH:-}"
fi
MODULE_CACHE_PATH="${MODULE_CACHE_PATH:-${BUILD_DIR}/swift-module-cache}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-${BUILD_DIR}/ci-test.xcresult}"
LOG_PATH="${LOG_PATH:-${BUILD_DIR}/ci-test.log}"
KEEP_RESULT=0
OPEN_RESULT=0
ENABLE_VIDEO_MODULE="${ENABLE_VIDEO_MODULE:-}"
VIDEO_MODULE_EXPLICIT=0
if [[ -n "$ENABLE_VIDEO_MODULE" ]]; then
  VIDEO_MODULE_EXPLICIT=1
fi
# Keep the default test run quiet: no suites that order real overlays/panels
# onto the display. Pass --with-visual (or set NOTINHAS_SKIP_VISUAL_TESTS=0)
# for an intentional UI integration run.
QUIET_TESTS="${NOTINHAS_QUIET_TESTS:-1}"
export NOTINHAS_QUIET_TESTS="$QUIET_TESTS"
SKIP_VISUAL_TESTS="${NOTINHAS_SKIP_VISUAL_TESTS:-1}"
# XCTest identifiers that flash fullscreen capture overlays, floating panels, or Dock policy.
# Keep in sync with delivery-workflow / testing-xctest skills when adding new on-screen hosts.
VISUAL_TEST_IDENTIFIERS=(
  NotinhasTests/AreaSelectionSessionLifecycleTests
  NotinhasTests/AreaSelectionMultiMonitorReconciliationTests
  NotinhasTests/AreaSelectionControllerTests
  NotinhasTests/AreaSelectionOverlayMagnifierLayoutTests
  NotinhasTests/CaptureViewModelTests
  NotinhasTests/QuickAccessPanelControllerTests
  NotinhasTests/AppStatusBarControllerTests
)
XCODEBUILD_ARGS=()

if [ -t 1 ]; then
  BOLD=$'\033[1m'
  BLUE=$'\033[0;34m'
  GREEN=$'\033[0;32m'
  RED=$'\033[0;31m'
  YELLOW=$'\033[0;33m'
  RESET=$'\033[0m'
else
  BOLD=""
  BLUE=""
  GREEN=""
  RED=""
  YELLOW=""
  RESET=""
fi

info() { printf "%binfo:%b %s\n" "${BLUE}${BOLD}" "$RESET" "$*"; }
success() { printf "%bsuccess:%b %s\n" "${GREEN}${BOLD}" "$RESET" "$*"; }
warn() { printf "%bwarning:%b %s\n" "${YELLOW}${BOLD}" "$RESET" "$*" >&2; }
error() { printf "%berror:%b %s\n" "${RED}${BOLD}" "$RESET" "$*" >&2; }
die() {
  error "$*"
  exit 1
}

apply_video_module_settings() {
  if [[ "${ENABLE_VIDEO_MODULE:-0}" == "1" ]]; then
    SCHEME="Notinhas Video"
    case "$CONFIGURATION" in
      Debug)
        CONFIGURATION="Debug+Video"
        ;;
      Release)
        CONFIGURATION="Release+Video"
        ;;
    esac
  else
    SCHEME="Notinhas"
  fi
}

append_skip_visual_args() {
  local id
  for id in "${VISUAL_TEST_IDENTIFIERS[@]}"; do
    XCODEBUILD_ARGS+=("-skip-testing:${id}")
  done
}

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] [XCODEBUILD_TEST_OPTIONS]

Runs xcodebuild test with local build artifacts under ./build.

Options:
  --configuration NAME   Xcode configuration. Default: ${CONFIGURATION}
  --destination VALUE    Xcode destination. Default: ${DESTINATION}
  --derived-data PATH    DerivedData path. Default: ${DERIVED_DATA_PATH}
  --log PATH             Test log path. Default: ${LOG_PATH}
  --open-result          Open the .xcresult bundle when done.
  --result-bundle PATH   Result bundle path. Default: ${RESULT_BUNDLE_PATH}
  --source-packages PATH SwiftPM package cache path. Default: ${SOURCE_PACKAGES_PATH}
  --keep-result          Do not remove the previous result bundle before running.
  --video-module         Run Recording/VideoEditor XCTests (Notinhas Video / Debug+Video).
  --no-video-module      Explicit default: Notinhas scheme without Video module.
  --skip-visual          Skip XCTest suites that flash real overlays/panels on screen
                         (area selection, Quick Access panel, status-bar activation).
                         This is the default.
  --with-visual          Include the on-screen overlay/panel suites explicitly.
                         Audio remains muted while running under XCTest.
  -h, --help             Show this help.

Environment:
  ENABLE_VIDEO_MODULE                 Set to 1 or 0 to enable/disable the Video module non-interactively.
  LOCAL_CODE_SIGN_IDENTITY            Local signing identity. Default: Prisma Local Code Signing.
  LOCAL_ENABLE_HARDENED_RUNTIME       Local hardened-runtime setting. Default: NO.
  NOTINHAS_QUIET_TESTS                 Keep test-side effects quiet. Default: 1.
  NOTINHAS_SKIP_VISUAL_TESTS          Set to 1 for the same effect as --skip-visual.
  NOTINHAS_ALLOW_TEST_SOUNDS          Set to 1 only for an intentional audio integration run.
  NOTINHAS_ALLOW_SCREEN_CAPTURE_IN_TESTS
                                      Set to 1 to use live ScreenCaptureKit backdrop
                                      captures in XCTest (default: synthetic, no Screen Recording TCC).

Examples:
  $0
  $0 --video-module
  $0 --skip-visual
  $0 --with-visual
  ENABLE_VIDEO_MODULE=1 $0
  NOTINHAS_SKIP_VISUAL_TESTS=1 $0
  $0 -only-testing:NotinhasTests/CaptureOutputNamingTests
  NOTINHAS_RUN_MICROPHONE_INTEGRATION=1 $0 -only-testing:NotinhasTests/MicrophoneAudioCapturerTests/testMicrophoneAudioCapturerStartStopRealMicrophoneIntegration
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "$1 not found. Install Xcode Command Line Tools first."
  fi
}

take_value() {
  local option="$1"
  local value="${2:-}"
  if [ -z "$value" ]; then
    die "$option requires a value"
  fi
  printf "%s" "$value"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --configuration)
      CONFIGURATION="$(take_value "$1" "${2:-}")"
      shift 2
      ;;
    --destination)
      DESTINATION="$(take_value "$1" "${2:-}")"
      shift 2
      ;;
    --derived-data)
      DERIVED_DATA_PATH="$(take_value "$1" "${2:-}")"
      shift 2
      ;;
    --log)
      LOG_PATH="$(take_value "$1" "${2:-}")"
      shift 2
      ;;
    --open-result)
      OPEN_RESULT=1
      shift
      ;;
    --result-bundle)
      RESULT_BUNDLE_PATH="$(take_value "$1" "${2:-}")"
      shift 2
      ;;
    --source-packages)
      SOURCE_PACKAGES_PATH="$(take_value "$1" "${2:-}")"
      shift 2
      ;;
    --keep-result)
      KEEP_RESULT=1
      shift
      ;;
    --video-module)
      ENABLE_VIDEO_MODULE=1
      VIDEO_MODULE_EXPLICIT=1
      shift
      ;;
    --no-video-module)
      ENABLE_VIDEO_MODULE=0
      VIDEO_MODULE_EXPLICIT=1
      shift
      ;;
    --skip-visual)
      SKIP_VISUAL_TESTS=1
      shift
      ;;
    --with-visual)
      SKIP_VISUAL_TESTS=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do
        XCODEBUILD_ARGS+=("$1")
        shift
      done
      ;;
    *)
      XCODEBUILD_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ "$VIDEO_MODULE_EXPLICIT" -eq 1 ]]; then
  apply_video_module_settings
fi

if [[ "$SKIP_VISUAL_TESTS" == "1" ]]; then
  append_skip_visual_args
fi

if [ "$(uname -s)" != "Darwin" ]; then
  die "This script requires macOS."
fi

require_command xcodebuild
require_command grep
require_command tail

mkdir_paths=("$BUILD_DIR" "$DERIVED_DATA_PATH" "$MODULE_CACHE_PATH")
if [[ -n "$SOURCE_PACKAGES_PATH" ]]; then
  mkdir_paths+=("$SOURCE_PACKAGES_PATH")
fi
mkdir -p "${mkdir_paths[@]}"

if [ "$KEEP_RESULT" -eq 0 ]; then
  rm -rf "$RESULT_BUNDLE_PATH"
fi

info "Running ${SCHEME} tests"
if [[ "$SKIP_VISUAL_TESTS" == "1" ]]; then
  info "Skipping visual on-screen suites (${#VISUAL_TEST_IDENTIFIERS[@]} identifiers)"
  for id in "${VISUAL_TEST_IDENTIFIERS[@]}"; do
    info "  -skip-testing:${id}"
  done
fi
info "Log: ${LOG_PATH}"
info "Result bundle: ${RESULT_BUNDLE_PATH}"

set +e
set +u
XCODEBUILD_CMD=(
  xcodebuild
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -resultBundlePath "$RESULT_BUNDLE_PATH"
)

if [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" ]]; then
  XCODEBUILD_CMD+=(
    CODE_SIGN_IDENTITY=
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGNING_ALLOWED=NO
  )
else
  XCODEBUILD_CMD+=(
    CODE_SIGN_STYLE=Manual
    "CODE_SIGN_IDENTITY=$LOCAL_CODE_SIGN_IDENTITY"
    DEVELOPMENT_TEAM=
    "ENABLE_HARDENED_RUNTIME=$LOCAL_ENABLE_HARDENED_RUNTIME"
  )
fi

if [[ -n "$SOURCE_PACKAGES_PATH" ]]; then
  XCODEBUILD_CMD+=(-clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH")
fi

CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_PATH" "${XCODEBUILD_CMD[@]}" "${XCODEBUILD_ARGS[@]}" test > "$LOG_PATH" 2>&1
STATUS=$?
set -u
set -e

if [ "$STATUS" -ne 0 ]; then
  error "Tests failed with status ${STATUS}."
  if [ -f "$LOG_PATH" ]; then
    warn "Likely failures:"
    grep -E "Test case '.*' failed|Failing tests:|\\*\\* TEST FAILED \\*\\*|error:" "$LOG_PATH" || true
    warn "Last 200 log lines:"
    tail -200 "$LOG_PATH"
  fi
  exit "$STATUS"
fi

if [ -f "$LOG_PATH" ]; then
  tail -20 "$LOG_PATH"
fi

success "Tests passed."

if [ "$OPEN_RESULT" -eq 1 ]; then
  open "$RESULT_BUNDLE_PATH"
fi
