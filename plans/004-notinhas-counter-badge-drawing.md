# Plan 004: Draw Notinhas pin numerals upright using Counter badge drawing

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 18f2e96..HEAD -- Snapzy/Features/Notinhas/Services/NotinhasNoteRenderer.swift Snapzy/Features/Annotate/Services/AnnotateAnnotationRenderer.swift SnapzyTests/Features/Notinhas`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `18f2e96`, 2026-07-20

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — independent of plan 005 (panel contrast) and plan 006 (move/delete)
- **Reviewer required**: `no` — visual parity check is enough; no persistence or gesture changes
- **Rationale**: Isolated drawing fix with a clear exemplar (`AnnotationRenderer.drawCounter`) and no product ambiguity.
- **Escalate when**: sharing the drawer forces a broad Annotate render refactor, or upright text cannot be achieved without changing the canvas coordinate system.
- **Scope guard**: The *only* required behavior change is making Notinhas
  numerals upright. `AnnotationRenderer.drawCounter` already renders correctly —
  rerouting it through a new shared drawer is an **optional** de-duplication,
  not part of the fix. Prefer the smallest change and treat touching the
  working upstream Counter path as opt-in (see Step 2), per the repo's
  "thin seams only / avoid rewriting upstream code" guidance.

## Why this matters

Notinhas pins currently render their numbers upside-down on the Annotate canvas
and in composed exports. The tool looks broken next to Snapzy's existing
Counter badges. The product decision is to keep the Notinhas note model, but
reuse Counter's badge drawing so numerals stay upright and visually match.

## Current state

- `Snapzy/Features/Notinhas/Services/NotinhasNoteRenderer.swift` — draws pins
  with a custom `CTLineDraw` path that manually flips Y. That flip is wrong in
  the AppKit `NSGraphicsContext` used by Annotate and `NSImage.lockFocus`.
- `Snapzy/Features/Annotate/Services/AnnotateAnnotationRenderer.swift` —
  `AnnotationRenderer.drawCounter` draws upright numbers with `NSString.draw(at:)`.
- Notinhas does **not** create `AnnotationItem.counter` annotations; pins stay
  as `NotinhasVisualNote`. Only the **visual badge drawing** is shared.
- There is a **third** number-in-circle site: the export side-panel list
  markers in `NotinhasNotesComposer.drawPanel` (fill ellipse + number via
  `NSAttributedString.draw`, ~lines 153–169). Those already render upright and
  are a different visual (small list markers, not pins). They are **out of
  scope** here — do not route them through the new drawer. Just be aware the
  "single source of truth" claim below covers pins + Counter, not the list
  markers.
- Coordinate systems validated: `AnnotateCanvasDrawingView` does **not**
  override `isFlipped` (default `false`, y-up), matching the unflipped
  `NSImage.lockFocus` export context. So a single `NSString.draw`-based fix is
  correct in both the live canvas and the export composition — no per-context
  branching needed.
- New Swift files under `Snapzy/` are picked up automatically
  (`PBXFileSystemSynchronizedRootGroup` in `Snapzy.xcodeproj`).

Broken path (excerpt):

```153:172:Snapzy/Features/Notinhas/Services/NotinhasNoteRenderer.swift
  private static func drawCenteredNumber(_ number: Int, in rect: CGRect, context: CGContext) {
    let text = "\(number)" as NSString
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.boldSystemFont(ofSize: pinFontSize),
      .foregroundColor: NSColor.white,
    ]
    let size = text.size(withAttributes: attributes)
    let origin = CGPoint(
      x: rect.midX - size.width / 2,
      y: rect.midY - size.height / 2
    )
    context.saveGState()
    context.textMatrix = .identity
    context.translateBy(x: 0, y: origin.y * 2 + size.height)
    context.scaleBy(x: 1, y: -1)
    let attributed = NSAttributedString(string: text as String, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributed)
    context.textPosition = CGPoint(x: origin.x, y: origin.y)
    CTLineDraw(line, context)
    context.restoreGState()
  }
```

Working Counter exemplar (excerpt):

```380:404:Snapzy/Features/Annotate/Services/AnnotateAnnotationRenderer.swift
  private func drawCounter(value: Int, in bounds: CGRect, properties: AnnotationProperties) {
    // ... fill ellipse ...
    let fontSize = min(max(rect.height * 0.5, 11), 56)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
      .foregroundColor: NSColor.white,
    ]
    let text = "\(value)" as NSString
    let textSize = text.size(withAttributes: attributes)
    let textPoint = CGPoint(
      x: rect.midX - textSize.width / 2,
      y: rect.midY - textSize.height / 2
    )
    text.draw(at: textPoint, withAttributes: attributes)
  }
```

Repo conventions: keep Notinhas-specific types under `Snapzy/Features/Notinhas/`;
shared Annotate drawing helpers live under `Snapzy/Features/Annotate/Services/`.
Two-space indent; run `./scripts/format.sh` before finishing.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `./scripts/format.sh` | exit 0 |
| Tests | `./scripts/run-tests.sh` | `success: Tests passed.` (or equivalent all-pass summary) |
| Build | `xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug build` | `** BUILD SUCCEEDED **` |

## Suggested executor toolkit

- Match Counter typography (`NSFont.systemFont(ofSize:weight: .bold)`, white ink).
- Do not invent a Core Text flip “fix” — delete the flip path entirely.

## Scope

**In scope** (the only files you should modify or create):

- `Snapzy/Features/Annotate/Services/AnnotationNumberedBadgeDrawer.swift` (create)
- `Snapzy/Features/Annotate/Services/AnnotateAnnotationRenderer.swift`
  (**optional** — only if you do Step 2's Counter reroute)
- `Snapzy/Features/Notinhas/Services/NotinhasNoteRenderer.swift`
- `SnapzyTests/Features/Notinhas/NotinhasNoteRendererTests.swift` (create)
- `plans/README.md` (status row only)

**Out of scope** (do NOT touch):

- Unifying Notinhas notes into `AnnotationItem.counter`
- Move/delete gestures (plan 006)
- Export panel text colors (plan 005)
- Counter tool behavior, sizing preferences, or undo
- Renaming upstream Annotate types for aesthetics

## Git workflow

- Branch: `fix/notinhas-counter-badge-drawing` (or `advisor/004-notinhas-counter-badge-drawing`)
- Commit style (from recent history): Conventional Commits, e.g.
  `fix: draw Notinhas pin numerals with Counter badge helper`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Extract shared numbered-badge drawer

Create `Snapzy/Features/Annotate/Services/AnnotationNumberedBadgeDrawer.swift` as a
`nonisolated enum` (or struct with static methods) that:

1. Fills an ellipse in `bounds` with the given `NSColor` fill (respect alpha
   already on the color; callers pass the fill they want).
2. Draws the integer value centered with the same font sizing formula as
   Counter: `min(max(bounds.height * 0.5, 11), 56)`, bold system font, white.
3. Uses `NSString.draw(at:withAttributes:)` — **no** `CTLineDraw`, **no**
   `scaleBy(x:1, y:-1)`.

Public API shape (names may vary slightly, but behavior must match):

```swift
nonisolated enum AnnotationNumberedBadgeDrawer {
  static func draw(
    value: Int,
    in bounds: CGRect,
    fillColor: NSColor,
    in context: CGContext
  )
}
```

The drawer must call into the provided `CGContext` for the fill (set fill
color + `fillEllipse`), then draw the string. Keep it AppKit-only
(`import AppKit`).

**Verify**: `rg -n "enum AnnotationNumberedBadgeDrawer|struct AnnotationNumberedBadgeDrawer" Snapzy/Features/Annotate/Services/AnnotationNumberedBadgeDrawer.swift` → matches the new type.

### Step 2 (OPTIONAL): Route Counter through the shared drawer

> **Optional de-duplication, not part of the bugfix.** `drawCounter` already
> renders correctly. Do this only if the diff stays trivial and the reviewer is
> comfortable touching the upstream Counter path. If in doubt, **skip this step**
> and leave `drawCounter` untouched — the drawer can be Notinhas-only.

If you do it: in `AnnotationRenderer.drawCounter`, replace the local fill +
`NSString.draw` body with a call to `AnnotationNumberedBadgeDrawer.draw(...)`,
passing `NSColor(properties.strokeColor)` and the resolved `rect`. Keep the
empty-bounds diameter fallback that already exists in `drawCounter` before
calling the drawer. There must be **no visual change** to Counter badges.

**Verify (only if attempted)**: `rg -n "AnnotationNumberedBadgeDrawer" Snapzy/Features/Annotate/Services/AnnotateAnnotationRenderer.swift` → at least one call site inside `drawCounter`; and Counter renders identically to before (visual parity).

### Step 3: Route Notinhas pins through the shared drawer

In `NotinhasNoteRenderer`:

- Delete `drawCenteredNumber` entirely.
- In `drawPointTarget` and `drawRectangleTarget`, after computing `circleRect`
  (and after any selection stroke), call
  `AnnotationNumberedBadgeDrawer.draw(value:displayNumber, in:circleRect, fillColor:color.withAlphaComponent(0.92), in:context)` —
  or fill the ellipse yourself if you prefer the drawer to only draw the
  numeral; **preferred**: let the drawer own both fill + numeral so Counter and
  Notinhas stay identical.
- If the drawer owns the fill, remove the duplicate `fillEllipse` that currently
  precedes `drawCenteredNumber`, but keep the selection ring stroke that
  Notinhas draws around selected pins.
- Remove unused `pinFontSize` if nothing else references it.
- Keep `pinRadius` / geometry constants unless they become unused.

**Verify**: `rg -n "CTLineDraw|scaleBy\\(x: 1, y: -1\\)|drawCenteredNumber" Snapzy/Features/Notinhas/Services/NotinhasNoteRenderer.swift` → no matches.

### Step 4: Add a focused regression test

Create `SnapzyTests/Features/Notinhas/NotinhasNoteRendererTests.swift` that:

1. Creates an `NSImage` of known size, locks focus, gets `cgContext`.
2. Calls `NotinhasNoteRenderer.drawPointTarget` (or `draw(note:...)`) with
   display number `1` and a bright fill color.
3. Unlocks focus and asserts the image is non-nil / has expected size.

Optional stronger assertion (preferred if cheap): sample a pixel **inside the
badge circle but off the glyph** — e.g. a point ~60–70% of the radius toward
the edge (roughly `center.x + pinRadius*0.6`, `center.y`) — and assert it is
approximately the fill color (not black/empty). Do **not** sample the exact
center: the white numeral is drawn there, so the center pixel is the digit's
ink, not the fill. Do **not** try to OCR the digit.

Also add a tiny unit test on the drawer font/centering math if you expose a
package-visible helper for text attributes; otherwise the render smoke test is
enough.

Model file layout after `SnapzyTests/Features/Notinhas/NotinhasNotesComposerTests.swift`.

**Verify**: `./scripts/run-tests.sh` → all pass, including the new test file.

### Step 5: Format and build

Run `./scripts/format.sh`, then Debug build.

**Verify**: format exit 0; `xcodebuild ... build` prints `** BUILD SUCCEEDED **`.

## Test plan

- New: `NotinhasNoteRendererTests` smoke that pin drawing into an `NSImage`
  succeeds without crashing (regression guard for the CTLine flip removal).
- Existing Counter rendering remains covered by Annotate tests if any; do not
  remove Counter coverage.
- Manual (operator / review): with Note tool, place pins 1–3 on a screenshot;
  numerals must be upright and match Counter weight/centering closely.

Verification: `./scripts/run-tests.sh` → all pass.

## Done criteria

- [ ] Notinhas numerals render upright on canvas **and** in export (the fix)
- [ ] `AnnotationNumberedBadgeDrawer` exists and is used by `NotinhasNoteRenderer`
      (using it from `drawCounter` too is optional; if skipped, Counter is left
      untouched and renders identically)
- [ ] `rg -n "CTLineDraw|scaleBy\\(x: 1, y: -1\\)" Snapzy/Features/Notinhas` returns no matches
- [ ] `./scripts/format.sh` exits 0
- [ ] `./scripts/run-tests.sh` exits 0 with the new test included
- [ ] Debug `xcodebuild` build succeeds
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row for 004 updated

## STOP conditions

Stop and report back (do not improvise) if:

- The Counter `drawCounter` excerpt no longer matches (drift).
- Sharing the drawer requires changing Recording annotation rendering paths
  beyond `AnnotationRenderer.drawCounter`.
- Upright text still fails after switching to `NSString.draw` — report the
  context (`isFlipped`, export vs canvas) instead of reintroducing a flip hack.
- Any out-of-scope file appears necessary for the fix.

## Maintenance notes

- If (and only if) Counter was rerouted through `AnnotationNumberedBadgeDrawer`,
  future Counter visual tweaks (font, ink, padding) should happen in the drawer
  so Notinhas stays in sync. If Counter was left on its own path, note that pin
  and Counter badge styling can drift and must be kept aligned by hand.
- The export side-panel list markers in `NotinhasNotesComposer.drawPanel` are a
  separate, upright drawing path and are intentionally **not** unified here.
- Reviewers should reject any reintroduction of Core Text Y-flip for badge
  numerals in AppKit image contexts.
- Deferred: stroke-width-driven Notinhas pin diameter (Counter supports it;
  Notinhas keeps fixed `pinRadius` unless a later plan asks otherwise).
