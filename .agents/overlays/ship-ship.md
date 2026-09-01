---
kind: project-overlay
extends: ship-ship
project: Cue
precedence: project
---

# Cue ship-ship

Concrete commands for the global `ship-ship` loop. Load after the global
skill. Do not weaken its safety or integrity rules.

## Plan units — preflight

```sh
./scripts/plan-preflight.sh plans/NNN-*.md \
  --scope <path> [--new-file <path>] \
  --report build/plan-preflight/<plan>.json --json
```

Read-only. Pass every in-scope path. Also confirms `plans/README.md`
dependencies and drift against `Planned at` for tracked scope paths.
Skip this block for task units (no plan file).

Does not replace merge, push, review, or manual
capture/TCC/WindowServer gates.

## Verify (plan or task units)

```sh
./scripts/verify-local.sh --base <ref> [--plan-only] [--execute] [--strict]
```

Capture reports under `build/verification/`. Prefer `--plan-only` before
`--execute`. Use `--strict` when the surface is unmapped or
manual-required.

## Integrate (ship)

Default to dry-run; apply only with explicit refs, evidence, and a
reviewed source tip:

```sh
./scripts/integrate-plan.sh --dry-run \
  --source-branch <branch> --target-branch <branch> --remote <remote>

./scripts/integrate-plan.sh --apply --fetch \
  --source-branch <branch> --target-branch <branch> --remote <remote> \
  --evidence <path> --reviewed-commit <sha> [--cleanup]
```

`--evidence` accepts a Cue integration manifest, a passing
plan-preflight JSON report (plan units), or verification evidence tied to
the source commit. After review and remediation, the script merges with
`--no-ff`, runs `make validate`, pushes without `--force`, and only then
performs optional recorded worktree/branch cleanup. It never marks plans
`DONE` — review and index updates stay with the orchestrator after ship.

## Plans index

For plan units only: keep `plans/README.md` current — dependencies
`DONE` before dispatch; after remediate, mark the plan `DONE` with merge
and review-fix SHAs.
