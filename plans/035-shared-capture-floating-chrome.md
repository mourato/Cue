# Plan 035: Extract shared capture floating HUD chrome (ungated)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1849b93a..HEAD -- Notinhas/Features/Recording/RecordingToolbarWindow.swift Notinhas/Features/Recording/Components/RecordingToolbarStyles.swift Notinhas/Features/Recording/Components/RecordingToolbarIconButton.swift Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureHUDWindow.swift Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureHUDView.swift NotinhasTests/Features/Recording/RecordingConfigurationTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt | direction
- **Planned at**: commit `1849b93a`, 2026-07-22

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — foundation for plans 036–037
- **Reviewer required**: `yes` — shared chrome must stay compilable with Video module off and on
- **Rationale**: Touches recording UI that is partly `#if NOTINHAS_VIDEO_MODULE` and partly always-compiled (`ToolbarConstants`). Wrong extraction breaks default builds or recording builds.
- **Escalate when**: Extraction appears to require rewriting `RecordingToolbarView` layout, or Xcode project membership cannot host new files without broader pbxproj surgery beyond adding the new sources to the Notinhas target.

## Why this matters

CleanShot-style All-In-One needs a floating capture HUD that works with the **default** Notinhas scheme (Video module off). Today the closest chrome lives behind `NOTINHAS_VIDEO_MODULE` (`RecordingToolbarWindow` / `ToolbarIconButton`), while scrolling capture duplicates a second HUD panel (`ScrollingCaptureHUDWindow`). Extracting placement + panel hosting + icon-button primitives into always-compiled capture chrome lets All-In-One and future capture HUDs reuse one path without depending on Recording.

## Current state

### What exists

- `Notinhas/Features/Recording/RecordingToolbarWindow.swift` — video-gated floating `NSPanel`; nested `RecordingToolbarPlacement.frameOrigin` (lines ~103–127) places the bar below a selection rect with clamp + inside-fallback.
- `Notinhas/Features/Recording/Components/RecordingToolbarStyles.swift` — `ToolbarConstants` and `RecordingToolbarDivider` are **outside** `#if NOTINHAS_VIDEO_MODULE`; button label styles are inside the gate.
- `Notinhas/Features/Recording/Components/RecordingToolbarIconButton.swift` — entire file wrapped in `#if NOTINHAS_VIDEO_MODULE`.
- `Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureHUDWindow.swift` — always-compiled floating HUD with its **own** positioning (`position(near:size:)` ~79–88), not shared with recording.
- `Notinhas/Features/Annotate/InlineAreaAnnotateWindow.swift` already references `ToolbarConstants` (so constants must remain available without Video module).
- Placement unit tests live under video module:
  `NotinhasTests/Features/Recording/RecordingConfigurationTests.swift` (`testRecordingToolbarPlacement_*`).

### Excerpts (planned-at)

```103:127:Notinhas/Features/Recording/RecordingToolbarWindow.swift
  enum RecordingToolbarPlacement {
    static let screenEdgeInset: CGFloat = 10
    static let outsideSelectionGap: CGFloat = 20
    static let insideSelectionBottomInset: CGFloat = 24

    static func frameOrigin(
      toolbarSize: CGSize,
      anchorRect rect: CGRect,
      screenFrame: CGRect
    ) -> CGPoint {
      let x = rect.midX - toolbarSize.width / 2
      // ... clamp X ...
      let belowSelectionY = rect.minY - toolbarSize.height - outsideSelectionGap
      let preferredY = belowSelectionY >= minY
        ? belowSelectionY
        : rect.minY + insideSelectionBottomInset
      // ... clamp Y ...
      return CGPoint(x: safeX, y: safeY)
    }
  }
```

```13:25:Notinhas/Features/Recording/Components/RecordingToolbarStyles.swift
enum ToolbarConstants {
  static let iconButtonSize: CGFloat = 32
  static let iconSize: CGFloat = 15
  static let buttonCornerRadius: CGFloat = 6
  static let toolbarCornerRadius: CGFloat = 14
  // ...
}
```

```1:8:Notinhas/Features/Recording/Components/RecordingToolbarIconButton.swift
#if NOTINHAS_VIDEO_MODULE
// ...
  struct ToolbarIconButton: View { ... }
#endif
```

### Conventions to match

- Swift 5.9, two-space indent, 120-col (`.swiftformat`).
- Capture platform adapters live under `Notinhas/Services/Capture/`; keep All-In-One feature UI later under `Notinhas/Features/Capture/` (plan 037).
- Do **not** put All-In-One behind `NOTINHAS_VIDEO_MODULE`.
- Product intent (`AGENTS.md`): prioritize capture → annotate → export; optional Video remains gated.

### Exemplar for floating HUD hosting

Mirror `ScrollingCaptureHUDWindow`: borderless nonactivating `NSPanel`, `.popUpMenu` level, clear background, SwiftUI via `NSHostingView`, `canBecomeKey/Main == false`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas/Services/Capture/FloatingToolbar Notinhas/Features/Recording/Components/RecordingToolbarStyles.swift Notinhas/Features/Recording/RecordingToolbarWindow.swift NotinhasTests/Services/Capture` | exit 0 |
| Default tests (placement) | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests` | all pass |
| Default build smoke | `./scripts/build_and_run.sh --no-video-module` (or Xcode build Notinhas Debug) | build succeeds |
| Video-module placement still OK | `./scripts/run-tests.sh --video-module --skip-visual -only-testing:NotinhasTests/RecordingConfigurationTests` | placement tests still pass (or skip if renamed — see Step 4) |

## Suggested executor toolkit

- `.agents/skills/macos-app-engineering/SKILL.md` — NSPanel / SwiftUI hosting
- `.agents/skills/swift-conventions/SKILL.md` — naming / format
- `.agents/skills/testing-xctest/SKILL.md` — XCTest layout under `NotinhasTests/Services/Capture/`
- `.agents/skills/delivery-workflow/SKILL.md` — build/test scripts

## Scope

**In scope** (create/modify only these):

- **Create** `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingToolbarPlacement.swift`
- **Create** `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingHUDWindow.swift`
- **Create** `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingToolbarChrome.swift` (shared SwiftUI divider + icon button + material chrome helpers; **not** video-gated)
- **Create** `NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift`
- **Modify** `Notinhas/Features/Recording/RecordingToolbarWindow.swift` — `RecordingToolbarPlacement` becomes a thin forwarder to `CaptureFloatingToolbarPlacement` (keep type name for call sites/tests)
- **Modify** `Notinhas/Features/Recording/Components/RecordingToolbarStyles.swift` — only if needed to avoid duplicating constants; prefer leaving `ToolbarConstants` where it is and having Capture chrome **reuse** it
- **Modify** `Notinhas/Features/Recording/Components/RecordingToolbarIconButton.swift` — optionally re-export/wrap shared `CaptureFloatingToolbarIconButton` behind the existing `ToolbarIconButton` name **or** leave recording button as-is if shared chrome is a separate type (preferred: separate type; do not break recording)
- **Modify** Xcode project membership so new files compile in the default Notinhas target
- **Modify** `plans/README.md` status row for 035

**Out of scope**:

- All-In-One mode picker UI, shortcuts, menu items (plan 037)
- Area resize handles / aspect lock / last selection (plan 036)
- Rewriting `ScrollingCaptureHUDWindow` to use the new host (optional follow-up; do **not** do it here unless a one-line placement call is trivial — prefer leave scrolling alone)
- Changing recording audio/options/record button layout
- Timer capture mode
- Any Sparkle / About / snapzy surfaces

## Git workflow

- Branch: `advisor/035-shared-capture-floating-chrome`
- Commits: Conventional Commits, e.g. `refactor(capture): extract shared floating toolbar chrome`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add placement math (always compiled)

Create `CaptureFloatingToolbarPlacement` with the **same** constants and `frameOrigin(toolbarSize:anchorRect:screenFrame:)` algorithm currently in `RecordingToolbarPlacement`.

**Verify**: `swift -e` is unnecessary — proceed to tests in Step 3. File exists and builds when added to target.

### Step 2: Add `CaptureFloatingHUDWindow`

Implement a reusable `NSPanel` subclass that:

- Accepts SwiftUI `AnyView` / generic `Content: View` content
- Exposes `show(anchorRect:screen:)` / `updateAnchorRect(_:)` using `CaptureFloatingToolbarPlacement.frameOrigin`
- Uses `.popUpMenu` level, `.none` sharingType, clear opaque=false, theme appearance via `ThemeManager.shared.nsAppearance` (same idea as recording toolbar)
- Does **not** become key/main

Keep the API small — All-In-One (037) will host mode + action toolbars in this window (one or two instances).

**Verify**: Default-scheme compile includes the type (`nm` / build). Prefer building via Step 5.

### Step 3: Add shared SwiftUI chrome primitives

In `CaptureFloatingToolbarChrome.swift` (name OK to split if file grows):

- `CaptureFloatingToolbarIconButton` — hover + SF Symbol, modeled on `ToolbarIconButton` / `ToolbarIconButtonLabel`, but **without** `#if NOTINHAS_VIDEO_MODULE`
- `CaptureFloatingToolbarDivider` — same visual as `RecordingToolbarDivider`
- Optional `CaptureFloatingToolbarMaterialBackground` — `RoundedRectangle` + `.regularMaterial` / hud material + subtle stroke, matching scrolling HUD / recording bar feel

Reuse `ToolbarConstants` from `RecordingToolbarStyles.swift` (already ungated). Do **not** duplicate constant values.

**Verify**: types compile in default scheme.

### Step 4: Forward recording placement + add default-scheme tests

1. Change `RecordingToolbarPlacement.frameOrigin` (and constants if desired) to call `CaptureFloatingToolbarPlacement` so video-module behavior stays identical.
2. Add `CaptureFloatingToolbarPlacementTests` under `NotinhasTests/Services/Capture/` copying the three placement assertions from `RecordingConfigurationTests` (outside `#if`), so default `./scripts/run-tests.sh` covers them.

Keep the old video-module tests compiling (they can keep calling `RecordingToolbarPlacement`).

**Verify**:
```bash
./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests
```
→ all new tests pass.

### Step 5: Dual-module smoke

```bash
./scripts/build_and_run.sh --no-video-module
```
→ build succeeds (launch optional; cancel after build if script launches).

If available:
```bash
./scripts/run-tests.sh --video-module --skip-visual -only-testing:NotinhasTests/RecordingConfigurationTests
```
→ placement-related tests still pass.

### Step 6: Format + index

```bash
swiftformat Notinhas/Services/Capture/FloatingToolbar NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift
```
Update `plans/README.md` row 035 → DONE (or leave for orchestrator if instructed).

## Test plan

- New file: `NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift`
- Cases (mirror existing recording placement tests):
  - uses outside gap when below selection fits
  - uses inside bottom inset near screen bottom
  - clamps inside inset to visible screen
- Pattern: `NotinhasTests/Features/Recording/RecordingConfigurationTests.swift` (`testRecordingToolbarPlacement_*`)
- Verification command above must show N ≥ 3 passing tests.

## Done criteria

- [ ] `CaptureFloatingToolbarPlacement`, `CaptureFloatingHUDWindow`, and ungated icon/divider chrome exist under `Notinhas/Services/Capture/FloatingToolbar/`
- [ ] `RecordingToolbarPlacement` forwards to shared placement (no behavior change)
- [ ] `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests` passes
- [ ] Default scheme (no Video module) builds successfully with the new files
- [ ] No All-In-One feature UI, shortcuts, or selection-refinement logic introduced
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- Placement algorithm in `RecordingToolbarWindow` no longer matches the excerpt (drift).
- Making chrome shared requires pulling large recording-only dependencies into the default target.
- Xcode project file changes balloon beyond adding the new Swift sources to existing groups/targets.
- Default-scheme build fails because something still referenced only exists under `#if NOTINHAS_VIDEO_MODULE`.

## Maintenance notes

- Plan 037 will host All-In-One toolbars in `CaptureFloatingHUDWindow` — keep the host API stable.
- Plan 036 may show one or two HUDs anchored to the selection rect; placement must stay pure/static for easy testing.
- Reviewers: confirm Video-off builds still see `ToolbarConstants` / Inline Annotate unchanged.
- Deferred: migrating `ScrollingCaptureHUDWindow` onto `CaptureFloatingHUDWindow` (nice-to-have DRY, not required for All-In-One).
