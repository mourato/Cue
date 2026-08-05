# Plan 010: Rebase existing agent skills from Picker to Notinhas

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 415d662..HEAD -- .agents/skills AGENTS.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: docs / dx
- **Planned at**: commit `415d662`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `no` — foundation for plans 012 and 011
- **Reviewer required**: `yes` — content accuracy of product-specific guidance
- **Rationale**: Markdown-only edits under `.agents/skills/` with a fixed rewrite brief per file; no Swift source changes.
- **Escalate when**: executor discovers real Notinhas behavior that contradicts `AGENTS.md` product intent, or when a skill appears to need new Swift APIs/docs outside this plan’s scope.

## Why this matters

All 13 local skills were copied from the Picker project. Agents that follow them will run wrong commands (`./build.sh`), chase nonexistent features (Grab Font, loupe, `FontLoader`), and ignore the actual Notinhas/Snapzy layout. Rebasing the skills to this repo is the highest-leverage agent-DX fix: every later skill and plan builds on truthful guidance.

## Current state

- Skills live only under `.agents/skills/<name>/SKILL.md` (13 directories). There is **no** `.agents/SKILLS_INDEX.md`, **no** `CLAUDE.md`, and **no** `.agents/review-profiles/`.
- `AGENTS.md` already describes Notinhas correctly (product intent, Snapzy fork, scripts) but does **not** mention skills routing.
- Every skill file still mentions Picker. Evidence from `delivery-workflow`:

```1:21:.agents/skills/delivery-workflow/SKILL.md
---
name: delivery-workflow
description: Delivery and verification workflow for Picker — ./build.sh, signing, manual menu-bar gates, and Git evidence.
---
...
| `./build.sh` | Release app bundle under `build/Picker.app` + codesign |
| `build/Picker.app/Contents/MacOS/Picker --demo` | Seeded UI, in-memory stores, sticky panel |
```

- Canonical product intent (honor this; skills must not contradict it):

```3:10:AGENTS.md
Notinhas is a tailored macOS visual-handoff tool for a product designer. It
turns a screenshot into an unambiguous brief for developers and AI coding
agents: capture an area, place numbered pins or rectangles, add concise notes,
and copy the annotated result. Prioritize speed, precise visual reference, and
clipboard-ready output. Do not add broad recording, cloud, or generic markup
features unless they directly support that workflow.
```

- Real commands (from `AGENTS.md` / `scripts/`):
  - `open Snapzy.xcodeproj`
  - `./scripts/build_and_run.sh`
  - `./scripts/run-tests.sh`
  - `./scripts/format.sh` (SwiftFormat via `.swiftformat`: `--indent 2`, `--maxwidth 120`)
- App layout: `Snapzy/` (app), `SnapzyTests/`, `docs/` (upstream Snapzy docs — keep; do not delete), `scripts/`.
- Menu bar owner: `Snapzy/App/AppStatusBarController.swift` (`NSStatusItem`, menu-driven capture — **not** Picker’s left-click panel / right-click quit).
- Notinhas module root: `Snapzy/Features/Notinhas/` (Models / Views / Services / Annotate).
- Format/style exemplar: `.swiftformat` + `AGENTS.md` “Code and Tests” section. Match Conventional Commits (`feat(notinhas): …`).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Drift check | `git diff --stat 415d662..HEAD -- .agents/skills AGENTS.md` | empty, or only expected WIP |
| Picker leakage scan | `rg -n -i 'Picker\|FontLoader\|Grab Font\|Sources/Picker\|\\./build\\.sh\|picker\\.picked\|NSColorSampler\|YIQ\|--demo' .agents/skills` | **no matches** after rewrite |
| Skill list | `ls .agents/skills` | same 13 skill dirs (no new skill yet) |
| Format (optional sanity) | `./scripts/format.sh` | exit 0 if SwiftFormat installed; **do not** reformat for this plan unless you touched Swift (you should not) |

## Suggested executor toolkit

- Read `AGENTS.md` fully before rewriting any skill.
- Skim `docs/CAPTURE.md`, `docs/ANNOTATE.md`, `docs/POST_CAPTURE.md`, `docs/QUICK_ACCESS.md` for accurate upstream vocabulary when rewriting capture/annotate-adjacent skills.
- Do **not** invent Makefile targets; this repo uses `scripts/*.sh`.

## Scope

**In scope** (the only files you should modify):
- All 13 files: `.agents/skills/*/SKILL.md`
  - `accessibility-audit`
  - `apple-design`
  - `code-quality`
  - `data-persistence`
  - `debugging-diagnostics`
  - `delivery-workflow`
  - `documentation`
  - `localization`
  - `macos-app-engineering`
  - `menubar`
  - `swift-concurrency-expert`
  - `swift-conventions`
  - `testing-xctest`

**Out of scope** (do NOT touch):
- Creating `capture-annotate-export` or `project-standards` — plans 011 / 012.
- Creating `.agents/SKILLS_INDEX.md` or editing `AGENTS.md` skills routing — plan 012.
- Any Swift under `Snapzy/` or `SnapzyTests/`.
- Upstream `docs/*` bodies (except reading them).
- Deleting skills, renaming skill directories, or adding global overlay profiles.

## Git workflow

- Branch: `advisor/010-rebase-skills-notinhas`
- Commit style: Conventional Commits, e.g. `docs(agents): rebase skills from Picker to Notinhas`
- Do NOT push or open a PR unless the operator instructed it.
- Prefer one commit for the full skill rebase (atomic docs change).

## Steps

### Step 1: Confirm Picker drift baseline

Run:

```bash
rg -n -i 'Picker|FontLoader|Grab Font|Sources/Picker|\./build\.sh|picker\.picked' .agents/skills | wc -l
```

**Verify**: count is **≥ 13** (today all 13 files leak). If already zero, STOP — someone already rebased; reconcile with plan 012 instead of rewriting blindly.

### Step 2: Rewrite each skill to Notinhas (keep directory names)

Keep YAML `name:` identical to the directory name. Rewrite `description:` and body. English only. Prefer this section order when practical: Role (optional short), When to Use, domain guidance, Checklist/Verification, Related Skills.

Use the **target briefs below**. Each brief is mandatory content; wording may vary but facts must match.

#### `delivery-workflow`

- Commands table must use:
  - `open Snapzy.xcodeproj`
  - `./scripts/build_and_run.sh` — build/launch isolated debug app (signing identity default `Prisma Local Code Signing` via `LOCAL_CODE_SIGN_IDENTITY` in script)
  - `./scripts/run-tests.sh` — XCTest → results under `build/`
  - `./scripts/format.sh` — SwiftFormat (`.swiftformat`)
- Remove all `./build.sh`, `Picker.app`, `--demo`, `swift format --configuration .swift-format` (Apple `swift-format` config) references.
- Merge gate: format (when tool installed) + tests relevant to change + manual smoke for capture/annotate/clipboard/permissions when those paths change.
- Signing note: Accessibility / Screen Recording TCC follows code signature; ad-hoc resign can reset grants (`scripts/build_and_run.sh`, `scripts/test-tcc-local.sh` exist — mention only if useful).
- Remove reference to `.agents/review-profiles/thermo-picker.md` (file does not exist). Optional: mention global thermo review skill only if present in the executor environment; do not invent a local profile path.
- Related: point to other skills by name; do not require `SKILLS_INDEX.md` yet (plan 012).

#### `documentation`

- Ownership:
  - `README.md` — upstream Snapzy human docs (do not pretend this repo’s README is a Notinhas-only pitch unless product later changes it).
  - `AGENTS.md` — **canonical agent guide** for Notinhas (edit this for agent policy).
  - `docs/` — upstream Snapzy engineering docs (CAPTURE, ANNOTATE, etc.); keep in sync when touching those flows; do not invent parallel root markdown backlogs for agent ops.
  - Skills under `.agents/skills/`.
- Remove claims that `CLAUDE.md` exists **or** add creating `CLAUDE.md` → `AGENTS.md` symlink as an explicit optional substep in this plan only if you keep the documentation skill requiring it. **Preferred**: state “optional symlink; create only if tooling needs `CLAUDE.md`” and do **not** create it in this plan.
- Remove Grab Font / YIQ / `--demo` / `./build.sh` checklists.
- MARK examples: large types like `AppStatusBarController`, `AnnotateState`, `NotinhasNoteGeometry`.

#### `swift-conventions`

- Scope paths: `Snapzy/` and `SnapzyTests/` (not `Sources/Picker/`).
- Indent **2**, max width **120**, Swift 5.9 — cite `.swiftformat` and `./scripts/format.sh`.
- Naming: UpperCamelCase types, lowerCamelCase members; `// MARK:` in large types.
- Keep Notinhas code in `Snapzy/Features/Notinhas/`; thin Annotate/Capture integration only.

#### `macos-app-engineering`

- Menu-bar app shell: `AppStatusBarController`, capture overlays, Annotate windows/panels, Quick Access.
- SwiftUI ↔ AppKit bridges are normal; keep MainActor for UI.
- Remove loupe / Grab Font / `DesignSystem.swift` / `--demo` guidance.
- Previews: `#Preview` when practical for isolated SwiftUI views under Notinhas/Annotate.
- Verify with `./scripts/build_and_run.sh` for shell/UI changes.

#### `menubar`

- Owner: `AppStatusBarController` (`NSStatusItem` + `NSMenu`).
- Do **not** document Picker’s left-click panel / right-click quit / non-activating sampling panel contracts.
- Invariants appropriate to Snapzy: single status item lifetime; menu actions gated on Screen Recording permission where capture requires it; no duplicate status items on reopen.
- Related: capture permission → `debugging-diagnostics` / future domain skill.

#### `apple-design`

- Ground in Notinhas/Snapzy UI: annotate chrome, note editor overlay, Quick Access cards, materials/motion already in app.
- Prefer system materials and existing tokens/patterns in the codebase over inventing a Picker `DesignSystem.swift`.
- Respect Reduce Motion / Reduce Transparency / Increase Contrast.
- Remove Grab Font specimen / sliding Colors-Fonts pill guidance.

#### `accessibility-audit`

- Focus: VoiceOver labels on annotate/Notinhas controls, permission prompts (Screen Recording / Accessibility), Escape dismissal for overlays/editors, color-not-only state.
- Remove YIQ swatch ink and Grab Font click-through overlay rules (Picker-specific).
- Point permission UX to onboarding/preferences components when relevant.

#### `debugging-diagnostics`

- Hotspots to document (replace Picker list):
  - Screen Recording denied → capture menu disabled / flows blocked (`ScreenCaptureManager`, `CaptureViewModel` / `ScreenCaptureViewModel`).
  - Accessibility denied → Smart Element / scrolling / window resolver paths.
  - Signing identity changes resetting TCC.
  - Annotate / Notinhas geometry or export surprises (wrong pin order, panel side, clipboard image missing notes panel).
  - ImgBB upload failures (missing API key, network) without logging secrets.
- Never log full screenshots or API keys.

#### `data-persistence`

- Replace palette/font keys with Notinhas-relevant persistence:
  - `PersistedNotinhasNotesSession` inside annotation session restore.
  - `NotinhasImgBBConfiguration.apiKeyUserDefaultsKey` = `notinhas.imgbb.apiKey` (mention key **name** only; never paste secret values).
  - Panel side via `PreferencesKeys.notinhasNotesPanelSide` / `NotinhasImgBBConfiguration.panelSideUserDefaultsKey`.
- Prefer additive Codable evolution; fail soft on corrupt payloads.
- Remove `--demo` / `picker.pickedColors.v1` entirely.

#### `swift-concurrency-expert`

- UI / AppKit controllers on MainActor.
- Image render/export/composition and network upload off MainActor where existing code already does (`nonisolated` geometry, exporter, ImgBB actor).
- Marshal UI updates explicitly from callbacks.
- Remove FontLoader-specific guidance.

#### `testing-xctest`

- Tests live under `SnapzyTests/` (Notinhas suite already exists).
- Prefer pure logic: `NotinhasNoteGeometry`, composer/renderer, annotate state undo, ImgBB response parsing.
- Run: `./scripts/run-tests.sh` or filtered `-only-testing:SnapzyTests/NotinhasNoteGeometryTests`.
- Remove “no test target” / `Tests/PickerTests` language.

#### `localization`

- User-facing strings via existing Snapzy localization (`*.xcstrings`, `NotinhasL10n` where present).
- Keep tone short/direct for designer handoff UI.
- Accessible labels describe actions (e.g. add note, copy, upload) not only glyphs.
- Remove “Copy HEX” / “Grab Font” examples.

#### `code-quality`

- Prefer reuse inside `Snapzy/Features/Notinhas/` before new abstractions.
- Keep upstream Snapzy edits thin; do not rewrite Annotate wholesale.
- Dead code removal needs `rg`/call-site evidence.
- Remove Picker single-package / `./build.sh` references; validation via Notinhas scripts/tests.

### Step 3: Leakage verification

```bash
rg -n -i 'Picker|FontLoader|Grab Font|Sources/Picker|\./build\.sh|picker\.picked|NSColorSampler|YIQ|--demo' .agents/skills
```

**Verify**: no matches. Allowed exceptions: none for this plan. If a legitimate historical note is required, STOP and report rather than adding “formerly Picker” commentary.

Also confirm skill count unchanged:

```bash
ls -1 .agents/skills | wc -l
```

**Verify**: `13`

### Step 4: Spot-check facts against the repo

For each claim of a path or command in the rewritten skills, confirm existence:

```bash
test -f scripts/build_and_run.sh && test -f scripts/run-tests.sh && test -f scripts/format.sh && test -f .swiftformat
test -d Snapzy/Features/Notinhas && test -f Snapzy/App/AppStatusBarController.swift
test -d SnapzyTests/Features/Notinhas
```

**Verify**: all `test` commands exit 0.

### Step 5: Update plans index status

Set plan 010 to DONE in `plans/README.md`.

**Verify**: `rg '010 .*DONE' plans/README.md` matches.

## Test plan

- No Swift tests required (docs-only).
- Mechanical checks in Steps 3–4 are the acceptance tests.
- Optional human review: open `delivery-workflow`, `menubar`, and `data-persistence` and confirm a Notinhas-aware engineer would trust them.

## Done criteria

- [ ] All 13 `.agents/skills/*/SKILL.md` files rewritten for Notinhas/Snapzy
- [ ] `rg -n -i 'Picker|FontLoader|Grab Font|Sources/Picker|\./build\.sh|picker\.picked|NSColorSampler|YIQ|--demo' .agents/skills` returns no matches
- [ ] Still exactly 13 skill directories (no new skills)
- [ ] No Swift / `docs/` / `AGENTS.md` changes in this plan’s commit (AGENTS edits belong to plan 012)
- [ ] `plans/README.md` row for 010 is DONE

## STOP conditions

- Drift check shows unrelated edits to skills you did not expect.
- Step 1 leakage count is already 0 (rebase may already be done).
- A rewritten skill would need to invent APIs/files that do not exist — report the gap instead of fabricating.
- You feel you must create `SKILLS_INDEX.md`, `project-standards`, or `capture-annotate-export` to finish — those belong to plans 012 / 011.
- Any request to “also fix” Swift bugs discovered while reading code.

## Maintenance notes

- After 010, treat Picker leakage in skills as a regression; plan 012 will add governance to prevent it.
- Reviewers should reject any skill PR that reintroduces `./build.sh` or Picker product nouns.
- Deferred: richer Notinhas domain workflow → plan 011; registry/AGENTS routing → plan 012.
