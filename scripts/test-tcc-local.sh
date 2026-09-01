#!/usr/bin/env bash
# test-tcc-local.sh — Test TCC permission persistence with self-signed cert
#
# Usage:
#   ./scripts/test-tcc-local.sh build-v1    # Build, sign, install v1
#   ./scripts/test-tcc-local.sh build-v2    # Re-sign/reinstall (same archive as v1)
#   ./scripts/test-tcc-local.sh compare     # Ad-hoc control build
#
# Default install target is isolated under /tmp/test-tcc-notinhas/Applications/.
# System installation requires --install-path and --allow-system-install.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="/tmp/test-tcc-notinhas"
DEFAULT_INSTALL_PATH="$TEST_DIR/Applications/Cue.app"
CERT_NAME="Cue Self-Signed"
ENTITLEMENTS="$PROJECT_DIR/Cue/Cue.entitlements"
INSTALL_PATH="$DEFAULT_INSTALL_PATH"
ALLOW_SYSTEM_INSTALL=0
WORKSPACE_PATH="$TEST_DIR"

BACKUP_DIR=""
INSTALL_SUCCEEDED=0
INSTALL_TARGET_BACKED_UP=0

usage() {
  cat <<EOF
Usage: $0 [options] <command>

Commands:
  build-v1   Build, sign with self-signed cert, install as v1
  build-v2   Re-sign and reinstall from the same v1 archive (same-source update)
  compare    Re-sign the v1 archive ad-hoc as a control case
  clean      Remove test artifacts from the fixed or explicit workspace
  help       Show this help

Options:
  --install-path PATH       Install target .app path (default: $DEFAULT_INSTALL_PATH)
  --allow-system-install    Allow installation under /Applications (requires --install-path)
  --workspace PATH          Workspace for clean only (default: $TEST_DIR)

Safety:
  - Default operation never replaces /Applications/Cue.app.
  - Paths under /Applications require --install-path and --allow-system-install.
  - In an interactive terminal, system installs also require confirmation.
  - Each stage writes a metadata report under <workspace>/reports/.
  - Permission persistence still requires manual inspection in System Settings.

Test flow:
  1. $0 build-v1
     → Open the reported app path → grant Screen Recording + Microphone
  2. $0 build-v2
     → Open the reported app path → verify permissions are still granted
  3. $0 compare
     → Open the reported app path → verify permissions are lost (ad-hoc control)
EOF
}

die() {
  echo "❌ $*" >&2
  exit 1
}

is_interactive_terminal() {
  [[ -t 0 && -t 1 ]]
}

canonicalize_path() {
  local path="$1"
  python3 - "$path" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
}

normalize_path() {
  local path="$1"
  if [[ -z "$path" ]]; then
    die "install path cannot be empty"
  fi
  if [[ "$path" == *"*"* || "$path" == *"?"* || "$path" == *"["* ]]; then
    die "install path must not contain shell globs: $path"
  fi
  if [[ "$path" != /* ]]; then
    die "install path must be absolute: $path"
  fi
  path="$(canonicalize_path "$path")"
  if [[ "$path" == "/" ]]; then
    die "refusing to use filesystem root as install path"
  fi
  if [[ "$path" == "$PROJECT_DIR" || "$path" == "$PROJECT_DIR/"* ]]; then
    die "refusing to install into the repository: $path"
  fi
  if [[ "$path" != *.app ]]; then
    die "install path must point to a .app bundle: $path"
  fi
  printf '%s\n' "$path"
}

is_system_install_path() {
  local path="$1"
  local system_root
  system_root="$(canonicalize_path "/Applications")"
  [[ "$path" == "$system_root"/* ]]
}

validate_install_path() {
  local path
  path="$(normalize_path "$INSTALL_PATH")"
  INSTALL_PATH="$path"

  if is_system_install_path "$INSTALL_PATH"; then
    if [[ "$ALLOW_SYSTEM_INSTALL" -ne 1 ]]; then
      die "refusing system install path without --allow-system-install: $INSTALL_PATH"
    fi
    if is_interactive_terminal; then
      echo "⚠️  System install requested: $INSTALL_PATH"
      read -r -p "Type the exact install path to continue: " confirmation
      if [[ "$confirmation" != "$INSTALL_PATH" ]]; then
        die "confirmation did not match install path; aborting"
      fi
    fi
  fi
}

validate_clean_workspace() {
  local path="$1"

  if [[ -z "$path" ]]; then
    die "clean workspace cannot be empty"
  fi
  if [[ "$path" == *"*"* || "$path" == *"?"* || "$path" == *"["* ]]; then
    die "clean workspace must not contain shell globs: $path"
  fi
  if [[ "$path" != /* ]]; then
    die "clean workspace must be absolute: $path"
  fi
  if [[ "$path" == "/" ]]; then
    die "refusing to clean filesystem root"
  fi
  if [[ "$path" == "$PROJECT_DIR" || "$path" == "$PROJECT_DIR/"* ]]; then
    die "refusing to clean the repository: $path"
  fi
  local system_root
  system_root="$(canonicalize_path "/Applications")"
  if [[ "$path" == "$system_root" || "$path" == "$system_root"/* ]]; then
    die "refusing to clean /Applications: $path"
  fi
  if [[ "$path" != "$TEST_DIR" && "$path" != "$TEST_DIR/"* ]]; then
    die "clean only supports the fixed test workspace ($TEST_DIR) or paths under it: $path"
  fi
}

restore_install_backup() {
  if [[ "$INSTALL_SUCCEEDED" -eq 1 || "$INSTALL_TARGET_BACKED_UP" -ne 1 ]]; then
    return 0
  fi
  if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
    return 0
  fi

  echo "↩️  Restoring previous install target from backup..."
  rm -rf "$INSTALL_PATH"
  if [[ -d "$BACKUP_DIR" ]]; then
    ditto "$BACKUP_DIR" "$INSTALL_PATH"
  fi
}

on_exit() {
  local status=$?
  if [[ "$status" -ne 0 ]]; then
    restore_install_backup
  fi
}

backup_install_target() {
  local backup_root="$TEST_DIR/backups/$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$backup_root/install-target"
  INSTALL_TARGET_BACKED_UP=0

  if [[ -d "$INSTALL_PATH" ]]; then
    mkdir -p "$BACKUP_DIR"
    ditto "$INSTALL_PATH" "$BACKUP_DIR"
    INSTALL_TARGET_BACKED_UP=1
    echo "  → Backed up existing install target to $BACKUP_DIR"
  fi
}

terminate_installed_app() {
  local binary_path="$INSTALL_PATH/Contents/MacOS/Cue"
  local pid

  if [[ ! -x "$binary_path" ]]; then
    return 0
  fi

  while IFS= read -r pid; do
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  done < <(lsof -t "$binary_path" 2>/dev/null || true)

  sleep 1
}

identity_kind() {
  local identity="$1"
  if [[ "$identity" == "-" ]]; then
    printf '%s\n' "ad-hoc"
  else
    printf '%s\n' "self-signed"
  fi
}

source_commit() {
  if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || true
  fi
}

write_stage_report() {
  local stage_label="$1"
  local archive_path="$2"
  local archive_label="$3"
  local identity="$4"
  local verification_result="$5"
  local bundle_id="$6"
  local report_dir="$TEST_DIR/reports"
  local timestamp
  local report_path
  local commit_sha

  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  report_path="$report_dir/${stage_label}-${timestamp}.json"
  commit_sha="$(source_commit)"

  mkdir -p "$report_dir"
  cat >"$report_path" <<EOF
{
  "stage": "$stage_label",
  "archive_path": "$archive_path",
  "archive_label": "$archive_label",
  "source_commit": "${commit_sha:-unknown}",
  "bundle_identifier": "$bundle_id",
  "install_path": "$INSTALL_PATH",
  "signing_identity": "$identity",
  "identity_kind": "$(identity_kind "$identity")",
  "timestamp": "$timestamp",
  "verification_result": "$verification_result"
}
EOF

  echo "  → Metadata report: $report_path"
}

build_archive() {
  local version_label="$1"
  local archive_path="$TEST_DIR/$version_label/Cue.xcarchive"

  echo "=== Building archive ($version_label) ==="
  mkdir -p "$TEST_DIR/$version_label"

  if [ -d "$archive_path" ]; then
    echo "  ♻️  Reusing existing archive at $archive_path"
    return
  fi

  echo "  → Building (this may take a few minutes)..."
  xcodebuild archive \
    -project "$PROJECT_DIR/Cue.xcodeproj" \
    -scheme Cue \
    -configuration Release \
    -archivePath "$archive_path" \
    -derivedDataPath "$TEST_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=NO \
    >"$TEST_DIR/$version_label/build.log" 2>&1

  if [ ! -d "$archive_path" ]; then
    echo "  ❌ Build failed! Check $TEST_DIR/$version_label/build.log"
    tail -20 "$TEST_DIR/$version_label/build.log"
    exit 1
  fi

  echo "  ✅ Archive built"
}

sign_and_install() {
  local stage_label="$1"
  local identity="$2"
  local archive_label="${3:-$stage_label}"
  local archive_path="$TEST_DIR/$archive_label/Cue.xcarchive"
  local source_app="$archive_path/Products/Applications/Cue.app"
  local app_path="$TEST_DIR/$stage_label/Cue.app"
  local bundle_id
  local processed
  local verification_result="failed"

  trap on_exit EXIT
  validate_install_path
  mkdir -p "$(dirname "$INSTALL_PATH")"

  echo "=== Signing ($stage_label) with identity: $identity ==="
  echo "  → Archive label: $archive_label"

  if [[ ! -d "$archive_path" ]]; then
    die "archive not found: $archive_path"
  fi
  if [[ ! -d "$source_app" ]]; then
    die "archive app bundle not found: $source_app"
  fi

  backup_install_target

  rm -rf "$app_path"
  ditto "$source_app" "$app_path"

  bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app_path/Contents/Info.plist")
  processed="$TEST_DIR/processed-entitlements.plist"
  sed "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$bundle_id/g" "$ENTITLEMENTS" >"$processed"
  echo "  → Pre-processed entitlements with bundle ID: $bundle_id"

  echo "  → Signing main app bundle..."
  codesign \
    --force \
    --sign "$identity" \
    --entitlements "$processed" \
    --timestamp=none \
    "$app_path"

  echo "  → Verifying signature..."
  if codesign --verify --deep --strict "$app_path" 2>&1; then
    verification_result="valid"
    echo "  ✅ Signature valid"
  else
    verification_result="warning"
    echo "  ⚠️  Verification warning (may be ok for self-signed)"
  fi

  echo "  → Signing identity:"
  codesign -dvv "$app_path" 2>&1 | grep -E "Authority|TeamIdentifier|CDHash" || true

  echo "  → Installing to $INSTALL_PATH..."
  terminate_installed_app
  rm -rf "$INSTALL_PATH"
  if ! ditto "$app_path" "$INSTALL_PATH"; then
    die "failed to copy signed app to install path"
  fi
  if ! codesign --verify --deep --strict "$INSTALL_PATH" >/dev/null 2>&1; then
    die "installed app failed signature verification"
  fi

  INSTALL_SUCCEEDED=1
  write_stage_report "$stage_label" "$archive_path" "$archive_label" "$identity" "$verification_result" "$bundle_id"

  echo ""
  echo "============================================"
  echo "✅ $stage_label installed to $INSTALL_PATH"
  echo "============================================"
}

check_cert() {
  echo "→ Checking for certificate '$CERT_NAME'..."
  if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo "  ✅ Certificate found"
  else
    echo "  ❌ Certificate '$CERT_NAME' not found in keychain!"
    echo ""
    echo "  Run this first to generate and import the cert:"
    echo "    ./scripts/create-signing-cert.sh"
    echo ""
    echo "  Then import the .p12 into your login keychain:"
    echo "    security import /path/to/signing-cert.p12 -P <password> -k ~/Library/Keychains/login.keychain-db"
    exit 1
  fi
}

clean_workspace() {
  local target="$1"
  target="$(canonicalize_path "$target")"
  validate_clean_workspace "$target"
  echo "Cleaning test artifacts in $target..."
  rm -rf "$target"
  echo "✅ Cleaned $target"
}

parse_args() {
  local args=("$@")
  local positional=()
  local index=0

  while [[ $index -lt ${#args[@]} ]]; do
    case "${args[$index]}" in
      --install-path)
        index=$((index + 1))
        [[ $index -lt ${#args[@]} ]] || die "--install-path requires a value"
        INSTALL_PATH="${args[$index]}"
        ;;
      --allow-system-install)
        ALLOW_SYSTEM_INSTALL=1
        ;;
      --workspace)
        index=$((index + 1))
        [[ $index -lt ${#args[@]} ]] || die "--workspace requires a value"
        WORKSPACE_PATH="${args[$index]}"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        index=$((index + 1))
        while [[ $index -lt ${#args[@]} ]]; do
          positional+=("${args[$index]}")
          index=$((index + 1))
        done
        break
        ;;
      -*)
        die "unknown option: ${args[$index]}"
        ;;
      *)
        positional+=("${args[$index]}")
        ;;
    esac
    index=$((index + 1))
  done

  if [[ ${#positional[@]} -eq 0 ]]; then
    CMD="help"
  else
    CMD="${positional[0]}"
  fi
}

prepare_install_command() {
  validate_install_path
}

parse_args "$@"

case "$CMD" in
  build-v1)
    prepare_install_command
    check_cert
    build_archive "v1"
    sign_and_install "build-v1" "$CERT_NAME" "v1"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Open Cue from $INSTALL_PATH"
    echo "   2. Grant Screen Recording permission in System Settings"
    echo "   3. Grant Microphone permission (if prompted)"
    echo "   4. Run: ./scripts/test-tcc-local.sh build-v2"
    ;;

  build-v2)
    prepare_install_command
    check_cert
    build_archive "v1"
    sign_and_install "build-v2" "$CERT_NAME" "v1"
    echo ""
    echo "📋 Check:"
    echo "   1. Open Cue from $INSTALL_PATH"
    echo "   2. Verify Screen Recording + Microphone permissions are STILL granted"
    echo "   3. (Optional) Run: ./scripts/test-tcc-local.sh compare"
    ;;

  compare)
    prepare_install_command
    echo "=== Ad-hoc comparison build ==="
    build_archive "v1"
    sign_and_install "compare" "-" "v1"
    echo ""
    echo "📋 Check:"
    echo "   1. Open Cue from $INSTALL_PATH"
    echo "   2. Observe: permissions are LOST (expected with ad-hoc)"
    ;;

  clean)
    clean_workspace "$WORKSPACE_PATH"
    ;;

  help)
    usage
    ;;

  *)
    usage
    exit 1
    ;;
esac
