# Plan 009: Per-note Notinhas pin size using Counter diameter controls

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat dfdfa83..HEAD -- Snapzy/Features/Notinhas Snapzy/Features/Annotate/Models/AnnotateAnnotationToolType.swift Snapzy/Features/Annotate/AnnotateState.swift Snapzy/Features/Annotate/Services/AnnotationNumberedBadgeDrawer.swift SnapzyTests/Features/Notinhas`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (independent of 007/008; land after or beside them)
- **Category**: direction
- **Planned at**: commit `dfdfa83`, 2026-07-20

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `yes` relative to 007/008, but touches shared quick-bar
  sizing paths — coordinate if both land together
- **Reviewer required**: `yes` — persistence, hit-testing, and quick-bar
  wiring must stay compatible with Counter
- **Rationale**: Extends the Notinhas model + geometry + quick properties;
  must reuse Counter diameter math, not invent a third sizing scale.
- **Escalate when**: enabling quick stroke width for `.notinhasNote` breaks
  Counter or other tools’ quick bar.

## Why this matters

Notinhas pins use a fixed diameter (`NotinhasNoteGeometry.pinDiameter = 28` /
`NotinhasNoteRenderer.pinRadius = 14`) while the Annotate **Counter** tool
already exposes a Size slider via quick properties
(`AnnotationProperties.counterDiameter(for:)`). Designers want the same
control for Notinhas. Product decision (A):

- **Per-note** size stored on `NotinhasVisualNote` and persisted in sessions.
- New notes use the **current Note-tool default** size (remembered like other
  tool defaults).
- Changing the quick-bar Size while the Note tool is active updates the tool
  default for **future** notes; it does **not** require Selection-tool
  multi-edit (that was rejected earlier). Optionally, if a note is selected
  under the Note tool, updating Size may also update that selected note —
  preferred UX, include it if cheap.

## Current state

Fixed geometry:

```11:14:Snapzy/Features/Notinhas/Services/NotinhasNoteGeometry.swift
nonisolated enum NotinhasNoteGeometry {
  static let pinDiameter: CGFloat = 28
```

```4:5:Snapzy/Features/Notinhas/Services/NotinhasNoteRenderer.swift
enum NotinhasNoteRenderer {
  static let pinRadius: CGFloat = 14
```

`NotinhasVisualNote` has no size field. `.notinhasNote` explicitly opts out of
quick stroke width:

```150:156:Snapzy/Features/Annotate/Models/AnnotateAnnotationToolType.swift
  var supportsQuickStrokeWidth: Bool {
    switch self {
    case .rectangle, .filledRectangle, .oval, .arrow, .line, .highlighter, .blur, .counter, .pencil:
      return true
    case .selection, .crop, .text, .watermark, .spotlight, .mockup, .notinhasNote:
      return false
```

Counter diameter mapping (reuse exactly):

```1307:1313:Snapzy/Features/Annotate/Models/AnnotateAnnotationItem.swift
  static func counterDiameter(for controlValue: CGFloat) -> CGFloat {
    12 + clampedControlValue(controlValue) * 4
  }
```

Badge drawing already goes through `AnnotationNumberedBadgeDrawer` (plans
004+).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format (touched only) | `swiftformat <paths>` | exit 0 |
| Tests | Notinhas geometry/state/session tests with signing disabled | `** TEST SUCCEEDED **` |
| Build | Debug build with `CODE_SIGNING_ALLOWED=NO` | `** BUILD SUCCEEDED **` |

## Scope

**In scope**:

- `Snapzy/Features/Notinhas/Models/NotinhasVisualNote.swift` — add size field
- `Snapzy/Features/Notinhas/Models/NotinhasNoteTarget.swift` — hit bounds use
  per-note diameter (pass diameter into `selectionBounds` or move hitTest to
  geometry helper that reads the note)
- `Snapzy/Features/Notinhas/Services/NotinhasNoteGeometry.swift`
- `Snapzy/Features/Notinhas/Services/NotinhasNoteRenderer.swift`
- `Snapzy/Features/Notinhas/Annotate/NotinhasAnnotateState.swift` — default
  size on beginDrawing / commit
- `Snapzy/Features/Annotate/Models/AnnotateAnnotationToolType.swift` — enable
  quick size for `.notinhasNote`
- `Snapzy/Features/Annotate/AnnotateState.swift` — tool default persistence +
  quick-bar value read/write for Note tool / selected note
- Session encode/decode already uses `NotinhasVisualNote`; ensure new property
  has a **Decodable default** for old sidecars
- Tests: geometry, model decode default, annotate state default size
- `plans/README.md` status

**Out of scope**:

- Unifying notes into `AnnotationItem.counter`
- Resize handles on-canvas (slider only for this plan)
- Preview composition (008) / editor modal chrome (007)

## Git workflow

- Branch: `feat/notinhas-pin-size`
- Commit example: `feat: add per-note Notinhas pin size like Counter`
- Do NOT push/PR unless asked.

## Steps

### Step 1: Extend the model with Counter-compatible control value

Add to `NotinhasVisualNote`:

```swift
/// Quick-bar Size control value; diameter via AnnotationProperties.counterDiameter(for:).
var pinControlValue: CGFloat
```

- Default for new notes: `AnnotationProperties.clampedControlValue` of the
  Note tool’s remembered stroke width (same storage Counter uses — see
  `annotationToolProperties[.notinhasNote]` / creation properties). If Note
  tool has no stored value yet, use the control value that yields diameter ≈
  28 (current look): solve
  `12 + v*4 = 28` → `v = 4`, then clamp.
- Codable: decode with `decodeIfPresent` defaulting to that legacy value so
  old sessions keep 28pt pins.

Add convenience:

```swift
var pinDiameter: CGFloat {
  AnnotationProperties.counterDiameter(for: pinControlValue)
}
```

**Verify**: round-trip encode/decode test; missing key → diameter 28.

### Step 2: Thread diameter through geometry + renderer

- Replace hard-coded `pinDiameter` / `pinRadius` usages for **drawing and
  hit-testing** with the note’s `pinDiameter` (keep a static default constant
  for legacy/default only).
- `NotinhasNoteTarget.selectionBounds` currently assumes fixed diameter for
  `.point` — change hit-testing to
  `NotinhasNoteGeometry.hitTest(note:at:)` using `note.pinDiameter` (update
  the helper; don’t break rect hit tests).
- `NotinhasNoteRenderer.drawPointTarget` / rect pin: pass diameter into
  `AnnotationNumberedBadgeDrawer.draw` bounds.
- Export composer panel row circles can stay fixed (panel UI), unless they
  already share pin radius — do not change panel row chrome in this plan.

**Verify**: geometry unit tests for hitTest with large vs small pins;
renderer smoke test still passes.

### Step 3: Enable quick Size for the Note tool

1. Set `supportsQuickStrokeWidth` true for `.notinhasNote` (Size label already
   special-cases `.counter` via `quickStrokeWidthUsesSizeLabel` — extend that
   private helper to treat `.notinhasNote` like `.counter`).
2. When Note tool is active and a note is selected, binding writes
   `pinControlValue` on that note (with undo via existing update path).
3. When Note tool is active and no note selected, binding writes the tool
   default in `annotationToolProperties` (same pattern as Counter defaults).
4. `notinhasBeginDrawing` / draft creation copies the current tool default
   into the new note’s `pinControlValue`.

**Verify**: manual — Note tool Size slider changes; new pin uses that size;
old notes keep their stored size; Counter tool still works.

### Step 4: Persistence / session tests

Extend `AnnotationSessionStoreTests` Notinhas round-trip (or Notinhas-specific
tests) to assert `pinControlValue` survives persist/load.

**Verify**: tests green.

### Step 5: Format touched files + build

## Test plan

- Decode missing `pinControlValue` → diameter 28.
- `counterDiameter` mapping shared (same formula as Counter).
- Hit-test radius follows per-note diameter.
- Manual Size slider + create + export badges look correctly sized.

## Done criteria

- [ ] Each note stores its own pin size; old sessions default to prior 28pt look
- [ ] Note tool shows Size in quick properties like Counter
- [ ] New notes use the tool default size
- [ ] Renderer + hit-testing honor per-note diameter
- [ ] Counter tool behavior unchanged
- [ ] Tests + Debug build succeed
- [ ] Scope respected; README row 009 updated

## STOP conditions

- Enabling `supportsQuickStrokeWidth` for Notinhas breaks Counter or text tools
  — stop; use a Notinhas-specific quick-bar affordance instead of the shared
  flag.
- Persisted sessions fail to decode after adding the field — stop; fix
  decode defaults before continuing.
- Diameter must differ from Counter’s formula for product reasons — stop and
  confirm with the operator (this plan requires shared formula).

## Maintenance notes

- Future “resize selected note from Selection tool” is out of scope; do not
  silently add it.
- Reviewers: confirm export badges and canvas badges use the same per-note
  diameter.
