# Plan 041: Remove rectangular backing from the All-In-One floating HUD

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report rather than improvising.
>
> **Drift check (run first)**: `git diff --stat 8fbb0455..HEAD -- Notinhas/Services/Capture/FloatingToolbar Notinhas/Features/Capture/AllInOne Notinhas/Features/Recording/Components/RecordingToolbarStyles.swift NotinhasTests/Services/Capture NotinhasTests/Features/Capture docs/CAPTURE.md`
> Compare the current host/material code with the excerpts below before editing.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/039-all-in-one-direct-mode-actions.md, plans/040-all-in-one-session-selection-lifecycle.md
- **Category**: bug | tech-debt
- **Planned at**: commit `8fbb0455`, 2026-07-22

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — the host and SwiftUI material must have one visual owner.
- **Reviewer required**: yes — rounded transparency failures are visual and can differ across appearance/accessibility settings.
- **Rationale**: The change is isolated to the floating host and chrome, but an incorrect AppKit layer can affect Recording/Scrolling users of the shared primitives.
- **Escalate when**: Fixing the corners requires changing screen capture compositing, changing the selection overlay, or touching unrelated window classes.

## Why this matters

The All-In-One HUD currently applies a material/background in two layers: an
AppKit `NSVisualEffectView` in the panel host and a SwiftUI material modifier
inside each toolbar. A clear, borderless panel should not expose a rectangular
material backing behind a rounded toolbar; the visible symptom is a white or
opaque rectangle at the corners. The fix must preserve floating placement,
shadow, accessibility settings, and the shared host's default-scheme and
Video-module compilation.

## Current state

- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingHUDWindow.swift` —
  borderless nonactivating `NSPanel`; `setContent(_:)` creates an
  `NSVisualEffectView` with `.hudWindow`, makes it layer-backed, applies a
  corner radius, embeds `NSHostingView`, and makes the effect view the panel's
  `contentView` (lines 28–61).
- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingToolbarChrome.swift` —
  `.captureFloatingToolbarMaterial()` applies a second `.ultraThinMaterial` or
  solid `windowBackgroundColor`, then clips the SwiftUI content to a rounded
  rectangle (lines 63–79).
- `AllInOneCaptureToolbarView` and `AllInOneActionToolbarView` both call
  `.captureFloatingToolbarMaterial()` on their roots, so the two logical HUD
  sections each receive the duplicated host/content background.
- `CaptureFloatingHUDWindow` intentionally uses `.popUpMenu` level, clear window
  background, all-spaces behavior, and a shadow (lines 101–112); keep those
  invariants.
- `CaptureFloatingToolbarPlacement` is already covered by pure geometry tests;
  do not replace its algorithm while fixing the corners.

The load-bearing current shape is:

```swift
// CaptureFloatingHUDWindow.swift:33-55
let effect = NSVisualEffectView()
effect.material = .hudWindow
effect.blendingMode = .behindWindow
effect.layer?.cornerRadius = ToolbarConstants.toolbarCornerRadius
effect.layer?.masksToBounds = true
effect.addSubview(hosting)
contentView = effect
```

```swift
// CaptureFloatingToolbarChrome.swift:66-71
content
  .background(reduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) :
    AnyShapeStyle(.ultraThinMaterial))
  .clipShape(RoundedRectangle(cornerRadius: ToolbarConstants.toolbarCornerRadius))
```

The design constraints are: use system material patterns, reuse
`ToolbarConstants`, respect Reduce Transparency and Reduce Motion, keep UI on
MainActor, and keep the host adapter thin. The default scheme compiles with
`NOTINHAS_VIDEO_MODULE` off; shared capture chrome must not be moved behind the
Recording gate.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `swiftformat Notinhas/Services/Capture/FloatingToolbar Notinhas/Features/Capture/AllInOne NotinhasTests/Services/Capture NotinhasTests/Features/Capture` | exit 0 |
| Placement tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests` | all pass using the repository's local signing override |
| Focused All-In-One tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests` | all pass using the repository's local signing override |
| Default build | `./scripts/build_and_run.sh --no-video-module` | builds and launches |
| Video build | `./scripts/run-tests.sh --video-module --skip-visual -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests` | shared host still compiles with Video enabled |

## Suggested executor toolkit

- `.agents/skills/macos-app-engineering/SKILL.md` — NSPanel/NSHostingView ownership.
- `.agents/skills/apple-design/SKILL.md` — material, contrast, and accessibility settings.
- `.agents/skills/testing-xctest/SKILL.md` — manual visual gate vs pure tests.
- `.agents/skills/delivery-workflow/SKILL.md` — build and capture verification.

## Scope

**In scope**:

- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingHUDWindow.swift`
- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingToolbarChrome.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureToolbarView.swift` only for the host/material contract
- `Notinhas/Features/Capture/AllInOne/AllInOneActionToolbarView.swift` only for the host/material contract
- `NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift`
- Create `NotinhasTests/Services/Capture/CaptureFloatingHUDWindowTests.swift` only if a deterministic host invariant can be asserted

**Out of scope**:

- Capture dispatch, selection lifecycle, `AreaSelectionController`, screen
  compositing, Recording toolbar layout, Scrolling capture behavior, or new
  design tokens.
- `scripts/run-tests.sh` — local signing support is already handled by the
  repository test runner; do not duplicate or revert that override.
- Replacing the placement algorithm or changing the capture rectangle.

## Git workflow

- Branch: `advisor/041-all-in-one-floating-hud-material`
- Use an atomic Conventional Commit, e.g. `fix(capture): remove opaque corners from floating HUD`.
- Do not push or open a PR unless explicitly instructed.

## Steps

### Step 1: Choose one material owner and keep the panel transparent

Make the AppKit host a transparent, borderless container and let the SwiftUI
toolbar root own its rounded material, or make AppKit the sole material owner
and remove the SwiftUI modifier from every hosted root. Prefer the first option
because both current All-In-One roots already use
`.captureFloatingToolbarMaterial()` and the shared host is an adapter.

If using the preferred option, set the panel/content background to clear,
embed the hosting view directly (or otherwise guarantee the effect view has no
rectangular visible fill), preserve fitting-size updates, and ensure the
hosting/content layer clips only to the toolbar's rounded shape. The four
corner pixels outside the rounded shape must remain transparent. Do not leave a
second `NSVisualEffectView` visible underneath the SwiftUI material.

Keep `.popUpMenu`/`.screenSaver` elevation behavior, `canBecomeKey == false`,
all-spaces collection behavior, shadow, theme appearance, and content-size
refresh behavior unchanged.

**Verify**: `rg -n "NSVisualEffectView|hudWindow|captureFloatingToolbarMaterial|backgroundColor|isOpaque" Notinhas/Services/Capture/FloatingToolbar Notinhas/Features/Capture/AllInOne` → exactly one active visible material owner per hosted toolbar and a clear panel background.

### Step 2: Harden the shared SwiftUI chrome for accessibility settings

Keep the existing `.ultraThinMaterial`/solid fallback behavior for Reduce
Transparency, but add the smallest necessary border or contrast treatment so
the rounded surface and selected mode remain legible without relying on a blue
outline. Reuse `ToolbarConstants.toolbarCornerRadius`; do not introduce a new
radius or a white fill. Preserve Reduce Motion behavior in existing hover and
selection animations.

Ensure both All-In-One logical sections use the same background contract. If
the implementation retains two floating panels, each must have transparent
corners independently; do not add a rectangular parent view behind them.

**Verify**: `swiftformat Notinhas/Services/Capture/FloatingToolbar Notinhas/Features/Capture/AllInOne` → exit 0; `rg -n "Color\\.white|windowBackgroundColor|ultraThinMaterial|hudWindow" Notinhas/Services/Capture/FloatingToolbar Notinhas/Features/Capture/AllInOne` → any remaining solid fallback is explicitly guarded by Reduce Transparency and no unconditional white background exists.

### Step 3: Add only deterministic host/geometry regression coverage

Keep placement tests focused on coordinate math. If the host exposes a stable
test seam, add a MainActor test that constructs a HUD, installs a simple
SwiftUI root, and asserts the panel is non-opaque, has a clear window
background, and preserves non-key behavior. Do not assert pixel colors in
XCTest; AppKit material rendering is environment-dependent. Do not add tests
that require Screen Recording permission.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests -only-testing:NotinhasTests/CaptureFloatingHUDWindowTests` → all selected tests pass, or omit the optional host test if no stable seam exists and record that manual coverage is the gate.

### Step 4: Perform the visual/manual capture gate

With Screen Recording permission granted, launch the default Video-off build
and trigger All-In-One with a valid last selection. Check all of the following
on both light and dark desktop content:

1. No white/opaque rectangle is visible behind any rounded HUD corner.
2. The toolbar shadow is outside the rounded surface, not a second white panel.
3. Mode labels/icons and selected state remain legible over bright and dark
   backgrounds.
4. Reduce Transparency produces a solid system window-colored rounded surface
   with no corner artifact; Reduce Motion does not leave the HUD half-animated.
5. Moving/resizing the selection keeps the HUD attached and does not expose a
   stale rectangular backing.

Repeat one smoke check with the Video module enabled to ensure the shared host
still compiles and Recording's existing toolbar is not visually regressed.

**Verify**: `./scripts/build_and_run.sh --no-video-module` → app launches; record the manual results and any screenshot path in the executor handoff.

## Test plan

- Pure placement regression remains in `CaptureFloatingToolbarPlacementTests`.
- Optional host invariant test is MainActor and asserts only stable AppKit
  properties, not material pixels.
- Manual visual coverage is mandatory for corner transparency and accessibility
  settings because the repository testing guidance treats real floating panels
  as visual/manual surfaces.

## Done criteria

- [ ] The panel has no unconditional opaque/white rectangular backing.
- [ ] Each hosted toolbar has one material owner and rounded clipping.
- [ ] Placement, shadow, all-spaces, non-key, and content sizing behavior remain intact.
- [ ] Reduce Transparency and Reduce Motion paths are preserved and manually checked.
- [ ] Default and Video-on compilation gates pass where signing permits.
- [ ] Manual light/dark corner checks are recorded.
- [ ] No files outside the scope list are modified.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

- Removing the AppKit material reveals that the hosted SwiftUI root is not
  clipped at all four corners; stop and report the rendered hierarchy instead
  of adding a white mask.
- A visual fix requires changing `AreaSelectionWindow`, screen capture output,
  or the global toolbar constants used by Recording.
- The host cannot stay nonactivating/non-key without changing capture focus or
  permission behavior.
- The same corner artifact appears after one focused correction attempt; stop
  and attach the manual reproduction details for a follow-up.

## Maintenance notes

Future floating capture surfaces should reuse this one-owner material contract.
Reviewers should reject nested opaque backgrounds and rectangular AppKit masks
under rounded SwiftUI content. Any later decision to combine the two logical
All-In-One panels into one window should be a separate layout plan, not hidden
inside a corner fix.
