#!/usr/bin/env bash
# uninstall.sh — Completely remove Cue and reset ALL related permissions
#
# Usage:
#   ./uninstall.sh           # Interactive mode (asks for confirmation)
#   ./uninstall.sh --force   # Skip confirmation
#
# What this script does:
#   1. Kills the running app
#   2. Resets ALL TCC permissions (Screen Recording, Microphone, Accessibility, etc.)
#   3. Removes Cue.app from /Applications (and legacy Notinhas/Snapzy bundles)
#   4. Removes Application Support data (captures, preferences, caches)
#   5. Removes user preferences (defaults)
#   6. Removes saved application state
#   7. Removes login items
#   8. Cleans temp files
#
# NOTE: TCC reset (step 2) runs BEFORE app removal (step 3) because tccutil
#       validates the bundle identifier via LaunchServices at runtime. Once
#       the .app bundle is deleted, LaunchServices can no longer resolve the
#       bundle ID and tccutil will fail with OSStatus error -10814.

set -euo pipefail

APP_NAME="Cue"
APP_PATH="/Applications/Cue.app"
FALLBACK_BUNDLE_ID="com.mourato.cue"
LEGACY_APP_PATHS=(
  "/Applications/Notinhas.app"
  "/Applications/Snapzy.app"
)
LEGACY_BUNDLE_IDS=(
  "com.mourato.cue.debug"
  "com.mourato.notinhas"
  "com.mourato.notinhas.debug"
  "com.trongduong.snapzy"
)
LEGACY_APP_SUPPORT_NAMES=(
  "Cue"
  "Notinhas"
  "Snapzy"
  "snapzy"
  "notinhas"
)

# ─── Auto-detect bundle ID from app name ─────────────────────────
# Must happen BEFORE the app is deleted (step 3).
# Strategy: osascript (LaunchServices) → PlistBuddy (.app bundle) → fallback
resolve_bundle_id() {
  local detected=""

  # Method 1: Ask LaunchServices via osascript (works even if app is not in /Applications)
  detected=$(osascript -e "id of app \"$APP_NAME\"" 2>/dev/null || true)
  if [[ -n "$detected" ]]; then
    echo "$detected"
    return
  fi

  # Method 2: Read directly from the .app bundle's Info.plist
  if [ -d "$APP_PATH" ]; then
    detected=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)
    if [[ -n "$detected" ]]; then
      echo "$detected"
      return
    fi
  fi

  # Fallback: hardcoded
  echo "$FALLBACK_BUNDLE_ID"
}

BUNDLE_ID=$(resolve_bundle_id)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}→${NC} $*"; }
success() { echo -e "${GREEN}✅${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠️${NC}  $*"; }
error()   { echo -e "${RED}❌${NC} $*"; }

reset_tcc_for_bundle() {
  local bundle_id="$1"
  [[ -z "$bundle_id" ]] && return 0

  local service
  for service in "${TCC_SERVICES[@]}"; do
    info "Resetting $service for $bundle_id..."
    if tccutil reset "$service" "$bundle_id" 2>/dev/null; then
      success "Reset $service for $bundle_id"
    else
      warn "Could not reset $service for $bundle_id"
      tcc_had_failure=true
    fi
  done

  info "Running catch-all TCC reset for $bundle_id..."
  if tccutil reset All "$bundle_id" 2>/dev/null; then
    success "Reset all remaining TCC entries for $bundle_id"
  else
    info "No additional TCC entries to reset for $bundle_id"
  fi
}

# ─── Confirmation ────────────────────────────────────────────────
if [[ "${1:-}" != "--force" ]]; then
  echo ""
  echo -e "${RED}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║  ⚠️  COMPLETE UNINSTALL: $APP_NAME                    ║${NC}"
  echo -e "${RED}╠══════════════════════════════════════════════════════╣${NC}"
  echo -e "${RED}║  This will:                                         ║${NC}"
  echo -e "${RED}║  • Delete $APP_NAME.app from /Applications           ║${NC}"
  echo -e "${RED}║  • Remove legacy Notinhas/Snapzy bundles if present ║${NC}"
  echo -e "${RED}║  • Remove all app data & preferences                ║${NC}"
  echo -e "${RED}║  • Reset ALL TCC permissions                        ║${NC}"
  echo -e "${RED}║  • Remove login items & caches                      ║${NC}"
  echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
  echo ""
  read -rp "Are you sure? Type 'yes' to proceed: " confirm < /dev/tty
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
  echo ""
fi

info "Detected bundle ID: ${BUNDLE_ID}"
echo ""

# ─── 1. Kill running app ────────────────────────────────────────
info "Stopping $APP_NAME..."
killall "$APP_NAME" 2>/dev/null && success "App stopped" || info "App was not running"
killall "Notinhas" 2>/dev/null && success "Legacy Notinhas process stopped" || true
killall "Snapzy" 2>/dev/null && success "Legacy Snapzy process stopped" || true
sleep 1

# ─── 2. Reset ALL TCC permissions ───────────────────────────────
# IMPORTANT: This MUST run BEFORE removing the app bundle (step 3).
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  Resetting TCC Permissions                           ${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo ""

# TCC services used by Cue
# NOTE: tccutil uses SHORT names (not kTCCService* constants)
TCC_SERVICES=(
  "ScreenCapture"      # Screen Recording (shown as "Screen & System Audio Recording" on macOS 15+)
  "Microphone"         # Microphone
  "Accessibility"      # Accessibility
  "PostEvent"          # Input Monitoring (synthetic events)
  "ListenEvent"        # Input Monitoring (listen)
)

tcc_had_failure=false

reset_tcc_for_bundle "$BUNDLE_ID"
for legacy_id in "${LEGACY_BUNDLE_IDS[@]}"; do
  [[ "$legacy_id" == "$BUNDLE_ID" ]] && continue
  reset_tcc_for_bundle "$legacy_id"
done

if $tcc_had_failure; then
  echo ""
  warn "Some TCC resets could not be completed automatically."
  info "If you face permission issues after reinstalling, you can manually remove"
  info "$APP_NAME from System Settings > Privacy & Security for the affected services."
fi

# ─── 3. Remove app bundle ───────────────────────────────────────
echo ""
info "Removing $APP_PATH..."
if [ -d "$APP_PATH" ]; then
  rm -rf "$APP_PATH"
  success "Removed $APP_PATH"
else
  info "$APP_PATH not found (already removed)"
fi

for legacy_app in "${LEGACY_APP_PATHS[@]}"; do
  if [ -d "$legacy_app" ]; then
    info "Removing legacy app bundle $legacy_app..."
    rm -rf "$legacy_app"
    success "Removed $legacy_app"
  fi
done

# ─── 4. Remove Application Support data ─────────────────────────
info "Checking Application Support data..."
for support_name in "${LEGACY_APP_SUPPORT_NAMES[@]}"; do
  app_support="$HOME/Library/Application Support/$support_name"
  [[ -d "$app_support" ]] || continue
  echo ""
  warn "Folder contains temporary captures/recordings:"
  echo "     $app_support"
  if [[ "${1:-}" != "--force" ]]; then
    read -rp "  Delete this folder? (y/n): " del_app_support < /dev/tty
    if [[ "$del_app_support" == "y" || "$del_app_support" == "Y" ]]; then
      rm -rf "$app_support"
      success "Removed $app_support"
    else
      info "Kept $app_support"
    fi
  else
    rm -rf "$app_support"
    success "Removed $app_support"
  fi
done

# ─── 5. Remove user preferences (defaults) ──────────────────────
info "Removing user preferences..."
for prefs_id in "$BUNDLE_ID" "${LEGACY_BUNDLE_IDS[@]}"; do
  defaults delete "$prefs_id" 2>/dev/null && success "Removed defaults for $prefs_id" || true
  plist_file="$HOME/Library/Preferences/${prefs_id}.plist"
  if [ -f "$plist_file" ]; then
    rm -f "$plist_file"
    success "Removed $plist_file"
  fi
done

# ─── 6. Remove caches ───────────────────────────────────────────
info "Removing caches..."
for cache_id in "$BUNDLE_ID" "${LEGACY_BUNDLE_IDS[@]}"; do
  for cache_dir in \
    "$HOME/Library/Caches/$cache_id" \
    "$HOME/Library/HTTPStorages/$cache_id"; do
    if [ -d "$cache_dir" ]; then
      rm -rf "$cache_dir"
      success "Removed $cache_dir"
    fi
  done
done
for cache_name in "${LEGACY_APP_SUPPORT_NAMES[@]}"; do
  cache_dir="$HOME/Library/Caches/$cache_name"
  if [ -d "$cache_dir" ]; then
    rm -rf "$cache_dir"
    success "Removed $cache_dir"
  fi
done

# ─── 7. Remove saved application state ──────────────────────────
info "Removing saved application state..."
for state_id in "$BUNDLE_ID" "${LEGACY_BUNDLE_IDS[@]}"; do
  saved_state="$HOME/Library/Saved Application State/${state_id}.savedState"
  if [ -d "$saved_state" ]; then
    rm -rf "$saved_state"
    success "Removed $saved_state"
  fi
done

# ─── 8. Remove logs ─────────────────────────────────────────────
info "Removing diagnostic logs..."
for logs_dir in \
  "$HOME/Library/Logs/Cue" \
  "$HOME/Library/Logs/Notinhas" \
  "$HOME/Library/Logs/Snapzy"; do
  if [ -d "$logs_dir" ]; then
    rm -rf "$logs_dir"
    success "Removed $logs_dir"
  fi
done

# ─── 9. Login items ─────────────────────────────────────────────
# NOTE: sfltool resetbtm resets ALL apps' login items, not just Cue.
# Skipped intentionally to avoid affecting other applications.
info "Login items: skipped (no safe per-app reset available)"

# ─── 10. Clean temp files ──────────────────────────────────────
info "Cleaning temp files..."
for tmp_dir in \
  "/tmp/test-tcc-snapzy" \
  "/tmp/$APP_NAME" \
  "/tmp/Notinhas" \
  "/tmp/Snapzy" \
  "/tmp/${BUNDLE_ID}"; do
  if [ -d "$tmp_dir" ]; then
    rm -rf "$tmp_dir"
    success "Removed $tmp_dir"
  fi
done

# ─── 11. Sandbox containers ─────────────────────────────────────
# Cue does NOT use App Sandbox. If a container exists, it's from
# macOS internal bookkeeping and requires sudo to remove.
container_ids=("$BUNDLE_ID" "${LEGACY_BUNDLE_IDS[@]}")
for container_id in "${container_ids[@]}"; do
  container="$HOME/Library/Containers/$container_id"
  if [ -d "$container" ]; then
    warn "Sandbox container exists at $container"
    info "  To remove manually: sudo rm -rf '$container'"
  fi
done

# ─── Done ────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ $APP_NAME has been completely uninstalled         ║${NC}"
echo -e "${GREEN}║  ✅ All TCC permissions have been reset              ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  To reinstall, download from:                       ║${NC}"
echo -e "${GREEN}║  https://github.com/mourato/Cue/releases              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}💡 Tip: You may need to log out and back in (or reboot)${NC}"
echo -e "${YELLOW}   for TCC changes to fully take effect.${NC}"
echo ""
