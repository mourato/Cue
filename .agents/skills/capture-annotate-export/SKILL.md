---
name: capture-annotate-export
description: Visual handoff loop for Notinhas — area capture, numbered pins/rects + notes, export composition, and clipboard-ready output. Use for Notinhas geometry, annotate integration, export panel, ImgBB upload UX, and scope questions about recording/cloud/markup.
---

# Capture → Annotate → Export

## Role

Canonical owner for Notinhas visual-handoff behavior: capture an area, place numbered pins or rectangles with concise notes, and produce clipboard-ready annotated output.

## Scope Boundary

- Own the Notinhas module (`Notinhas/Features/Notinhas/`) and its thin hooks into Capture/Annotate export/clipboard.
- Delegate menu-bar shell details to the global `menubar` and
  `macos-app-engineering` skills, with their Notinhas overlays.
- Delegate generic Swift style, concurrency, tests, and delivery commands to their skills.
- Do **not** use this skill to grow broad screen recording, generic markup toolbelts, or unrelated cloud features unless the change directly serves the handoff loop.
- Screen recording and Video Editor are **optional** inherited features, gated
  at compile time (`NOTINHAS_VIDEO_MODULE`) and runtime
  (`VideoModuleAvailability` / `videoModule.enabled`, default off). Notinhas
  handoff work does not require them; see the global `delivery-workflow` skill
  and its Notinhas overlay for build/test
  with the Video module on.

## When to Use

Use when the user asks to change Notinhas notes/pins/rects, note editor UX, notes side panel, export composition, clipboard output of annotated briefs, Notinhas geometry/hit-testing, ImgBB upload from annotate, or to decide whether a request is in/out of Notinhas product scope.

## Product Loop

1. **Capture** — prefer area capture that lands in Annotate (inline area annotate / post-capture open annotate). Entry: `CaptureViewModel.captureAreaAnnotate()` → `startInlineAreaAnnotateCapture()`; also post-capture annotate via preferences.
2. **Annotate** — tool `AnnotationToolType.notinhasNote`; state in `AnnotateState` via `NotinhasAnnotateState` helpers; models `NotinhasVisualNote` + `NotinhasNoteTarget` (`.point` / `.rect`).
3. **Export** — `NotinhasNoteRenderer` draws markers; `NotinhasNotesComposer` / `NotinhasNoteCompositor` add the notes panel; `AnnotateExporter.composeNotinhasIfNeeded` integrates into final image; clipboard via `AnnotateExporter.copyToClipboard`.

## Canonical Paths

| Concern | Path / symbol |
|---------|----------------|
| Geometry (pure) | `Notinhas/Features/Notinhas/Services/NotinhasNoteGeometry.swift` |
| Note model | `Notinhas/Features/Notinhas/Models/NotinhasVisualNote.swift` |
| State mutations | `Notinhas/Features/Notinhas/Annotate/NotinhasAnnotateState.swift` |
| Editor UI | `NotinhasNoteEditorView` / `NotinhasNoteEditorCanvasOverlay` |
| Side panel | `NotinhasNotesSidePanelView` |
| Composition | `NotinhasNotesComposer`, `NotinhasNoteRenderer` |
| Export hook | `AnnotateExporter.composeNotinhasIfNeeded` |
| Session persist | `PersistedNotinhasNotesSession` on `PersistedAnnotationSession` |
| ImgBB | `NotinhasImgBBConfiguration`, `NotinhasImgBBUploadService`, `NotinhasUploadCoordinator` |
| Screen Recording permission | `ScreenCaptureManager` (upstream) |
| Accessibility permission | `SmartElementQueryService.ensureAccessibilityPermission()` (upstream; not Notinhas-core) |

## Invariants

- Keep Notinhas-specific logic inside `Notinhas/Features/Notinhas/` when possible; Annotate/Capture edits stay thin.
- Pin/rect display order and export transforms go through `NotinhasNoteGeometry` — do not fork ad-hoc numbering in views.
- Export preview and clipboard must include the notes panel when renderable notes exist.
- UI on MainActor; pure geometry/`CGContext` work may be `nonisolated` as in existing code.
- Never log API keys or full screenshot bitmaps in diagnostics.
- ImgBB API key key-name: `notinhas.imgbb.apiKey` (UserDefaults) — do not print values.

## Inherited Surfaces (Retained)

Inherited Snapzy capabilities that **remain** in the tree (not dead-code targets):
scrolling/OCR/Smart Element/object cutout/All-In-One capture; BYO cloud
(S3/R2/Google Drive) alongside handoff-oriented ImgBB; annotate watermark,
combine, and integrated mockup. See
[`docs/adr/070-retain-inherited-snapzy-surfaces.md`](../../docs/adr/070-retain-inherited-snapzy-surfaces.md).

## Removed Upstream Channels

Do **not** reintroduce: Sparkle auto-updates, About/Check for Updates UI,
Report a Problem flows, `snapzy://` URL aliases, public support endpoints,
Homebrew cask distribution, or Discord release bots — per Product Intent and
[ADR 070](../../docs/adr/070-retain-inherited-snapzy-surfaces.md).

## Out-of-Scope Pressure Tests

Reject or narrow requests that primarily add: full recording suites, generic shape tool parity for its own sake, or cloud storage platforms unrelated to shipping the brief — unless the user explicitly overrides product intent.

## Verification

- Pure logic: `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasNoteGeometryTests` (and other `NotinhasTests/Features/Notinhas/*` as touched).
- Manual: Screen Recording granted → area capture → add pin + rect notes → Preview/export → copy → paste shows markers + notes panel.
- Permission regressions: confirm capture still disabled/prompting correctly when Screen Recording is off.

## Related Skills

- Global `delivery-workflow` — build/test/format commands
- Global `macos-app-engineering` — SwiftUI/AppKit hosting
- `debugging-diagnostics` — permission/signing failures
- `testing-xctest` — XCTest layout
- `data-persistence` — session/API key keys
- `project-standards` — where guidance lives

## References

- `AGENTS.md` — product intent + fork workflow
- `docs/CAPTURE.md`, `docs/ANNOTATE.md`, `docs/POST_CAPTURE.md` — upstream flow narrative
