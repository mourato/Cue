# Plan 025: Document Video module workflow and dual-mode verification

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat f29a2c6..HEAD -- AGENTS.md README.md docs .agents scripts/build_and_run.sh scripts/run-tests.sh plans/README.md`
> Prefer landing after 020–024 so docs match shipped behavior; can draft stubs earlier but finalize last.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/020-video-module-gate-and-build.md (hard); 021–024 soft for accurate final wording
- **Category**: docs | dx
- **Planned at**: commit `f29a2c6`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — docs-only once behavior exists
- **Reviewer required**: `no`
- **Rationale**: Documentation and skill touch-ups only.
- **Escalate when**: Product intent in AGENTS.md would need contradicting recording encouragement — stop and ask.

## Why this matters

Without docs, the next agent re-enables recording in the default build or forgets the interactive script prompt. Dual-mode verification (module off vs on) must live next to existing delivery commands.

## Current state

- `AGENTS.md` — product intent already discourages broad recording; no mention of `NOTINHAS_VIDEO_MODULE`.
- `.agents/skills/delivery-workflow/SKILL.md` — documents `build_and_run.sh` / `run-tests.sh` without video flag.
- `.agents/skills/capture-annotate-export/SKILL.md` — out-of-scope pressure test against recording suites; should cross-link the optional module.
- `docs/BUILD.md` / `docs/CONFIGURATION.md` — upstream-oriented; update lightly if they describe recording as always-on.
- `scripts/build_and_run.sh` — after 020, has interactive video prompt (document it).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Link check (manual) | `rg -n "NOTINHAS_VIDEO_MODULE|ENABLE_VIDEO_MODULE|Snapzy Video|VideoModuleAvailability" AGENTS.md .agents docs scripts` | hits in the files you updated |
| Format | n/a for markdown unless repo formats md | — |

## Suggested executor toolkit

- `.agents/skills/documentation/SKILL.md`
- `.agents/skills/project-standards/SKILL.md`
- `.agents/skills/delivery-workflow/SKILL.md`

## Scope

**In scope**:
- `AGENTS.md` — short “Optional Video module” subsection under Build/Product
- `.agents/skills/delivery-workflow/SKILL.md` — commands for module off/on, interactive script, test host policy from 024
- `.agents/skills/capture-annotate-export/SKILL.md` — pointer: recording is optional module; do not reintroduce without flag
- `scripts/build_and_run.sh` usage text already updated in 020 — only fix if docs drift
- Optional: `docs/BUILD.md` one paragraph
- `plans/README.md` status + this round’s dependency notes

**Out of scope**:
- Rewriting upstream `docs/` wholesale
- Code changes (unless a doc sample command is wrong — then fix script help only)
- Publishing GitHub issues

## Git workflow

- Branch: `docs/video-module` or same feature branch
- Commit: `docs: document optional video module build and runtime gates`

## Steps

### Step 1: AGENTS.md

Add a concise subsection:

- Flag name `NOTINHAS_VIDEO_MODULE`
- Default off; scheme `Snapzy Video` / script prompt
- Runtime key `videoModule.enabled` default false; Advanced toggle; cannot disable while recording
- Perimeter one-liner + link to plans 020–024 for implementers

**Verify**: `rg -n "NOTINHAS_VIDEO_MODULE" AGENTS.md`

### Step 2: delivery-workflow skill

Document:

| Goal | Command |
|------|---------|
| Daily Notinhas (no video) | `./scripts/build_and_run.sh` → answer N to video |
| Work on recording | answer Y, or `--video-module`, or scheme `Snapzy Video` |
| Tests | whatever 024 decided (`run-tests.sh` video-on host + module-off compile check) |

**Verify**: skill table includes video module rows.

### Step 3: capture-annotate-export skill

In Out-of-Scope / Related: “Recording/Video Editor live behind `VideoModuleAvailability`; do not expand them for Notinhas handoff work.”

### Step 4: plans/README.md round section

Add “Video module optionalization” round summarizing 020–025, locked decisions, and execution order (see index update in the same PR).

## Test plan

- No code tests. Peer read: another agent can enable video via script without reading this chat.

## Done criteria

- [ ] `AGENTS.md` documents flag, defaults, Advanced toggle, perimeter
- [ ] `delivery-workflow` skill documents script + schemes + test policy
- [ ] `capture-annotate-export` references the gate
- [ ] `plans/README.md` lists 020–025 with dependency notes and locked decisions
- [ ] No source behavior changes

## STOP conditions

- 020 not landed and docs would describe nonexistent flags — wait or mark docs as “pending 020”
- Conflict with product intent language — stop

## Maintenance notes

- When upstream Snapzy merge reintroduces always-on recording UI, re-check this doc section.
- Reviewers: keep AGENTS short; details stay in plans/skills.
