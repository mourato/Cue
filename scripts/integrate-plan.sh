#!/bin/bash
# Explicit local Git integration protocol for Notinhas handoff plans.
# After review and remediation, follows the global merge -> validate -> push
# -> cleanup lifecycle.
#
# Usage:
#   ./scripts/integrate-plan.sh --dry-run \
#     --source-branch advisor/example --target-branch main --remote origin
#
# Default mode is --dry-run (non-mutating). Use --apply only after the
# orchestrator authorizes the exact refs and evidence paths.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DRY_RUN=1
APPLY=0
FETCH=0
CLEANUP=0
SOURCE_BRANCH=""
TARGET_BRANCH=""
REMOTE=""
EVIDENCE_PATH=""
REVIEWED_COMMIT=""
SOURCE_WORKTREE=""
TARGET_WORKTREE=""

declare -a PLANNED_COMMANDS=()
declare -a CHECK_RECORDS=()

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Run the mandatory local Git integration protocol for a plan branch. The
default mode is --dry-run: print CHECK/PLAN steps without changing Git state,
remotes, branches, or worktrees.

Required arguments:
  --source-branch NAME      Branch containing the integrated plan work.
  --target-branch NAME      Integration branch (for example main).
  --remote NAME             Explicit remote name (for example origin). No
                            implicit remote selection is performed.

Modes:
  --dry-run                 Preview the protocol (default).
  --apply                   Perform the guarded merge/validate/push sequence.
                            Requires --evidence and --reviewed-commit.

Evidence and review (required with --apply):
  --evidence PATH           Integration evidence manifest or report file.
                            Apply mode accepts a notinhas-integration-evidence
                            JSON manifest, a passing plan-preflight JSON report,
                            or a verify-local text report. Manifests must
                            reference passing preflight and verification
                            evidence for the source commit.
  --reviewed-commit SHA     Reviewed source commit SHA. Must match the source
                            branch tip exactly. The script verifies identity
                            only; it does not judge review quality.

Optional apply flags:
  --fetch                   Fetch the named remote before merging.
  --cleanup                 After a successful push, delete the recorded source
                            branch when its identity matches --source-branch.
  --source-worktree PATH    Expected source worktree path for cleanup checks.
  --target-worktree PATH    Expected target worktree path. When set, the
                            current worktree must match before apply.

Safety policy:
  - No force-push, rebase, or automatic conflict resolution.
  - Runs make validate after merge and before push.
  - Stops on dirty worktree, missing refs, merge conflicts, failed pushes,
    evidence gaps, or mismatched reviewed commits.
  - Never marks plans DONE in plans/README.md.

Examples:
  ${SCRIPT_NAME} --help
  ${SCRIPT_NAME} --dry-run --source-branch advisor/049 --target-branch main \\
    --remote origin
  ${SCRIPT_NAME} --apply --fetch --cleanup \\
    --source-branch advisor/049 --target-branch main --remote origin \\
    --evidence build/integration/049-evidence.json \\
    --reviewed-commit <source-sha>
EOF
}

die() {
  printf 'integrate-plan: error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf 'integrate-plan: %s\n' "$*"
}

stop() {
  info "STOP: $*"
  exit 1
}

record_check() {
  local label="$1"
  local ok="$2"
  local detail="${3:-}"
  CHECK_RECORDS+=("${label}|${ok}|${detail}")
}

emit_checks() {
  local record label ok detail
  info "CHECK:"
  for record in "${CHECK_RECORDS[@]}"; do
    IFS='|' read -r label ok detail <<<"$record"
    if [[ "$ok" -eq 1 ]]; then
      printf 'integrate-plan:   [ok] %s' "$label"
    else
      printf 'integrate-plan:   [fail] %s' "$label"
    fi
    if [[ -n "$detail" ]]; then
      printf ' — %s' "$detail"
    fi
    printf '\n'
  done
}

plan_command() {
  local command="$1"
  PLANNED_COMMANDS+=("$command")
  info "PLAN: ${command}"
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 0
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      --dry-run)
        DRY_RUN=1
        APPLY=0
        shift
        ;;
      --apply)
        APPLY=1
        DRY_RUN=0
        shift
        ;;
      --fetch)
        FETCH=1
        shift
        ;;
      --cleanup)
        CLEANUP=1
        shift
        ;;
      --source-branch)
        shift
        [[ $# -gt 0 ]] || die "--source-branch requires a name"
        SOURCE_BRANCH="$1"
        shift
        ;;
      --target-branch)
        shift
        [[ $# -gt 0 ]] || die "--target-branch requires a name"
        TARGET_BRANCH="$1"
        shift
        ;;
      --remote)
        shift
        [[ $# -gt 0 ]] || die "--remote requires a name"
        REMOTE="$1"
        shift
        ;;
      --evidence)
        shift
        [[ $# -gt 0 ]] || die "--evidence requires a path"
        EVIDENCE_PATH="$1"
        shift
        ;;
      --reviewed-commit)
        shift
        [[ $# -gt 0 ]] || die "--reviewed-commit requires a SHA"
        REVIEWED_COMMIT="$1"
        shift
        ;;
      --source-worktree)
        shift
        [[ $# -gt 0 ]] || die "--source-worktree requires a path"
        SOURCE_WORKTREE="$1"
        shift
        ;;
      --target-worktree)
        shift
        [[ $# -gt 0 ]] || die "--target-worktree requires a path"
        TARGET_WORKTREE="$1"
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

require_args() {
  [[ -n "$SOURCE_BRANCH" ]] || die "--source-branch is required"
  [[ -n "$TARGET_BRANCH" ]] || die "--target-branch is required"
  [[ -n "$REMOTE" ]] || die "--remote is required"
  if [[ "$SOURCE_BRANCH" == "$TARGET_BRANCH" ]]; then
    stop "source and target branches must differ"
  fi
  if [[ "$APPLY" -eq 1 ]]; then
    [[ -n "$EVIDENCE_PATH" ]] || die "--evidence is required with --apply"
    [[ -n "$REVIEWED_COMMIT" ]] || die "--reviewed-commit is required with --apply"
  fi
}

current_worktree_path() {
  git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || true
}

check_worktree_clean() {
  local status_output
  status_output="$(git -C "$REPO_ROOT" status --short 2>/dev/null || true)"
  if [[ -n "$(printf '%s' "$status_output" | sed '/^[[:space:]]*$/d')" ]]; then
    record_check "worktree_clean" 0 "uncommitted changes present"
    return 1
  fi
  record_check "worktree_clean" 1 "worktree clean"
  return 0
}

check_merge_in_progress() {
  local git_dir merge_head
  git_dir="$(git -C "$REPO_ROOT" rev-parse --git-dir)"
  merge_head="${git_dir}/MERGE_HEAD"
  if [[ -f "$merge_head" ]]; then
    record_check "merge_in_progress" 0 "merge already in progress"
    return 1
  fi
  record_check "merge_in_progress" 1 "no merge in progress"
  return 0
}

check_target_worktree() {
  if [[ -z "$TARGET_WORKTREE" ]]; then
    record_check "target_worktree" 1 "target worktree not constrained"
    return 0
  fi
  local current
  current="$(current_worktree_path)"
  if [[ "$current" != "$TARGET_WORKTREE" ]]; then
    record_check "target_worktree" 0 "current worktree ${current:-unknown} != ${TARGET_WORKTREE}"
    return 1
  fi
  record_check "target_worktree" 1 "current worktree matches target"
  return 0
}

resolve_ref() {
  local ref="$1"
  git -C "$REPO_ROOT" rev-parse --verify "$ref" 2>/dev/null
}

check_refs() {
  local source_sha target_sha
  source_sha="$(resolve_ref "$SOURCE_BRANCH" || true)"
  target_sha="$(resolve_ref "$TARGET_BRANCH" || true)"
  if [[ -z "$source_sha" ]]; then
    record_check "source_ref" 0 "cannot resolve ${SOURCE_BRANCH}"
    return 1
  fi
  record_check "source_ref" 1 "${SOURCE_BRANCH} -> ${source_sha}"
  if [[ -z "$target_sha" ]]; then
    record_check "target_ref" 0 "cannot resolve ${TARGET_BRANCH}"
    return 1
  fi
  record_check "target_ref" 1 "${TARGET_BRANCH} -> ${target_sha}"
  printf '%s\n' "$source_sha"
}

check_remote_exists() {
  if ! git -C "$REPO_ROOT" remote get-url "$REMOTE" >/dev/null 2>&1; then
    record_check "remote_present" 0 "remote ${REMOTE} is not configured"
    return 1
  fi
  record_check "remote_present" 1 "remote ${REMOTE} configured"
  return 0
}

check_no_force_push() {
  local command
  for command in "${PLANNED_COMMANDS[@]}"; do
    if [[ "$command" == *"--force"* || "$command" == *"-f "* ]]; then
      record_check "no_force_push" 0 "force push is forbidden"
      return 1
    fi
  done
  record_check "no_force_push" 1 "no force-push commands planned"
  return 0
}

validate_evidence() {
  local source_sha="$1"
  local evidence_abs
  if [[ "$EVIDENCE_PATH" != /* ]]; then
    evidence_abs="${REPO_ROOT}/${EVIDENCE_PATH}"
  else
    evidence_abs="$EVIDENCE_PATH"
  fi
  [[ -f "$evidence_abs" ]] || {
    record_check "evidence_present" 0 "missing evidence file"
    return 1
  }

  if ! python3 - "$evidence_abs" "$SOURCE_BRANCH" "$source_sha" "$REVIEWED_COMMIT" "$REPO_ROOT" <<'PY'
import json
import pathlib
import sys

evidence_path, source_branch, source_sha, reviewed_commit, repo_root = sys.argv[1:6]

def fail(message: str) -> None:
    print(message, file=sys.stderr)
    sys.exit(1)

def read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")

def validate_preflight(path: pathlib.Path) -> None:
    payload = json.loads(read_text(path))
    if payload.get("result") != "pass":
        fail(f"preflight evidence failed: {path}")
    if payload.get("currentHead") != source_sha:
        fail(f"preflight currentHead mismatch: {path}")

def validate_verify_local(path: pathlib.Path) -> None:
    text = read_text(path)
    first = text.splitlines()[0] if text else ""
    if not first.startswith("verify-local:"):
        fail(f"verification evidence missing verify-local header: {path}")

def resolve(path_value: str) -> pathlib.Path:
    candidate = pathlib.Path(path_value)
    if not candidate.is_absolute():
        candidate = pathlib.Path(repo_root) / candidate
    return candidate

text = read_text(pathlib.Path(evidence_path))
if text.lstrip().startswith("{"):
    payload = json.loads(text)
    kind = payload.get("kind")
    if kind == "notinhas-integration-evidence":
        if payload.get("sourceBranch") != source_branch:
            fail("evidence sourceBranch mismatch")
        if payload.get("sourceCommit") != source_sha:
            fail("evidence sourceCommit mismatch")
        if payload.get("reviewedCommit") != reviewed_commit:
            fail("evidence reviewedCommit mismatch")
        if payload.get("reviewedCommit") != source_sha:
            fail("reviewed commit must match source tip")
        preflight = payload.get("preflight") or {}
        verification = payload.get("verification") or {}
        preflight_path = resolve(preflight.get("path", ""))
        verification_path = resolve(verification.get("path", ""))
        if not preflight_path.is_file():
            fail("preflight evidence path missing")
        if not verification_path.is_file():
            fail("verification evidence path missing")
        validate_preflight(preflight_path)
        validate_verify_local(verification_path)
        if preflight.get("result") not in (None, "pass"):
            fail("preflight evidence result must be pass")
        sys.exit(0)
    if payload.get("result") == "pass":
        if payload.get("currentHead") != source_sha:
            fail("preflight currentHead mismatch")
        if reviewed_commit != source_sha:
            fail("reviewed commit must match source tip")
        sys.exit(0)
    fail("unsupported JSON evidence payload")

first_line = text.splitlines()[0] if text else ""
if first_line.startswith("plan-preflight:") and "pass" in first_line:
    current_head = next(
        (line.split(":", 1)[1].strip() for line in text.splitlines() if line.startswith("currentHead:")),
        "",
    )
    if current_head != source_sha:
        fail("preflight currentHead mismatch")
    if reviewed_commit != source_sha:
        fail("reviewed commit must match source tip")
    sys.exit(0)
if first_line.startswith("verify-local:"):
    fail("apply requires integration manifest or passing preflight JSON, not verify-local alone")

fail("unsupported evidence format")
PY
  then
    record_check "evidence_valid" 0 "evidence validation failed"
    return 1
  fi

  record_check "evidence_valid" 1 "evidence accepted for ${source_sha}"
  return 0
}

check_reviewed_commit() {
  local source_sha="$1"
  if [[ "$REVIEWED_COMMIT" != "$source_sha" ]]; then
    record_check "reviewed_commit" 0 "reviewed ${REVIEWED_COMMIT} != source ${source_sha}"
    return 1
  fi
  record_check "reviewed_commit" 1 "reviewed commit matches source tip"
  return 0
}

build_plan() {
  local source_sha="$1"
  if [[ "$FETCH" -eq 1 ]]; then
    plan_command "git -C ${REPO_ROOT} fetch ${REMOTE}"
  fi
  plan_command "git -C ${REPO_ROOT} checkout ${TARGET_BRANCH}"
  plan_command "git -C ${REPO_ROOT} merge --no-ff ${SOURCE_BRANCH}"
  plan_command "make -C ${REPO_ROOT} validate"
  plan_command "git -C ${REPO_ROOT} push ${REMOTE} ${TARGET_BRANCH}"
  if [[ "$CLEANUP" -eq 1 ]]; then
    if [[ -n "$SOURCE_WORKTREE" ]]; then
      plan_command "git -C ${REPO_ROOT} worktree remove ${SOURCE_WORKTREE}"
    fi
    plan_command "git -C ${REPO_ROOT} branch -d ${SOURCE_BRANCH}"
  fi
  check_no_force_push >/dev/null
}

run_apply() {
  local source_sha="$1"
  info "APPLY: starting guarded integration"
  if [[ "$FETCH" -eq 1 ]]; then
    git -C "$REPO_ROOT" fetch "$REMOTE"
  fi
  local current_source_sha
  current_source_sha="$(resolve_ref "$SOURCE_BRANCH" || true)"
  if [[ "$current_source_sha" != "$source_sha" ]]; then
    stop "source branch changed after evidence validation"
  fi
  git -C "$REPO_ROOT" checkout "$TARGET_BRANCH"
  if ! git -C "$REPO_ROOT" merge --no-ff "$SOURCE_BRANCH"; then
    stop "merge failed or conflicts detected"
  fi
  if ! make -C "$REPO_ROOT" validate; then
    stop "post-merge validation failed; target remains merged and unpushed"
  fi
  if ! git -C "$REPO_ROOT" push "$REMOTE" "$TARGET_BRANCH"; then
    stop "push failed"
  fi
  if [[ "$CLEANUP" -eq 1 ]]; then
    local current_branch
    current_branch="$(git -C "$REPO_ROOT" branch --show-current)"
    if [[ "$current_branch" == "$SOURCE_BRANCH" ]]; then
      stop "refusing cleanup while checked out on source branch"
    fi
    if [[ -n "$SOURCE_WORKTREE" ]]; then
      if [[ ! -d "$SOURCE_WORKTREE" ]]; then
        stop "source worktree missing for cleanup: ${SOURCE_WORKTREE}"
      fi
      local worktree_branch
      worktree_branch="$(git -C "$SOURCE_WORKTREE" branch --show-current 2>/dev/null || true)"
      if [[ -n "$worktree_branch" && "$worktree_branch" != "$SOURCE_BRANCH" ]]; then
        stop "source worktree branch mismatch for cleanup"
      fi
      git -C "$REPO_ROOT" worktree remove "$SOURCE_WORKTREE"
    fi
    git -C "$REPO_ROOT" branch -d "$SOURCE_BRANCH"
  fi
  info "RESULT: integrated ${SOURCE_BRANCH} (${source_sha}) into ${TARGET_BRANCH} on ${REMOTE}"
}

main() {
  parse_args "$@"
  require_args

  local failed=0
  check_worktree_clean || failed=1
  check_merge_in_progress || failed=1
  check_target_worktree || failed=1
  check_remote_exists || failed=1

  local source_sha
  source_sha="$(check_refs)" || failed=1
  if [[ "$failed" -eq 1 ]]; then
    emit_checks
    stop "preflight checks failed"
  fi

  if [[ "$APPLY" -eq 1 ]]; then
    validate_evidence "$source_sha" || failed=1
    check_reviewed_commit "$source_sha" || failed=1
    if [[ "$failed" -eq 1 ]]; then
      emit_checks
      stop "evidence or reviewed-commit checks failed"
    fi
  elif [[ -n "$EVIDENCE_PATH" || -n "$REVIEWED_COMMIT" ]]; then
    info "PLAN: evidence arguments supplied; full validation runs only under --apply"
  fi

  build_plan "$source_sha"
  emit_checks

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "RESULT: dry-run complete; no Git state changed"
    exit 0
  fi

  run_apply "$source_sha"
}

main "$@"
