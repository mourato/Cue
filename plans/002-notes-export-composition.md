# Plan 002: Export a Notes composition and preference

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, report it; do not improvise. Update this plan's row in
> `plans/README.md` only after the code-review gate passes.
>
> **Drift check (run first)**: `git diff --stat bad6da2..HEAD -- Snapzy/Features/Annotate Snapzy/Features/Notinhas Snapzy/Features/Preferences SnapzyTests/Features/Annotate SnapzyTests/Features/Notinhas Snapzy/Resources/Localization`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/001-notes-editor-extension.md`
- **Category**: direction
- **Planned at**: commit `bad6da2`, 2026-07-20

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — it consumes Plan 001's model and becomes the single
  output path for copy, save, close, and later Imgur uploads.
- **Reviewer required**: yes — output pixel geometry and existing exporter
  behavior are regression-sensitive.
- **Rationale**: The work touches export snapshots, image dimensions,
  preferences, localization, and session-aware output.
- **Escalate when**: mockup/crop composition cannot reuse a post-render image
  pass, or a change to core exporter ordering is required.

## Why this matters

A marker without its written context is ambiguous. When Notes exist, every
final artifact must carry the captured image plus a readable Notes panel whose
numbered rows map exactly to the pins/areas. The same deterministic composition
must be used by copy, save, close, and upload so recipients never receive a
different interpretation of the screenshot.

## Current state

- `AnnotateExporter.renderFinalImage` is the shared final-render path for
  save/copy and is documented in `docs/ANNOTATE.md` as the single exporter.
- `AnnotationRenderer` draws `AnnotationItem` content in Core Graphics; Plan
  001 adds the Notinhas visual-note renderer without modifying upstream types.
- `PreferencesKeys` centralizes `@AppStorage` keys; `PreferencesAnnotateSettingsView`
  is the existing Annotate settings surface.
- The current exporter can create an image with no Notes; that behavior must
  remain byte/size compatible when the Notes array is empty.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `./scripts/format.sh` | SwiftFormat exits 0 |
| Tests | `./scripts/run-tests.sh` | `success: Tests passed.` |
| Build | `xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug build` | `** BUILD SUCCEEDED **` |
| Run | `./scripts/build_and_run.sh` | `Snapzy Debug` launches |

## Scope

**In scope**

- `Snapzy/Features/Notinhas/Services/NotinhasNotesComposer.swift` and tests
  for pure layout/rendering.
- Narrow calls from `AnnotateExporter` and its render-snapshot path.
- One versioned `PreferencesKeys` setting and controls in the existing Annotate
  settings view; localization catalog changes.
- Export/snapshot tests in `SnapzyTests/Features/Annotate/` and pure compositor
  tests in `SnapzyTests/Features/Notinhas/`.

**Out of scope**

- New Notes gestures/models (Plan 001), Imgur/networking (Plan 003), or any
  changes to normal images that contain no Notes.
- Changing global Quick Access layout or existing cloud-provider settings.

## Steps

### Step 1: Define deterministic composition rules in the extension

Create a pure `NotinhasNotesComposition`/`NotinhasNotesComposer` under
`Features/Notinhas`. It receives the already-rendered base image, ordered
Notes, panel side, and display scale. It returns a new image only when Notes
exist. Default side is left; the only alternative is right.

Use a neutral panel background, `Notes` heading, and rows containing a colored
circular number and wrapped note text. Do not reproduce CuePin branding or its
legend. Preserve base-image pixels at their original scale; add width for the
panel rather than shrinking or cropping the screenshot. Use deterministic
panel width, padding, font metrics, and row spacing; wrap long text and expand
the output height only when required to avoid clipping. Render the pin/area
artwork with the same Notinhas renderer used on-canvas.

**Verify**: `./scripts/run-tests.sh -only-testing:SnapzyTests/Features/Notinhas` →
layout tests pass for left/right, long text, each style, and no-notes passthrough.

### Step 2: Insert the composition after the existing final render

At the narrowest post-render seam in `AnnotateExporter`, apply the composer to
the final flat image and its matching Notes snapshot. Do this for both
state-based and `AnnotateRenderSnapshot` rendering so foreground copy/save and
background close/save produce the identical output. Keep the existing mockup,
crop, embedded-image, and standard annotation order unchanged; Notes compose
after that final image exists.

Do not persist a flattened Notes panel as the editable source. Keep the base
image plus session Notes in the sidecar so reopening remains editable.

**Verify**: `./scripts/run-tests.sh -only-testing:SnapzyTests/Features/Annotate/AnnotateRenderSnapshotTests` →
snapshot rendering tests pass, including a new Notes image-dimension/pixel test.

### Step 3: Add the panel-side preference

Add `annotate.notinhasNotes.panelSide.v1` in `PreferencesKeys`, with an enum
that defaults to `.left` on an absent or invalid value. Show a two-choice
control (Left / Right) in `PreferencesAnnotateSettingsView`. Keep the setting
local to Notinhas behavior; do not add it to Snapzy's generic canvas preset or
TOML schema in this release. Add all user-facing strings through the existing
`.xcstrings` catalogs.

**Verify**: `./scripts/run-tests.sh -only-testing:SnapzyTests/Features/Notinhas` →
preference decoding/default tests pass.

### Step 4: Perform mandatory code review

Have a reviewer compare canvas, foreground export, and render-snapshot output
for the same note session. Confirm: empty Notes return the unmodified existing
output; nonempty Notes always create exactly one panel; left/right merely
changes placement; long text does not overlap or clip; the original screenshot
is not rescaled; and no CuePin assets/copy were introduced. Review the diff for
extension-boundary violations and require visual screenshots for all three area
styles.

**Verify**: `git diff --check && ./scripts/run-tests.sh` → no whitespace
errors and `success: Tests passed.`

## Test plan

- Pure composition tests: empty passthrough; left/right placement; sequential
  row order/color; long multi-line content; each area style.
- Export tests: regular and snapshot paths have equal pixel dimensions and
  include the Notes panel only when Notes exist.
- Manual macOS test: save, copy, close-and-save, crop, mockup, and reopen; use
  left then right preference and verify the panel remains legible.

## Done criteria

- [ ] Every final output with Notes has a baked `Notes` panel on the configured
  side; outputs with no Notes are unchanged.
- [ ] Original screenshot pixels retain scale and notes text never clips.
- [ ] Left is the default; invalid/missing preference values fail to left.
- [ ] Full XCTest suite and Debug build pass.
- [ ] Mandatory code review completed and the README status is updated.

## STOP conditions

- The only way to render the panel changes the source image in-place or loses
  editable session data.
- The snapshot exporter cannot receive a value copy of the Notes list.
- Correct panel layout requires a third-party renderer or unsupported minimum
  macOS API.

## Maintenance notes

Keep layout constants and Core Graphics drawing inside the Notinhas composer.
Future alternate formats (Markdown, PDF, other sidebars) should be separate
composers, not branches spread across `AnnotateExporter`. Plan 003 must call
this exact final-render path rather than generating a second upload-only image.
