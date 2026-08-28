#!/bin/bash
# Fixture tests for scripts/integrate-plan.sh (isolated temporary Git repos).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INTEGRATE_PLAN="${ROOT_DIR}/scripts/integrate-plan.sh"

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

assert_output_missing() {
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
    fail "$name" "output unexpectedly contained ${needle} (exit ${status})"
  else
    pass
    printf 'ok  %s (missing %s)\n' "$name" "$needle"
  fi
}

install_integrate_plan() {
  local repo="$1"
  mkdir -p "${repo}/scripts"
  cp "$INTEGRATE_PLAN" "${repo}/scripts/integrate-plan.sh"
  chmod +x "${repo}/scripts/integrate-plan.sh"
}

write_preflight_report() {
  local path="$1"
  local source_sha="$2"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<EOF
{
  "plan": "plans/049-local-git-integration-protocol.md",
  "plannedAt": "${source_sha}",
  "currentHead": "${source_sha}",
  "result": "pass",
  "checks": []
}
EOF
}

write_verify_report() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'EOF'
verify-local: plan-only
base: main
strict: no
full: no

changed_paths:
  - scripts/integrate-plan.sh
EOF
}

write_integration_manifest() {
  local path="$1"
  local source_branch="$2"
  local source_sha="$3"
  local preflight_path="$4"
  local verify_path="$5"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<EOF
{
  "kind": "notinhas-integration-evidence",
  "sourceBranch": "${source_branch}",
  "sourceCommit": "${source_sha}",
  "reviewedCommit": "${source_sha}",
  "preflight": {
    "path": "${preflight_path}",
    "result": "pass"
  },
  "verification": {
    "path": "${verify_path}",
    "mode": "plan-only"
  }
}
EOF
}

run_integrate() {
  local repo="$1"
  shift
  (
    cd "$repo"
    ./scripts/integrate-plan.sh "$@"
  )
}

setup_repo() {
  local tmp bare
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/integrate-plan-fixture.XXXXXX")"
  bare="$(mktemp -d "${TMPDIR:-/tmp}/integrate-plan-remote.XXXXXX")"
  (
    cd "$bare"
    git init --bare -q
  )
  (
    cd "$tmp"
    git init -q
    git config user.email "fixture@example.com"
    git config user.name "Fixture"
    printf 'validate:\n\t@touch validation-ran\n' >Makefile
    echo "base" >README.md
    git add .
    git commit -q -m "base"
    git branch -M main
    git remote add origin "$bare"
    git push -u origin main >/dev/null
    git checkout -q -b advisor/feature
    echo "feature" >>README.md
    git add README.md
    git commit -q -m "feature work"
    git checkout -q main >/dev/null
  )
  install_integrate_plan "$tmp"
  git -C "$tmp" add scripts/integrate-plan.sh
  git -C "$tmp" commit -q -m "add integrate-plan"
  printf '%s|%s' "$tmp" "$bare"
}

source_sha() {
  local repo="$1"
  git -C "$repo" rev-parse advisor/feature
}

write_evidence_bundle() {
  local repo="$1"
  local source_branch="$2"
  local sha="$3"
  local evidence_root
  evidence_root="$(mktemp -d "${TMPDIR:-/tmp}/integrate-plan-evidence.XXXXXX")"
  local preflight="${evidence_root}/preflight.json"
  local verify="${evidence_root}/verify.txt"
  local manifest="${evidence_root}/manifest.json"
  write_preflight_report "$preflight" "$sha"
  write_verify_report "$verify"
  write_integration_manifest "$manifest" "$source_branch" "$sha" "$preflight" "$verify"
  printf '%s' "$manifest"
}

main() {
  [[ -x "$INTEGRATE_PLAN" ]] || chmod +x "$INTEGRATE_PLAN"
  bash -n "$INTEGRATE_PLAN"
  bash -n "$0"

  assert_exit "help exits zero" 0 "$INTEGRATE_PLAN" --help
  assert_output_contains "help documents dry-run default" "--dry-run" "$INTEGRATE_PLAN" --help
  assert_output_contains "help documents apply" "--apply" "$INTEGRATE_PLAN" --help
  assert_output_contains "help documents no force push" "No force-push" "$INTEGRATE_PLAN" --help

  local repo_pair repo bare
  repo_pair="$(setup_repo)"
  repo="${repo_pair%%|*}"
  bare="${repo_pair##*|}"

  local sha manifest
  sha="$(source_sha "$repo")"

  assert_exit "dry-run succeeds" 0 \
    run_integrate "$repo" --dry-run --source-branch advisor/feature --target-branch main --remote origin
  assert_output_contains "dry-run labels plan" "PLAN:" \
    run_integrate "$repo" --dry-run --source-branch advisor/feature --target-branch main --remote origin
  assert_output_contains "dry-run result" "dry-run complete" \
    run_integrate "$repo" --dry-run --source-branch advisor/feature --target-branch main --remote origin
  assert_output_missing "dry-run avoids force push" "--force" \
    run_integrate "$repo" --dry-run --source-branch advisor/feature --target-branch main --remote origin
  assert_output_contains "dry-run plans post-merge validation" "make -C" \
    run_integrate "$repo" --dry-run --source-branch advisor/feature --target-branch main --remote origin

  manifest="$(write_evidence_bundle "$repo" "advisor/feature" "$sha")"

  assert_exit "same source and target fails" 1 \
    run_integrate "$repo" --dry-run --source-branch main --target-branch main --remote origin
  assert_output_contains "same branch stop" "STOP:" \
    run_integrate "$repo" --dry-run --source-branch main --target-branch main --remote origin

  assert_exit "missing source ref fails" 1 \
    run_integrate "$repo" --dry-run --source-branch missing/branch --target-branch main --remote origin

  printf 'dirty\n' >"${repo}/scratch.txt"
  assert_exit "dirty worktree fails" 1 \
    run_integrate "$repo" --dry-run --source-branch advisor/feature --target-branch main --remote origin
  assert_output_contains "dirty worktree label" "worktree_clean" \
    run_integrate "$repo" --dry-run --source-branch advisor/feature --target-branch main --remote origin
  rm -f "${repo}/scratch.txt"

  assert_exit "apply without evidence fails" 1 \
    run_integrate "$repo" --apply --source-branch advisor/feature --target-branch main --remote origin \
      --reviewed-commit "$sha"

  local bad_evidence_root bad_preflight bad_verify bad_manifest
  bad_evidence_root="$(mktemp -d "${TMPDIR:-/tmp}/integrate-plan-bad-evidence.XXXXXX")"
  bad_preflight="${bad_evidence_root}/preflight.json"
  bad_verify="${bad_evidence_root}/verify.txt"
  bad_manifest="${bad_evidence_root}/manifest.json"
  write_preflight_report "$bad_preflight" "$(git -C "$repo" rev-parse main)"
  write_verify_report "$bad_verify"
  write_integration_manifest "$bad_manifest" "advisor/feature" "$sha" "$bad_preflight" "$bad_verify"
  assert_exit "apply rejects mismatched preflight head" 1 \
    run_integrate "$repo" --apply --source-branch advisor/feature --target-branch main --remote origin \
      --evidence "$bad_manifest" --reviewed-commit "$sha"

  assert_exit "apply with evidence succeeds" 0 \
    run_integrate "$repo" --apply --fetch --cleanup \
      --source-branch advisor/feature --target-branch main --remote origin \
      --evidence "$manifest" --reviewed-commit "$sha"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ -f "${repo}/validation-ran" ]]; then
    pass
    printf 'ok  post-merge validation ran\n'
  else
    fail "post-merge validation ran" "validation marker missing"
  fi
  rm -f "${repo}/validation-ran"

  TESTS_RUN=$((TESTS_RUN + 1))
  if git -C "$repo" show-ref --verify --quiet refs/heads/advisor/feature; then
    fail "cleanup removed source branch" "advisor/feature still present"
  else
    pass
    printf 'ok  cleanup removed source branch\n'
  fi
  TESTS_RUN=$((TESTS_RUN + 1))
  if git -C "$bare" show-ref --verify --quiet refs/heads/main; then
    pass
    printf 'ok  push updated bare remote main\n'
  else
    fail "push updated bare remote" "origin/main missing"
  fi

  local conflict_repo_pair conflict_repo conflict_bare conflict_sha conflict_manifest
  conflict_repo_pair="$(setup_repo)"
  conflict_repo="${conflict_repo_pair%%|*}"
  conflict_bare="${conflict_repo_pair##*|}"
  conflict_sha="$(source_sha "$conflict_repo")"
  conflict_manifest="$(write_evidence_bundle "$conflict_repo" "advisor/feature" "$conflict_sha")"
  echo "conflict on main" >>"${conflict_repo}/README.md"
  git -C "$conflict_repo" add README.md
  git -C "$conflict_repo" commit -q -m "conflict on main"
  assert_exit "merge conflict stops apply" 1 \
    run_integrate "$conflict_repo" --apply --source-branch advisor/feature --target-branch main \
      --remote origin --evidence "$conflict_manifest" --reviewed-commit "$conflict_sha"
  assert_output_contains "merge conflict stop" "STOP:" \
    run_integrate "$conflict_repo" --apply --source-branch advisor/feature --target-branch main \
      --remote origin --evidence "$conflict_manifest" --reviewed-commit "$conflict_sha"
  rm -rf "$conflict_repo" "$conflict_bare"

  local push_repo_pair push_repo push_bare push_sha push_manifest
  push_repo_pair="$(setup_repo)"
  push_repo="${push_repo_pair%%|*}"
  push_bare="${push_repo_pair##*|}"
  push_sha="$(source_sha "$push_repo")"
  push_manifest="$(write_evidence_bundle "$push_repo" "advisor/feature" "$push_sha")"
  rm -rf "$push_bare"
  assert_exit "failed push stops apply" 1 \
    run_integrate "$push_repo" --apply --source-branch advisor/feature --target-branch main \
      --remote origin --evidence "$push_manifest" --reviewed-commit "$push_sha"
  assert_output_contains "failed push stop" "STOP:" \
    run_integrate "$push_repo" --apply --source-branch advisor/feature --target-branch main \
      --remote origin --evidence "$push_manifest" --reviewed-commit "$push_sha"
  rm -rf "$push_repo"

  local cleanup_repo_pair cleanup_repo cleanup_bare cleanup_sha cleanup_manifest
  cleanup_repo_pair="$(setup_repo)"
  cleanup_repo="${cleanup_repo_pair%%|*}"
  cleanup_bare="${cleanup_repo_pair##*|}"
  cleanup_sha="$(source_sha "$cleanup_repo")"
  cleanup_manifest="$(write_evidence_bundle "$cleanup_repo" "advisor/wrong" "$cleanup_sha")"
  assert_exit "cleanup with mismatched evidence branch fails" 1 \
    run_integrate "$cleanup_repo" --apply --cleanup --source-branch advisor/feature --target-branch main \
      --remote origin --evidence "$cleanup_manifest" --reviewed-commit "$cleanup_sha"
  rm -rf "$cleanup_repo" "$cleanup_bare"

  rm -rf "$repo" "$bare"

  printf '\nintegrate-plan fixtures: %s/%s passed\n' "$TESTS_PASSED" "$TESTS_RUN"
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    printf 'failures:\n' >&2
    printf '  - %s\n' "${FAILURES[@]}" >&2
    exit 1
  fi
}

main "$@"
