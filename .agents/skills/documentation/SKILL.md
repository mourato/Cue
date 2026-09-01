---
name: documentation
description: Documentation guidance for Cue — README, AGENTS.md, docs/, skills routing, and MARK organization in sources.
---

# Documentation

Use when updating project docs, agent guidance, or in-source section markers.

## Ownership

- **README.md** — Cue product docs (install, handoff workflow, development). Localized: `README.vi.md`, `README.zh-CN.md`.
- **AGENTS.md** — canonical agent guide (product intent, structure, commands, fork workflow).
- **docs/** — engineering docs; `MIGRATION.md`, `RELEASES.md`, and `UPDATES.md` describe Notinhas distribution (no Sparkle).
- **`.agents/skills/`** — reusable operational guidance per domain.
- Source `// MARK:` — navigate large files (`AppStatusBarController`, `AnnotateState`, `CueNoteGeometry`).

## Rules

- Keep agent policy in `AGENTS.md`.
- Document Screen Recording / Accessibility requirements when capture or permission UX changes.
- Do not reintroduce Sparkle, About, Report a Problem, or `snapzy://` in user-facing docs.
- Legacy identity references belong only in `docs/MIGRATION.md` (labelled
  migration inputs).
- Prefer linking to skills over duplicating long checklists in README.

## Checklist

- Would a new contributor build and run from README + `AGENTS.md`?
- Do agent docs match `./scripts/build_and_run.sh` and `./scripts/run-tests.sh` with **Cue** scheme paths?
- Is `docs/MIGRATION.md` updated when legacy path or Keychain migration changes?

## Related

- Standards / routing → `AGENTS.md` + `project-standards` + the owning skill
- Delivery commands → `delivery-workflow`
