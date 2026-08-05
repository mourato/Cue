# Plan 011: Add `capture-annotate-export` domain skill (visual handoff)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 415d662..HEAD -- .agents/skills AGENTS.md plans`
> If plans 010/012 are not DONE, STOP — do not author this skill against Picker-era guidance.
> If in-scope files changed since this plan was written, re-read live excerpts before proceeding.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: `plans/010-rebase-skills-notinhas.md`, `plans/012-port-project-standards.md`
- **Category**: docs / direction
- **Planned at**: commit `415d662`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `no` — depends on rebased skills + governance template
- **Reviewer required**: `yes` — domain accuracy for capture → notes → clipboard
- **Rationale**: Adds one skill markdown file plus index/AGENTS registration already scaffolded by 003; no Swift changes.
- **Escalate when**: live code paths contradict the inlined skill draft (wrong entry points, missing export hooks), or ImgBB/security guidance needs a separate keychain plan.

## Why this matters

Notinhas’ product loop is capture → numbered pins/rects + notes → clipboard-ready export. No skill owns that loop today. Without it, agents fall back to generic macOS or leftover Picker habits and expand scope into recording/cloud/generic markup that `AGENTS.md` explicitly discourages. This skill becomes the canonical domain owner for visual handoff work.

## Current state

- After plan 010: the 13 base skills describe Notinhas, not Picker.
- After plan 012: `.agents/skills/project-standards/SKILL.md` exists, `.agents/SKILLS_INDEX.md` exists, and `AGENTS.md` has a skills routing section (possibly listing a placeholder for this skill).
- This skill directory **does not** exist yet: `.agents/skills/capture-annotate-export/`.
- Product intent (must be restated in the skill):

```3:10:AGENTS.md
Notinhas is a tailored macOS visual-handoff tool for a product designer. It
turns a screenshot into an unambiguous brief for developers and AI coding
agents: capture an area, place numbered pins or rectangles, add concise notes,
and copy the annotated result. ... Do not add broad recording, cloud, or generic markup
features unless they directly support that workflow.
```

- Module layout (all under `Snapzy/Features/Notinhas/`):

```
Annotate/NotinhasAnnotateState.swift
Models/{NotinhasAreaStyle,NotinhasNoteTarget,NotinhasNotesPanelSide,NotinhasPaletteColor,NotinhasVisualNote,PersistedNotinhasNotesSession}.swift
Services/{NotinhasNoteGeometry,NotinhasNotesComposer,NotinhasNoteRenderer,NotinhasNoteCompositor,NotinhasNotesPanelStyle,NotinhasImgBB*,NotinhasUploadCoordinator}.swift
Views/{NotinhasNoteEditor*,NotinhasNotesSidePanelView,NotinhasAreaStylePreviewButton}.swift
NotinhasL10n.swift
```

- Integration is thin into upstream Annotate/Capture (do not rewrite upstream):
  - Tool: `AnnotationToolType.notinhasNote`
  - State extension: `NotinhasAnnotateState.swift` on `AnnotateState`
  - Export: `AnnotateExporter.composeNotinhasIfNeeded` / `exportableNotinhasNotes`
  - Capture entry: area + inline annotate via `CaptureViewModel.captureAreaAnnotate()` → `startInlineAreaAnnotateCapture()`
  - Clipboard: `AnnotateExporter.copyToClipboard` → final image including Notinhas panel when notes exist
- Permissions are **upstream**, not inside Notinhas/:
  - Screen Recording: `ScreenCaptureManager.checkPermission()` / `CGPreflightScreenCaptureAccess()`
  - Accessibility: `SmartElementQueryService.ensureAccessibilityPermission()` (and related capture helpers)
- Geometry exemplar:

```11:18:Snapzy/Features/Notinhas/Services/NotinhasNoteGeometry.swift
nonisolated enum NotinhasNoteGeometry {
  static let pinDiameter: CGFloat = 28
  static let dragThreshold: CGFloat = 8
  static let minimumRectSize: CGFloat = 24
  ...
}
```

- Tests already covering domain logic: `SnapzyTests/Features/Notinhas/*` (geometry, composer, renderer, annotate state, pin size, ImgBB).
- Upstream narrative docs to cite (read-only): `docs/CAPTURE.md`, `docs/ANNOTATE.md`, `docs/POST_CAPTURE.md`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Preconditions | `test -f .agents/skills/project-standards/SKILL.md && test -f .agents/SKILLS_INDEX.md` | exit 0 |
| Create skill dir | `mkdir -p .agents/skills/capture-annotate-export` | dir exists |
| Leakage scan | `rg -n -i 'Picker\|FontLoader\|Grab Font\|\\./build\\.sh' .agents/skills/capture-annotate-export` | no matches |
| Path sanity | `test -f Snapzy/Features/Notinhas/Services/NotinhasNoteGeometry.swift` | exit 0 |
| Focused tests (optional) | `./scripts/run-tests.sh -only-testing:SnapzyTests/NotinhasNoteGeometryTests` | pass (no code change expected) |

## Suggested executor toolkit

- Follow skill template from `.agents/skills/project-standards/SKILL.md` (Role, Scope Boundary, When to Use, guidance, Verification, Related Skills, References).
- Read `docs/CAPTURE.md` Flow Index and `docs/ANNOTATE.md` only as vocabulary references — do not duplicate entire docs into the skill.

## Scope

**In scope**:
- Create `.agents/skills/capture-annotate-export/SKILL.md`
- Update `.agents/SKILLS_INDEX.md` to register this skill as the domain owner for visual handoff
- Update `AGENTS.md` skills routing table/section (created in 012) to include this skill if not already listed as TODO

**Out of scope**:
- Any Swift implementation, refactors, or new tests
- Changing ImgBB storage to Keychain
- Expanding product into recording/cloud/generic markup
- Rewriting the 13 base skills (plan 010)
- Changing `project-standards` policy beyond index/AGENTS registration lines

## Git workflow

- Branch: `advisor/011-capture-annotate-export-skill` (or continue the advisor branch if 010/012 already landed there — prefer one branch per plan if separate PRs).
- Commit message example: `docs(agents): add capture-annotate-export skill`
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Verify dependencies landed

```bash
rg -n -i 'Picker|FontLoader|Grab Font|\./build\.sh' .agents/skills | head
test -f .agents/skills/project-standards/SKILL.md
test -f .agents/SKILLS_INDEX.md
rg -n 'skills|Skills' AGENTS.md | head
```

**Verify**:
- Picker leakage scan is empty (or only mentions outside skills — should be empty under `.agents/skills`).
- `project-standards` and `SKILLS_INDEX.md` exist.
- `AGENTS.md` mentions skills routing.

If any fail → STOP (run/finish 001 and 003 first).

### Step 2: Write the skill file

Create `.agents/skills/capture-annotate-export/SKILL.md` with content that matches the following draft closely (executor may tighten wording but must keep facts, paths, and boundaries).

````markdown
---
name: capture-annotate-export
description: Visual handoff loop for Notinhas — area capture, numbered pins/rects + notes, export composition, and clipboard-ready output. Use for Notinhas geometry, annotate integration, export panel, ImgBB upload UX, and scope questions about recording/cloud/markup.
---

# Capture → Annotate → Export

## Role

Canonical owner for Notinhas visual-handoff behavior: capture an area, place numbered pins or rectangles with concise notes, and produce clipboard-ready annotated output.

## Scope Boundary

- Own the Notinhas module (`Snapzy/Features/Notinhas/`) and its thin hooks into Capture/Annotate export/clipboard.
- Delegate menu-bar shell details to `menubar` / `macos-app-engineering`.
- Delegate generic Swift style, concurrency, tests, and delivery commands to their skills.
- Do **not** use this skill to grow broad screen recording, generic markup toolbelts, or unrelated cloud features unless the change directly serves the handoff loop.

## When to Use

Use when the user asks to change Notinhas notes/pins/rects, note editor UX, notes side panel, export composition, clipboard output of annotated briefs, Notinhas geometry/hit-testing, ImgBB upload from annotate, or to decide whether a request is in/out of Notinhas product scope.

## Product Loop

1. **Capture** — prefer area capture that lands in Annotate (inline area annotate / post-capture open annotate). Entry: `CaptureViewModel.captureAreaAnnotate()` → `startInlineAreaAnnotateCapture()`; also post-capture annotate via preferences.
2. **Annotate** — tool `AnnotationToolType.notinhasNote`; state in `AnnotateState` via `NotinhasAnnotateState` helpers; models `NotinhasVisualNote` + `NotinhasNoteTarget` (`.point` / `.rect`).
3. **Export** — `NotinhasNoteRenderer` draws markers; `NotinhasNotesComposer` / `NotinhasNoteCompositor` add the notes panel; `AnnotateExporter.composeNotinhasIfNeeded` integrates into final image; clipboard via `AnnotateExporter.copyToClipboard`.

## Canonical Paths

| Concern | Path / symbol |
|---------|----------------|
| Geometry (pure) | `Snapzy/Features/Notinhas/Services/NotinhasNoteGeometry.swift` |
| Note model | `Snapzy/Features/Notinhas/Models/NotinhasVisualNote.swift` |
| State mutations | `Snapzy/Features/Notinhas/Annotate/NotinhasAnnotateState.swift` |
| Editor UI | `NotinhasNoteEditorView` / `NotinhasNoteEditorOverlay` |
| Side panel | `NotinhasNotesSidePanelView` |
| Composition | `NotinhasNotesComposer`, `NotinhasNoteRenderer` |
| Export hook | `AnnotateExporter.composeNotinhasIfNeeded` |
| Session persist | `PersistedNotinhasNotesSession` on `PersistedAnnotationSession` |
| ImgBB | `NotinhasImgBBConfiguration`, `NotinhasImgBBUploadService`, `NotinhasUploadCoordinator` |
| Screen Recording permission | `ScreenCaptureManager` (upstream) |
| Accessibility permission | `SmartElementQueryService.ensureAccessibilityPermission()` (upstream; not Notinhas-core) |

## Invariants

- Keep Notinhas-specific logic inside `Snapzy/Features/Notinhas/` when possible; Annotate/Capture edits stay thin.
- Pin/rect display order and export transforms go through `NotinhasNoteGeometry` — do not fork ad-hoc numbering in views.
- Export preview and clipboard must include the notes panel when renderable notes exist.
- UI on MainActor; pure geometry/`CGContext` work may be `nonisolated` as in existing code.
- Never log API keys or full screenshot bitmaps in diagnostics.
- ImgBB API key key-name: `notinhas.imgbb.apiKey` (UserDefaults) — do not print values.

## Out-of-Scope Pressure Tests

Reject or narrow requests that primarily add: full recording suites, generic shape tool parity for its own sake, or cloud storage platforms unrelated to shipping the brief — unless the user explicitly overrides product intent.

## Verification

- Pure logic: `./scripts/run-tests.sh -only-testing:SnapzyTests/NotinhasNoteGeometryTests` (and other `SnapzyTests/Features/Notinhas/*` as touched).
- Manual: Screen Recording granted → area capture → add pin + rect notes → Preview/export → copy → paste shows markers + notes panel.
- Permission regressions: confirm capture still disabled/prompting correctly when Screen Recording is off.

## Related Skills

- `../delivery-workflow/SKILL.md` — build/test/format commands
- `../macos-app-engineering/SKILL.md` — SwiftUI/AppKit hosting
- `../debugging-diagnostics/SKILL.md` — permission/signing failures
- `../testing-xctest/SKILL.md` — XCTest layout
- `../data-persistence/SKILL.md` — session/API key keys
- `../project-standards/SKILL.md` — where guidance lives

## References

- `AGENTS.md` — product intent + fork workflow
- `docs/CAPTURE.md`, `docs/ANNOTATE.md`, `docs/POST_CAPTURE.md` — upstream flow narrative
````

**Verify**:

```bash
test -f .agents/skills/capture-annotate-export/SKILL.md
rg -n '^name: capture-annotate-export' .agents/skills/capture-annotate-export/SKILL.md
rg -n 'NotinhasNoteGeometry|composeNotinhasIfNeeded|captureAreaAnnotate' .agents/skills/capture-annotate-export/SKILL.md
```

All succeed; skill mentions geometry, export hook, and capture entry.

### Step 3: Register in `SKILLS_INDEX.md` and `AGENTS.md`

- Add a row/section for `capture-annotate-export` as **domain owner** for visual handoff / Notinhas notes / export / clipboard brief.
- Ensure routing text: “Notinhas pin/note/export work → `capture-annotate-export` first.”
- If 012 left a placeholder “TODO: capture-annotate-export”, replace it with the real entry.

**Verify**:

```bash
rg -n 'capture-annotate-export' .agents/SKILLS_INDEX.md AGENTS.md
```

At least one hit in each file.

### Step 4: Leakage and scope check

```bash
rg -n -i 'Picker|FontLoader|Grab Font|\./build\.sh|Sources/Picker' .agents/skills/capture-annotate-export
git status --short
```

**Verify**: no leakage matches; changed files limited to the skill file + index + `AGENTS.md` (skills section only).

### Step 5: Update plans index

Mark plan 011 DONE in `plans/README.md`.

## Test plan

- Docs-only; no new XCTest required.
- Optional: run `./scripts/run-tests.sh -only-testing:SnapzyTests/NotinhasNoteGeometryTests` to ensure the environment still works (must pass without code changes).
- Reviewer checklist: skill paths resolve; product “do not expand recording/cloud/markup” boundary present; Related Skills links use relative `../…/SKILL.md` form consistent with other skills post-003.

## Done criteria

- [ ] `.agents/skills/capture-annotate-export/SKILL.md` exists with YAML `name: capture-annotate-export`
- [ ] Skill documents capture entry, Notinhas module paths, export/clipboard hooks, permissions owners, and out-of-scope pressure tests
- [ ] Registered in `.agents/SKILLS_INDEX.md` and `AGENTS.md`
- [ ] No Picker leakage in the new skill
- [ ] No Swift source modifications
- [ ] `plans/README.md` row for 011 is DONE

## STOP conditions

- Plans 010 or 012 not DONE / preconditions fail.
- Live symbols renamed since this plan (e.g. `composeNotinhasIfNeeded` missing) — update the skill only after confirming the new symbol; if unclear, STOP and report.
- Temptation to implement ImgBB Keychain migration or Annotate refactors “while documenting.”
- Skill draft would exceed ~250 lines by pasting entire `docs/CAPTURE.md` — summarize and link instead.

## Maintenance notes

- When Notinhas export/clipboard behavior changes, update this skill in the same PR as the Swift change (per `project-standards`).
- Reviewers should check that new Notinhas features did not invent a second geometry helper outside `NotinhasNoteGeometry`.
- Deferred: Keychain for ImgBB secrets; richer permission skill if TCC flows keep growing.
