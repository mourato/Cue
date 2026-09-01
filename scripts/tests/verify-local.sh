#!/bin/bash
# Fixture tests for scripts/verify-local.sh and scripts/verification-map.tsv.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_LOCAL="${ROOT_DIR}/scripts/verify-local.sh"
MAP_FILE="${ROOT_DIR}/scripts/verification-map.tsv"

TESTS_RUN=0
TESTS_PASSED=0
FAILURES=()

pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
  local name="$1"
  local detail="$2"
  FAILURES+=("${name}: ${detail}")
  printf 'FAIL: %s — %s\n' "$name" "$detail" >&2
}

assert_exit() {
  local name="$1"
  local expected="$2"
  shift 2
  TESTS_RUN=$((TESTS_RUN + 1))
  set +e
  "$@" >/dev/null 2>&1
  local actual=$?
  set -e
  if [[ "$actual" -eq "$expected" ]]; then
    pass
    printf 'ok  %s (exit %s)\n' "$name" "$actual"
  else
    fail "$name" "expected exit ${expected}, got ${actual}"
  fi
}

assert_output_contains() {
  local name="$1"
  local needle="$2"
  shift 2
  TESTS_RUN=$((TESTS_RUN + 1))
  local output
  set +e
  output="$("$@" 2>&1)"
  local status=$?
  set -e
  if printf '%s' "$output" | grep -Fq -- "$needle"; then
    pass
    printf 'ok  %s (found %s)\n' "$name" "$needle"
  else
    fail "$name" "output missing ${needle} (exit ${status})"
  fi
}

validate_map_rows() {
  TESTS_RUN=$((TESTS_RUN + 1))
  local invalid=0
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == glob$'\t'* ]] && continue
    local count
    count="$(printf '%s' "$line" | awk -F '\t' '{print NF}')"
    if [[ "$count" -ne 5 ]]; then
      invalid=1
      printf 'invalid field count (%s): %s\n' "$count" "$line" >&2
    fi
    if printf '%s' "$line" | grep -Eq '`|\$\(|;[[:space:]]*(source|eval)'; then
      invalid=1
      printf 'executable shell syntax in map row: %s\n' "$line" >&2
    fi
  done <"$MAP_FILE"

  if [[ "$invalid" -eq 0 ]]; then
    pass
    printf 'ok  map rows have five fields and no shell snippets\n'
  else
    fail "map row validation" "invalid verification-map.tsv rows"
  fi
}

validate_selectors_exist() {
  TESTS_RUN=$((TESTS_RUN + 1))
  local missing=0
  while IFS=$'\t' read -r _glob profile selector _manual _reason; do
    [[ "$_glob" == "glob" || -z "$selector" ]] && continue
    [[ "$profile" == "xctest" || "$profile" == "video-module" ]] || continue
    local class="${selector#CueTests/}"
    local found
    found="$(find "${ROOT_DIR}/NotinhasTests" -name "${class}.swift" | head -n 1 || true)"
    if [[ -z "$found" ]]; then
      missing=1
      printf 'missing selector file for %s\n' "$selector" >&2
    fi
  done <"$MAP_FILE"

  if [[ "$missing" -eq 0 ]]; then
    pass
    printf 'ok  referenced XCTest selectors exist\n'
  else
    fail "selector validation" "verification-map.tsv references missing selectors"
  fi
}

install_verify_bundle() {
  local repo="$1"
  mkdir -p "${repo}/scripts/tests" "${repo}/build/verification"
  cp "$VERIFY_LOCAL" "${repo}/scripts/verify-local.sh"
  cp "$MAP_FILE" "${repo}/scripts/verification-map.tsv"
  chmod +x "${repo}/scripts/verify-local.sh"
}

run_verify() {
  local repo="$1"
  shift
  (
    cd "$repo"
    ./scripts/verify-local.sh "$@"
  )
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/verify-local-fixture.XXXXXX")"
  (
    cd "$tmp"
    git init -q
    git config user.email "fixture@example.com"
    git config user.name "Fixture"
    mkdir -p scripts Cue/Features/Notinhas Cue/Features/Annotate \
      Cue/Services/Capture Cue/Features/Recording \
      Cue/Features/VideoEditor docs .agents/skills/sample
    echo "base" >README.md
    git add .
    git commit -q -m "base"
    git branch -M main
    git branch base
  )
  install_verify_bundle "$tmp"
  git -C "$tmp" add scripts/verify-local.sh scripts/verification-map.tsv
  git -C "$tmp" commit -q -m "add verify-local"
  printf '%s' "$tmp"
}

verify_base() {
  printf 'base'
}

touch_and_commit() {
  local repo="$1"
  local rel_path="$2"
  local parent
  parent="$(dirname "${repo}/${rel_path}")"
  mkdir -p "$parent"
  echo "change" >>"${repo}/${rel_path}"
  git -C "$repo" add "${rel_path}"
  git -C "$repo" commit -q -m "change ${rel_path}"
}

tracked_snapshot() {
  local repo="$1"
  git -C "$repo" diff --name-only
  git -C "$repo" diff --name-only --cached
}

main() {
  [[ -x "$VERIFY_LOCAL" ]] || chmod +x "$VERIFY_LOCAL"
  bash -n "$VERIFY_LOCAL"

  assert_exit "help exits zero" 0 "$VERIFY_LOCAL" --help
  assert_output_contains "help documents base" "--base" "$VERIFY_LOCAL" --help
  assert_output_contains "help documents plan-only" "--plan-only" "$VERIFY_LOCAL" --help
  assert_output_contains "help documents strict" "--strict" "$VERIFY_LOCAL" --help
  assert_output_contains "help documents full" "--full" "$VERIFY_LOCAL" --help
  assert_output_contains "help documents video-module" "--video-module" "$VERIFY_LOCAL" --help
  assert_output_contains "help documents report output" "build/verification/" "$VERIFY_LOCAL" --help

  validate_map_rows
  validate_selectors_exist

  local repo
  repo="$(setup_repo)"

  assert_exit "missing base ref fails" 1 run_verify "$repo" --base does-not-exist --plan-only
  rm -rf "$repo"

  local base_ref
  base_ref="$(verify_base)"

  local notinhas_repo
  notinhas_repo="$(setup_repo)"
  touch_and_commit "$notinhas_repo" "Cue/Features/Cue/CueNoteGeometry.swift"
  assert_output_contains "notinhas path selects geometry tests" \
    "CueTests/CueNoteGeometryTests" \
    run_verify "$notinhas_repo" --base "$base_ref" --plan-only
  assert_exit "notinhas strict passes" 0 run_verify "$notinhas_repo" --base "$base_ref" --plan-only --strict
  rm -rf "$notinhas_repo"

  local annotate_repo
  annotate_repo="$(setup_repo)"
  touch_and_commit "$annotate_repo" "Cue/Features/Annotate/AnnotateCore.swift"
  assert_output_contains "annotate path selects annotate tests" \
    "CueTests/AnnotateCoreTests" \
    run_verify "$annotate_repo" --base "$base_ref" --plan-only
  rm -rf "$annotate_repo"

  local capture_repo
  capture_repo="$(setup_repo)"
  touch_and_commit "$capture_repo" "Cue/Services/Capture/AreaSelectionModels.swift"
  assert_output_contains "capture path selects capture tests" \
    "CueTests/AreaSelectionModelsTests" \
    run_verify "$capture_repo" --base "$base_ref" --plan-only
  assert_output_contains "capture path flags manual gate" "manual_required:" \
    run_verify "$capture_repo" --base "$base_ref" --plan-only
  assert_exit "capture strict fails" 1 run_verify "$capture_repo" --base "$base_ref" --plan-only --strict
  rm -rf "$capture_repo"

  local recording_repo
  recording_repo="$(setup_repo)"
  touch_and_commit "$recording_repo" "Cue/Features/Recording/RecordingSession.swift"
  assert_output_contains "recording path selects video profile" "video-module" \
    run_verify "$recording_repo" --base "$base_ref" --plan-only
  assert_output_contains "recording path selects recording tests" \
    "CueTests/RecordingSessionTests" \
    run_verify "$recording_repo" --base "$base_ref" --plan-only
  rm -rf "$recording_repo"

  local scripts_repo
  scripts_repo="$(setup_repo)"
  mkdir -p "${scripts_repo}/scripts"
  cat >"${scripts_repo}/scripts/sample.sh" <<'EOF'
#!/bin/bash
usage() { echo "sample"; }
case "$1" in -h|--help) usage; exit 0;; esac
EOF
  chmod +x "${scripts_repo}/scripts/sample.sh"
  git -C "$scripts_repo" add scripts/sample.sh
  git -C "$scripts_repo" commit -q -m "add sample script"
  assert_output_contains "scripts path uses shell checks" "bash -n" \
    run_verify "$scripts_repo" --base "$base_ref" --plan-only
  assert_output_contains "scripts path avoids xctest" "xctest_selectors:" \
    run_verify "$scripts_repo" --base "$base_ref" --plan-only
  assert_exit "scripts-only strict passes" 0 \
    run_verify "$scripts_repo" --base "$base_ref" --plan-only --strict
  rm -rf "$scripts_repo"

  local docs_repo
  docs_repo="$(setup_repo)"
  touch_and_commit "$docs_repo" "docs/DEVELOPMENT.md"
  assert_output_contains "docs path lists documentation checks" "documentation_checks:" \
    run_verify "$docs_repo" --base "$base_ref" --plan-only
  rm -rf "$docs_repo"

  local unknown_repo
  unknown_repo="$(setup_repo)"
  touch_and_commit "$unknown_repo" "Cue/Features/History/HistoryPanel.swift"
  assert_output_contains "unknown app path is manual-required" "manual-required" \
    run_verify "$unknown_repo" --base "$base_ref" --plan-only
  assert_exit "unknown app path strict fails" 1 \
    run_verify "$unknown_repo" --base "$base_ref" --plan-only --strict
  rm -rf "$unknown_repo"

  local side_effects_repo
  side_effects_repo="$(setup_repo)"
  before_tracked="$(tracked_snapshot "$side_effects_repo" | LC_ALL=C sort -u | paste -sd, -)"
  touch_and_commit "$side_effects_repo" "docs/DEVELOPMENT.md"
  run_verify "$side_effects_repo" --base "$base_ref" --plan-only >/dev/null
  after_tracked="$(tracked_snapshot "$side_effects_repo" | LC_ALL=C sort -u | paste -sd, -)"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$before_tracked" == "$after_tracked" ]]; then
    pass
    printf 'ok  plan-only does not modify tracked files\n'
  else
    fail "plan-only side effects" "tracked files changed (${before_tracked} -> ${after_tracked})"
  fi
  rm -rf "$side_effects_repo"

  rm -rf "$repo"

  printf '\nverify-local fixtures: %s/%s passed\n' "$TESTS_PASSED" "$TESTS_RUN"
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    printf 'failures:\n' >&2
    printf '  - %s\n' "${FAILURES[@]}" >&2
    exit 1
  fi
}

main "$@"
