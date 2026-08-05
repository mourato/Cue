#!/bin/bash
# Changed-surface local verification planner/runner for Notinhas.
#
# Usage:
#   ./scripts/verify-local.sh --base main --plan-only
#   ./scripts/verify-local.sh --base main --execute
#   ./scripts/verify-local.sh --base main --plan-only --strict
#   ./scripts/verify-local.sh --full --execute

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP_FILE="${REPO_ROOT}/scripts/verification-map.tsv"
RUN_TESTS="${REPO_ROOT}/scripts/run-tests.sh"

BASE_REF="main"
PLAN_ONLY=1
EXECUTE=0
STRICT=0
FULL=0
FORCE_VIDEO=0
REPORT_PATH=""

CHANGED_PATHS=()
declare -a MATCHED_PROFILES=()
declare -a XCTEST_SELECTORS=()
declare -a VIDEO_SELECTORS=()
declare -a SHELL_SCRIPTS=()
declare -a DOC_PATHS=()
declare -a MANUAL_ITEMS=()
declare -a UNMAPPED_PATHS=()
declare -a RESOLVED_COMMANDS=()

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Plan or run deterministic local verification for files changed since --base.
Default mode is --plan-only: print the resolved plan and optional report without
running tests, builds, or UI actions unless --execute is supplied.

Options:
  --base REF            Git ref to diff against. Default: ${BASE_REF}
  --plan-only           Print the verification plan only (default).
  --execute             Run the resolved deterministic checks after planning.
  --strict              Fail when any path is unmapped or manual-required.
  --full                Delegate to ./scripts/run-tests.sh without changed-surface
                        narrowing (still respects --execute).
  --video-module        Force ./scripts/run-tests.sh --video-module when running
                        XCTest selectors (also selected automatically for Video
                        profile paths).
  --report PATH         Write the text report to PATH. When omitted, plan-only
                        mode writes under build/verification/ when that directory
                        can be created.
  -h, --help            Show this help and exit.

Report output:
  Stable sections list changed paths, profiles, XCTest selectors, shell checks,
  documentation routing checks, manual-required items, and resolved commands.
  Plan-only mode does not mutate tracked Git state.

Examples:
  ${SCRIPT_NAME} --help
  ${SCRIPT_NAME} --base main --plan-only
  ${SCRIPT_NAME} --base main --plan-only --strict
  ${SCRIPT_NAME} --base main --execute
  ${SCRIPT_NAME} --full --execute
EOF
}

die() {
  printf 'verify-local: error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf 'verify-local: %s\n' "$*"
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      --base)
        shift
        [[ $# -gt 0 ]] || die "--base requires a ref"
        BASE_REF="$1"
        shift
        ;;
      --plan-only)
        PLAN_ONLY=1
        shift
        ;;
      --execute)
        EXECUTE=1
        shift
        ;;
      --strict)
        STRICT=1
        shift
        ;;
      --full)
        FULL=1
        shift
        ;;
      --video-module)
        FORCE_VIDEO=1
        shift
        ;;
      --report)
        shift
        [[ $# -gt 0 ]] || die "--report requires a path"
        REPORT_PATH="$1"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        die "unknown option: $1"
        ;;
      *)
        die "unexpected argument: $1"
        ;;
    esac
  done
}

require_map() {
  [[ -f "$MAP_FILE" ]] || die "verification map missing: ${MAP_FILE}"
}

collect_changed_paths() {
  if ! git -C "$REPO_ROOT" rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
    die "base ref unavailable: ${BASE_REF}"
  fi

  local -a paths=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && paths+=("$line")
  done < <(
    {
      git -C "$REPO_ROOT" diff --name-only "$BASE_REF" HEAD
      git -C "$REPO_ROOT" diff --name-only HEAD
      git -C "$REPO_ROOT" diff --name-only --cached
    } | LC_ALL=C sort -u
  )

  if [[ ${#paths[@]} -eq 0 ]]; then
    CHANGED_PATHS=()
    return 0
  fi

  CHANGED_PATHS=("${paths[@]}")
}

resolve_matches() {
  MATCHED_PROFILES=()
  XCTEST_SELECTORS=()
  VIDEO_SELECTORS=()
  SHELL_SCRIPTS=()
  DOC_PATHS=()
  MANUAL_ITEMS=()
  UNMAPPED_PATHS=()

  if [[ ${#CHANGED_PATHS[@]} -eq 0 ]]; then
    return 0
  fi

  local python_output
  python_output="$(
    REPO_ROOT="$REPO_ROOT" MAP_FILE="$MAP_FILE" python3 - "$BASE_REF" "${CHANGED_PATHS[@]}" <<'PY'
import os
import re
import sys
from pathlib import PurePosixPath

repo_root = os.environ["REPO_ROOT"]
map_file = os.environ["MAP_FILE"]
changed = sys.argv[2:]


def path_matches_glob(path: str, pattern: str) -> bool:
    if "**" not in pattern:
        return PurePosixPath(path).match(pattern)
    parts = pattern.split("**")
    regex = "^"
    for index, segment in enumerate(parts):
        if index > 0:
            regex += ".*"
        regex += re.escape(segment).replace(r"\*", "[^/]*")
    regex += "$"
    return re.match(regex, path) is not None


rows = []
with open(map_file, encoding="utf-8") as handle:
    for line in handle:
        line = line.rstrip("\n")
        if not line or line.startswith("glob\t"):
            continue
        parts = line.split("\t")
        if len(parts) != 5:
            raise SystemExit(f"invalid map row ({len(parts)} fields): {line}")
        rows.append(
            {
                "glob": parts[0],
                "profile": parts[1],
                "selector": parts[2],
                "manual": parts[3],
                "reason": parts[4],
            }
        )

def specificity(pattern: str) -> int:
    return len(pattern.replace("**", "").replace("*", ""))

def matches(path: str, pattern: str) -> bool:
    return path_matches_glob(path, pattern)

def best_glob(path: str):
    candidates = [row["glob"] for row in rows if matches(path, row["glob"])]
    if not candidates:
        return None
    return max(candidates, key=specificity)

profiles = set()
selectors = []
video_selectors = []
shell_scripts = []
doc_paths = []
manual_items = []
unmapped = []

for path in changed:
    glob = best_glob(path)
    if glob is None:
        unmapped.append(path)
        manual_items.append(f"{path}\tunmapped\tNo verification-map entry matches this path")
        continue

    matched_rows = [row for row in rows if row["glob"] == glob]
    profile_names = {row["profile"] for row in matched_rows}
    profiles.update(profile_names)

    if "manual-required" in profile_names:
        for row in matched_rows:
            if row["profile"] == "manual-required":
                manual_items.append(f"{path}\tmanual-required\t{row['reason']}")
        continue

    if glob == "scripts/**" and path.startswith("scripts/") and path.endswith(".sh"):
        shell_scripts.append(path)

    if profile_names & {"docs"} and (
        path.startswith("docs/")
        or path.startswith(".agents/skills/")
        or path == "AGENTS.md"
        or path.startswith("plans/")
    ):
        doc_paths.append(path)

    for row in matched_rows:
        if row["manual"] in {"yes", "required"}:
            manual_items.append(f"{path}\t{row['profile']}\t{row['reason']}")
        if row["profile"] == "xctest" and row["selector"]:
            selectors.append(row["selector"])
        if row["profile"] == "video-module" and row["selector"]:
            video_selectors.append(row["selector"])

selectors = sorted(set(selectors))
video_selectors = sorted(set(video_selectors))
shell_scripts = sorted(set(shell_scripts))
doc_paths = sorted(set(doc_paths))
unmapped = sorted(set(unmapped))

print("PROFILES\t" + ",".join(sorted(profiles)))
print("SELECTORS\t" + ",".join(selectors))
print("VIDEO_SELECTORS\t" + ",".join(video_selectors))
print("SHELL\t" + ",".join(shell_scripts))
print("DOCS\t" + ",".join(doc_paths))
print("UNMAPPED\t" + ",".join(unmapped))
for item in manual_items:
    print("MANUAL\t" + item)
PY
  )"

  local line key value
  while IFS= read -r line; do
    key="${line%%$'\t'*}"
    value="${line#*$'\t'}"
    case "$key" in
      PROFILES)
        IFS=',' read -r -a _profiles <<<"$value"
        if [[ -n "${value}" ]]; then
          MATCHED_PROFILES=("${_profiles[@]}")
        fi
        ;;
      SELECTORS)
        IFS=',' read -r -a _selectors <<<"$value"
        if [[ -n "${value}" ]]; then
          XCTEST_SELECTORS=("${_selectors[@]}")
        fi
        ;;
      VIDEO_SELECTORS)
        IFS=',' read -r -a _video <<<"$value"
        if [[ -n "${value}" ]]; then
          VIDEO_SELECTORS=("${_video[@]}")
        fi
        ;;
      SHELL)
        IFS=',' read -r -a _shell <<<"$value"
        if [[ -n "${value}" ]]; then
          SHELL_SCRIPTS=("${_shell[@]}")
        fi
        ;;
      DOCS)
        IFS=',' read -r -a _docs <<<"$value"
        if [[ -n "${value}" ]]; then
          DOC_PATHS=("${_docs[@]}")
        fi
        ;;
      UNMAPPED)
        IFS=',' read -r -a _unmapped <<<"$value"
        if [[ -n "${value}" ]]; then
          UNMAPPED_PATHS=("${_unmapped[@]}")
        fi
        ;;
      MANUAL)
        MANUAL_ITEMS+=("$value")
        ;;
    esac
  done <<<"$python_output"
}

script_supports_help() {
  local script_path="$1"
  grep -Eq '(-h\|--help)|(^|[[:space:]])usage\(\)' "$script_path"
}

build_commands() {
  RESOLVED_COMMANDS=()

  if [[ "$FULL" -eq 1 ]]; then
    RESOLVED_COMMANDS+=("make format-check")
    RESOLVED_COMMANDS+=("make lint")
    RESOLVED_COMMANDS+=("${RUN_TESTS}")
    return 0
  fi

  local needs_swift_quality=0
  local changed_path
  for changed_path in "${CHANGED_PATHS[@]}"; do
    if [[ "$changed_path" == *.swift || "$changed_path" == ".swiftformat" || \
          "$changed_path" == ".swiftlint.yml" || "$changed_path" == "Makefile" ]]; then
      needs_swift_quality=1
      break
    fi
  done
  if [[ "$needs_swift_quality" -eq 1 ]]; then
    RESOLVED_COMMANDS+=("make format-check")
    RESOLVED_COMMANDS+=("make lint")
  fi

  if [[ ${#SHELL_SCRIPTS[@]} -gt 0 ]]; then
    local script
    for script in "${SHELL_SCRIPTS[@]}"; do
      local abs="${REPO_ROOT}/${script}"
      RESOLVED_COMMANDS+=("bash -n ${abs}")
      if script_supports_help "$abs"; then
        RESOLVED_COMMANDS+=("${abs} --help")
      fi
    done
  fi

  if [[ ${#DOC_PATHS[@]} -gt 0 ]]; then
    RESOLVED_COMMANDS+=("git -C ${REPO_ROOT} diff --check ${BASE_REF} -- ${DOC_PATHS[*]}")
  fi

  local -a selectors=()
  local use_video=0
  if [[ ${#VIDEO_SELECTORS[@]} -gt 0 ]]; then
    use_video=1
    selectors+=("${VIDEO_SELECTORS[@]}")
  fi
  if [[ ${#XCTEST_SELECTORS[@]} -gt 0 ]]; then
    selectors+=("${XCTEST_SELECTORS[@]}")
  fi

  if [[ ${#selectors[@]} -gt 0 ]]; then
  selectors=($(printf '%s\n' "${selectors[@]}" | LC_ALL=C sort -u))
    local -a args=()
    if [[ "$use_video" -eq 1 || "$FORCE_VIDEO" -eq 1 ]]; then
      args+=("--video-module")
    fi
    local selector
    for selector in "${selectors[@]}"; do
      args+=("-only-testing:${selector}")
    done
    RESOLVED_COMMANDS+=("${RUN_TESTS} ${args[*]}")
  fi
}

write_report() {
  local destination="$1"
  local mode="plan-only"
  if [[ "$EXECUTE" -eq 1 ]]; then
    mode="execute"
  fi

  mkdir -p "$(dirname "$destination")"
  {
    printf 'verify-local: %s\n' "$mode"
    printf 'base: %s\n' "$BASE_REF"
    printf 'strict: %s\n' "$([[ "$STRICT" -eq 1 ]] && printf yes || printf no)"
    printf 'full: %s\n' "$([[ "$FULL" -eq 1 ]] && printf yes || printf no)"
    printf '\nchanged_paths:\n'
    if [[ ${#CHANGED_PATHS[@]} -eq 0 ]]; then
      printf '  (none)\n'
    else
      local path
      for path in "${CHANGED_PATHS[@]}"; do
        printf '  - %s\n' "$path"
      done
    fi
    printf '\nprofiles:\n'
    if [[ ${#MATCHED_PROFILES[@]} -eq 0 ]]; then
      printf '  (none)\n'
    else
      local profile
      for profile in "${MATCHED_PROFILES[@]}"; do
        printf '  - %s\n' "$profile"
      done
    fi
    printf '\nxctest_selectors:\n'
    if [[ ${#XCTEST_SELECTORS[@]} -eq 0 && ${#VIDEO_SELECTORS[@]} -eq 0 ]]; then
      printf '  (none)\n'
    else
      local selector
      if [[ ${#XCTEST_SELECTORS[@]} -gt 0 ]]; then
        for selector in "${XCTEST_SELECTORS[@]}"; do
          printf '  - %s\n' "$selector"
        done
      fi
      if [[ ${#VIDEO_SELECTORS[@]} -gt 0 ]]; then
        for selector in "${VIDEO_SELECTORS[@]}"; do
          printf '  - %s\n' "$selector"
        done
      fi
    fi
    printf '\nshell_checks:\n'
    if [[ ${#SHELL_SCRIPTS[@]} -eq 0 ]]; then
      printf '  (none)\n'
    else
      local script
      for script in "${SHELL_SCRIPTS[@]}"; do
        printf '  - bash -n %s\n' "${REPO_ROOT}/${script}"
        if script_supports_help "${REPO_ROOT}/${script}"; then
          printf '  - %s --help\n' "${REPO_ROOT}/${script}"
        fi
      done
    fi
    printf '\ndocumentation_checks:\n'
    if [[ ${#DOC_PATHS[@]} -eq 0 ]]; then
      printf '  (none)\n'
    else
      local doc
      for doc in "${DOC_PATHS[@]}"; do
        printf '  - %s\n' "$doc"
      done
    fi
    printf '\nmanual_required:\n'
    if [[ ${#MANUAL_ITEMS[@]} -eq 0 ]]; then
      printf '  (none)\n'
    else
      local item
      for item in "${MANUAL_ITEMS[@]}"; do
        printf '  - %s\n' "$item"
      done
    fi
    printf '\nunmapped_paths:\n'
    if [[ ${#UNMAPPED_PATHS[@]} -eq 0 ]]; then
      printf '  (none)\n'
    else
      local unmapped
      for unmapped in "${UNMAPPED_PATHS[@]}"; do
        printf '  - %s\n' "$unmapped"
      done
    fi
    printf '\nresolved_commands:\n'
    if [[ ${#RESOLVED_COMMANDS[@]} -eq 0 ]]; then
      printf '  (none)\n'
    else
      local command
      for command in "${RESOLVED_COMMANDS[@]}"; do
        printf '  - %s\n' "$command"
      done
    fi
  } >"$destination"
}

print_report_stdout() {
  local temp
  temp="$(mktemp "${TMPDIR:-/tmp}/verify-local-report.XXXXXX")"
  write_report "$temp"
  cat "$temp"
  rm -f "$temp"
}

strict_failure() {
  # Plan-only strict validates that every path is mapped while retaining
  # manual-required items as visible handoff gates. Execute mode still fails
  # when those manual gates remain incomplete.
  [[ ${#UNMAPPED_PATHS[@]} -gt 0 || ( "$EXECUTE" -eq 1 && ${#MANUAL_ITEMS[@]} -gt 0 ) ]]
}

run_commands() {
  local status=0
  local script abs selector
  local -a selectors=()
  local -a test_args=()

  if [[ "$FULL" -eq 1 ]]; then
    info "running: ${RUN_TESTS}"
    if [[ "$FORCE_VIDEO" -eq 1 ]]; then
      if ! "$RUN_TESTS" --video-module; then
        status=1
      fi
    elif ! "$RUN_TESTS"; then
      status=1
    fi
    return "$status"
  fi

  for script in "${SHELL_SCRIPTS[@]}"; do
    abs="${REPO_ROOT}/${script}"
    info "running: bash -n ${abs}"
    if ! bash -n "$abs"; then
      status=1
    fi
    if script_supports_help "$abs"; then
      info "running: ${abs} --help"
      if ! "$abs" --help; then
        status=1
      fi
    fi
  done

  if [[ ${#DOC_PATHS[@]} -gt 0 ]]; then
    info "running: git -C ${REPO_ROOT} diff --check ${BASE_REF} -- <documentation paths>"
    if ! git -C "$REPO_ROOT" diff --check "$BASE_REF" -- "${DOC_PATHS[@]}"; then
      status=1
    fi
  fi

  if [[ ${#VIDEO_SELECTORS[@]} -gt 0 ]]; then
    selectors+=("${VIDEO_SELECTORS[@]}")
  fi
  if [[ ${#XCTEST_SELECTORS[@]} -gt 0 ]]; then
    selectors+=("${XCTEST_SELECTORS[@]}")
  fi
  if [[ ${#selectors[@]} -gt 0 ]]; then
    if [[ "$FORCE_VIDEO" -eq 1 || ${#VIDEO_SELECTORS[@]} -gt 0 ]]; then
      test_args+=("--video-module")
    fi
    local sorted_selectors
    sorted_selectors="$(printf '%s\n' "${selectors[@]}" | LC_ALL=C sort -u)"
    while IFS= read -r selector; do
      [[ -n "$selector" ]] || continue
      test_args+=("-only-testing:${selector}")
    done <<<"$sorted_selectors"
    info "running: ${RUN_TESTS} ${test_args[*]}"
    if ! "$RUN_TESTS" "${test_args[@]}"; then
      status=1
    fi
  fi

  return "$status"
}

main() {
  parse_args "$@"
  require_map
  collect_changed_paths
  resolve_matches
  build_commands

  local report_target="$REPORT_PATH"
  if [[ -z "$report_target" ]]; then
    report_target="${REPO_ROOT}/build/verification/verify-local-report.txt"
  fi

  write_report "$report_target"
  print_report_stdout
  info "report: ${report_target}"

  local exit_status=0
  if [[ "$EXECUTE" -eq 1 ]]; then
    if [[ ${#RESOLVED_COMMANDS[@]} -gt 0 ]]; then
      if ! run_commands; then
        exit_status=1
      fi
    fi
    if [[ ${#MANUAL_ITEMS[@]} -gt 0 ]]; then
      info "MANUAL_GATE_REQUIRED: deterministic checks finished; complete manual gates before merge"
      exit_status=1
    fi
  fi

  if [[ "$STRICT" -eq 1 ]] && strict_failure; then
    info "strict mode failed: unmapped or manual-required paths present"
    exit_status=1
  fi

  exit "$exit_status"
}

main "$@"
