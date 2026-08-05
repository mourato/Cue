# Plan 082: Establish the Swift 6.2 agent baseline for Notinhas

> **Executor instructions**: Read this plan completely before editing. Use an
> isolated branch/worktree and keep the migration serial because it changes all
> Xcode configurations, formatting, concurrency defaults, and delivery gates.
> Update the plan ledger only after the complete app/test/Video/guidance gate
> and review pass.
>
> **Drift check (run first)**: `git diff --stat 39e0bb13..HEAD -- Notinhas
> NotinhasTests Notinhas.xcodeproj scripts Makefile .github AGENTS.md .agents
> docs/adr plans`

## Status

- Priority: P0
- Effort: L
- Risk: HIGH
- Depends on: Completed plans 001–081; preserve the current `verify-local`
  contract
- Category: migration / tooling / concurrency
- **Planned at**: commit `39e0bb13`, 2026-08-05

## Execution profile

- Recommended profile: `implementer`
- Risk/lane: High / Full
- Parallelizable: No. Swift settings, formatter churn, source migration, and
  CI/pre-commit gates must be reconciled as one baseline.
- Reviewer required: Yes — Swift 6.2/concurrency, Xcode configurations, and
  delivery-gate review.
- Rationale: Notinhas is the largest language-version gap and currently has no
  lint gate; its default MainActor setting and optional Video configurations
  make a careless global change risky.
- Escalate when: a source rewrite changes capture/export behavior, persistence,
  module boundaries, or requires broad unsafe concurrency escapes.

## Why it matters

Notinhas currently mixes Swift 5.0 Xcode settings, SwiftFormat 5.9, a default
MainActor isolation setting, and no SwiftLint configuration. Its existing
`verify-local.sh` is a strong plan-only/strict changed-surface planner, and its
build/test scripts are the right foundation. The new baseline should add only
the missing format/lint contract and connect it to those scripts, CI, and
pre-commit checks.

This is **not a config-only change**. Moving to Swift 6.2, changing the default
actor isolation to the shared policy, and normalizing two-space source to the
group's four-space format will rewrite source and tests. Those rewrites are
explicitly expected and limited to compiler/concurrency/lint/format corrections;
capture, OCR, export, video, and persistence behavior must remain unchanged.

## Current state

- `Notinhas.xcodeproj/project.pbxproj` has eight `SWIFT_VERSION = 5.0` entries
  across app/test, Debug/Release, and Video configurations.
- The same project enables `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
  approachable concurrency, and upcoming feature settings. The new baseline
  must make the chosen isolation policy deliberate rather than inherited.
- `.swiftformat` declares `--swiftversion 5.9`, two-space indentation, max width
  120, and excludes Pods/build/Derived/Generated paths.
- There is no `.swiftlint.yml` or Make lint target. The existing
  `.github/workflows/swiftformat.yml` explicitly prints that validation is
  disabled, and `scripts/pre-commit` has its format check commented out.
- `scripts/verify-local.sh` already supports plan-only/default and `--strict`
  verification through `scripts/verification-map.tsv`; it should remain the
  changed-surface/manual-required authority.
- `AGENTS.md` still describes Swift 5.9 and names build/run/test scripts as the
  canonical commands. It must be updated without discarding the manual capture
  and permission notes.
- Read-only SwiftFormat currently reports `4/606` files requiring formatting
  with the old config; changing indentation/version will create a larger,
  reviewable mechanical rewrite.
- Existing ADRs include 066 and 070; use `docs/adr/071-swift-6-2-agent-baseline.md`.

## Commands and evidence

| Check | Command | Expected result |
|---|---|---|
| Toolchain | `swift --version && xcodebuild -version && swiftformat --version && swiftlint version` | Swift 6.2-compatible toolchain; versions recorded in ADR 071 |
| Xcode settings | `rg -n 'SWIFT_VERSION|SWIFT_DEFAULT_ACTOR_ISOLATION|SWIFT_STRICT_CONCURRENCY|SWIFT_APPROACHABLE_CONCURRENCY' Notinhas.xcodeproj/project.pbxproj` | All owned configurations are 6.2 with explicit concurrency policy |
| Format | `make format-check` | Exit 0; owned source/tests are SwiftFormat 6.2 and four-space clean |
| Full lint | `make lint` | Exit 0, fail closed, no unreviewed warnings |
| Changed lint | `make lint-changed` | Only changed Swift files are checked; no-change case is deterministic |
| Build/test | `./scripts/build_and_run.sh --help` then `make build` and `make test` | Canonical app build and tests pass |
| Video coverage | `make build-video` and `make test-video` (or exact targets established by the plan) | Video configuration/module is compiled and tested |
| Local planner | `./scripts/verify-local.sh --full --plan-only --strict` | Exit 0 with expected manual-required profiles reported |
| CI/guidance | `make guidance-check` and the SwiftFormat workflow | Exit 0; workflow performs real validation |
| Hygiene | `git diff --check` | No whitespace errors |

If a named Video target does not exist, discover the existing scheme/configuration
first and document the exact replacement in the implementation handoff; do not
silently omit it.

## Suggested executor toolkit

- Reuse `swift-conventions` with a Notinhas overlay.
- Reuse `delivery-workflow` with the existing build/test/verification scripts.
- Keep the local Swift concurrency and XCTest specialist skills referenced by
  the project.
- Use the existing `verify-local.sh` and workflow; add only the smallest
  lint/format wrapper needed for a truthful agent command.

## Scope

In scope:

- Set all eight owned Xcode configurations to Swift 6.2, complete strict
  concurrency, and an explicit actor-isolation policy. Target nonisolated by
  default with explicit `@MainActor` at SwiftUI/AppKit/lifecycle boundaries;
  review every Video/test boundary before applying it.
- Set SwiftFormat to Swift 6.2 and four-space indentation, retaining current
  generated/Pods/build exclusions.
- Add a focused `.swiftlint.yml` for `Notinhas` and `NotinhasTests`, with clear
  thresholds, useful opt-ins, and fail-closed verification.
- Add minimal Make/script commands for full and changed format/lint, separate
  autofix, and agent output. Integrate format/lint with `verify-local.sh` and
  enable the existing CI/pre-commit format checks without adding a new CI
  framework.
- Rewrite `Notinhas/**` and `NotinhasTests/**` Swift code where Swift 6.2,
  actor isolation, lint, or format diagnostics require it, including the Video
  configuration when it is owned source.
- Update `AGENTS.md`, `.agents/overlays/`, ADR 071, and this plan README.

Out of scope:

- Capture/OCR/export/video feature changes, persistence migration, UI redesign,
  dependency replacement, or broad architecture refactoring.
- Pods, DerivedData, build/generated artifacts, secrets, unrelated existing
  changes, and global skill source files.

## Git workflow

Use `chore/notinhas-swift-6-2-baseline` in an isolated worktree. Use scoped
Conventional Commits such as `chore(swift): establish Swift 6.2 agent baseline`;
do not push or rewrite history. Do not format excluded/generated files or
unrelated dirty paths.

## Ordered implementation steps

### 1. Freeze baseline and inventory all configurations

Run the drift check, `git status --short`, `git diff --check`, existing build,
test, verify-local, and SwiftFormat commands. Enumerate default and Video
schemes/configurations and capture current failures before changing the format
or actor policy.

**Verify:** all owned targets/configurations are listed; any unexpected failure
or missing Video command is resolved or escalated before proceeding.

### 2. Normalize Xcode language and isolation settings

Set all owned `SWIFT_VERSION` entries to 6.2. Make complete strict concurrency
explicit and replace the implicit MainActor-wide baseline with the shared
nonisolated target, adding explicit `@MainActor` to UI/AppKit/lifecycle entry
points. Preserve approachable-concurrency behavior only when it does not hide
the Swift 6.2 contract; document any retained setting.

**Verify:** `rg` finds no owned Swift 5.0/5.9 setting, every Video/test config
matches, and the project builds far enough to expose source diagnostics.

### 3. Normalize formatter and add lint foundation

Change `.swiftformat` to Swift 6.2/four spaces, run it in the isolated branch,
and review the expected broad mechanical rewrite. Add `.swiftlint.yml` for
owned app/tests, excluding generated/Pods/build paths. Add path-aware full and
changed checks with correct `--help`, and keep autofix separate from
verification; no `|| true` may mask a check failure.

**Verify:** `make format-check` and `make lint` fail on an injected bad fixture,
pass on the cleaned tree, and produce compact output suitable for an agent.

### 4. Rewrite source/tests for Swift 6.2

Build and test in slices. Fix actor isolation, `Sendable`, async boundaries,
test isolation, and lint diagnostics in app, tests, and Video code. Use explicit
boundary annotations rather than broad `@preconcurrency`, `@unchecked Sendable`,
or disabled rules. Preserve capture/export/OCR behavior and data contracts.

**Verify:** default and Video builds/tests pass; every non-mechanical rewrite is
linked to a migration diagnostic or selected lint rule.

### 5. Integrate the delivery scripts and existing CI

Keep `build_and_run.sh`, `run-tests.sh`, and `verify-local.sh` as canonical
project commands. Add the smallest Make/script wrappers needed for
`format-check`, `lint`, `lint-changed`, `lint-fix`, and `agent-check`. Add the
lint/format result to the strict local planner. Re-enable the existing
SwiftFormat workflow and pre-commit format check; do not add tests to
pre-commit by default.

**Verify:** full/changed local checks, `verify-local --full --plan-only
--strict`, CI command, and pre-commit command all return truthful exit codes.

### 6. Record the durable baseline decision

Create ADR 071 with the exact Swift 6.2 settings, four-space policy, lint rule
ownership, source-rewrite allowance, Video coverage, agent command tiers, and
upgrade/exception process. Update `AGENTS.md` and overlays from Swift 5.9 to
the new contract while preserving manual verification guidance.

**Verify:** a fresh agent can discover the baseline, run a targeted check, and
run the full handoff gate without relying on disabled or undocumented scripts.

### 7. Run final validation and update the ledger

Run every command in the table, inspect the source/config/CI diff, obtain the
required reviewer sign-off, and update plan 082's README row.

**Verify:** only approved migration/config/docs/plan files are changed and all
required checks pass.

## Test plan

- Build and test the default app/test configuration.
- Build and test the Video configuration/module, using the exact discovered
  scheme if the repository does not expose a dedicated Make target today.
- Run full and changed format/lint checks, including a no-change case.
- Run `verify-local.sh` in strict plan-only/full mode, `make guidance-check`,
  and the active CI command locally.
- Manually smoke-test capture/annotation/export only if actor isolation changes
  those boundaries; record any unavailable permission/hardware check.

## Done criteria

- Every owned Notinhas configuration uses Swift 6.2 with complete, explicit
  concurrency policy; Video/test targets are not omitted.
- SwiftFormat and SwiftLint are present, clean, fail closed, and agent-friendly.
- Required source rewrites are reviewed, behavior-preserving, and documented.
- Build/test/Video/verify-local/CI/pre-commit/guidance checks pass.
- ADR 071, `AGENTS.md`, overlays, scripts/Makefile, and plan 082 agree.

## STOP conditions

- The live tree differs from the drift check or owned target/configuration scope
  cannot be established.
- Swift 6.2 migration requires changing capture/export/video/persistence/API
  behavior.
- The only viable fix is broad unsafe concurrency, hidden warnings, or disabled
  verification.
- Generated/Pods/build artifacts must be edited directly.
- A baseline build/test failure is unrelated and cannot be reproduced cleanly.

## Maintenance notes

Future Swift/Xcode upgrades must update all Xcode configurations, formatter/lint
configs, Make/scripts, CI/pre-commit, overlays, and ADR 071 together. Keep
`verify-local` as the manual-required/planner authority and the full lint/build/
test gate as the merge contract. Any exception needs an owner and removal
condition.
