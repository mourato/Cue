# Plan 005: Make exported Notes panel text readable on the light background

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 18f2e96..HEAD -- Snapzy/Features/Notinhas/Services/NotinhasNotesComposer.swift SnapzyTests/Features/Notinhas/NotinhasNotesComposerTests.swift`
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
- **Parallelizable**: `yes` — independent of plans 004 and 006
- **Reviewer required**: `no`
- **Rationale**: Color-token fix in one composer file with a deterministic unit test.
- **Escalate when**: export composition is rewritten away from
  `NotinhasNotesComposer`, or panel layout changes force a broader redesign.

## Why this matters

Exported Notinhas compositions append a light Notes panel. On dark-mode Macs,
`NSColor.labelColor` resolves to white while the panel fill stays near-white
(`NSColor(white: 0.97)`), so note text is effectively invisible. The chosen
product fix is: **keep the light panel and force explicit dark ink**, so
clipboard/export output is readable regardless of system appearance.

## Current state

- `Snapzy/Features/Notinhas/Services/NotinhasNotesComposer.swift` draws the
  export panel inside `NSImage.lockFocus`.
- Background is hardcoded light; header/body text use `NSColor.labelColor`.

```117:141:Snapzy/Features/Notinhas/Services/NotinhasNotesComposer.swift
  private static func drawPanel(
    notes: [NotinhasVisualNote],
    in panelRect: CGRect,
    context: CGContext
  ) {
    context.saveGState()
    context.setFillColor(NSColor(white: 0.97, alpha: 1).cgColor)
    context.fill(panelRect)
    // ...
    let headerAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.boldSystemFont(ofSize: 18),
      .foregroundColor: NSColor.labelColor,
    ]
    // ...
    let textAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 14),
      .foregroundColor: NSColor.labelColor,
    ]
```

- Live SwiftUI panel (`NotinhasNotesSidePanelView`) uses `.primary` / materials
  and is **out of scope** unless you discover it also hardcodes white-on-white
  (it should not — do not change it “for consistency”).
- Existing tests in `SnapzyTests/Features/Notinhas/NotinhasNotesComposerTests.swift`
  only assert output size, not ink color.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `./scripts/format.sh` | exit 0 |
| Tests | `./scripts/run-tests.sh` | all pass |
| Build | `xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug build` | `** BUILD SUCCEEDED **` |

## Scope

**In scope**:

- `Snapzy/Features/Notinhas/Services/NotinhasNotesComposer.swift`
- Optionally create
  `Snapzy/Features/Notinhas/Services/NotinhasNotesPanelStyle.swift` if you
  extract tokens (preferred for testability)
- `SnapzyTests/Features/Notinhas/NotinhasNotesComposerTests.swift`
- `plans/README.md` (status row only)

**Out of scope**:

- Live `NotinhasNotesSidePanelView` styling
- Dark-mode export panel variant (rejected for this plan)
- Pin badge numeral color (stays white on colored circles)
- Imgur upload / exporter call sites (they already use this composer)

## Git workflow

- Branch: `fix/notinhas-export-panel-contrast` (or `advisor/005-notinhas-export-panel-contrast`)
- Commit example: `fix: use dark ink on Notinhas export notes panel`
- Do NOT push or open a PR unless asked.

## Steps

### Step 1: Introduce fixed panel color tokens

Add a small `nonisolated` style surface (either nested in the composer file or
a dedicated `NotinhasNotesPanelStyle.swift`) with explicit colors, for example:

```swift
nonisolated enum NotinhasNotesPanelStyle {
  static let background = NSColor(white: 0.97, alpha: 1)
  /// Near-black ink — must stay dark even when the app runs in dark mode.
  static let primaryText = NSColor(white: 0.12, alpha: 1)
}
```

Do **not** use `NSColor.labelColor`, `NSColor.textColor`, or
`NSColor.secondaryLabelColor` for panel title/body text.

**Verify**: `rg -n "labelColor" Snapzy/Features/Notinhas/Services/NotinhasNotesComposer.swift` → no matches after step 2.

### Step 2: Wire `drawPanel` to the tokens

Replace:

- panel fill → `NotinhasNotesPanelStyle.background` (or equivalent)
- header `.foregroundColor` → `primaryText`
- note body `.foregroundColor` → `primaryText`

Leave badge numbers white on the note’s fill color.

**Verify**: `rg -n "foregroundColor: NSColor\\.(labelColor|textColor)" Snapzy/Features/Notinhas/Services/NotinhasNotesComposer.swift` → no matches.

### Step 3: Add a regression test for ink luminance

In `NotinhasNotesComposerTests.swift` (or a new focused test file under the
same folder), assert that the panel primary text color’s brightness is low
enough to contrast with the light background. Example approach:

```swift
func testExportPanelPrimaryTextIsDarkInk() {
  let ink = NotinhasNotesPanelStyle.primaryText
  // Calibrated RGB; avoid appearance-dependent dynamic colors.
  XCTAssertLessThan(ink.brightnessComponent, 0.35)
  XCTAssertGreaterThan(NotinhasNotesPanelStyle.background.brightnessComponent, 0.9)
}
```

If `brightnessComponent` is inconvenient for the chosen color space, convert
with `ink.usingColorSpace(.deviceRGB)` first, then assert
`redComponent`/`greenComponent`/`blueComponent` are all `< 0.35`.

Also keep existing size tests passing.

**Verify**: `./scripts/run-tests.sh` → the new test runs and passes.

### Step 4: Format and build

**Verify**: `./scripts/format.sh` exit 0; Debug build succeeds.

## Test plan

- Unit test: panel style tokens enforce dark ink + light background.
- Manual: with macOS Appearance = Dark, compose/copy a Notinhas image; Notes
  panel title and comments must be clearly readable.

## Done criteria

- [ ] Export panel title and note body no longer use `NSColor.labelColor`
- [ ] Explicit dark ink + light background tokens exist and are tested
- [ ] The per-row list marker number stays **white on the note's fill color**
      (the `\(index + 1)` badge at ~lines 156–169) — do NOT switch it to the
      dark ink token "for consistency"; only header + body text change
- [ ] `./scripts/format.sh` exits 0
- [ ] `./scripts/run-tests.sh` exits 0
- [ ] Debug build succeeds
- [ ] No files outside the in-scope list are modified
- [ ] `plans/README.md` status row for 005 updated

## STOP conditions

- `drawPanel` no longer owns panel text attributes (composition moved) —
  refresh the plan instead of patching a dead path.
- Product direction flips to a dark export panel — stop; that needs a new plan.
- Fix appears to require changing SwiftUI live panel colors to “match” —
  leave the live panel alone and report.

## Maintenance notes

- Any new export-panel secondary labels must use the same fixed tokens, never
  dynamic label colors, while the background stays light.
- Reviewers should fail PRs that reintroduce `labelColor` into
  `NotinhasNotesComposer` panel drawing.
