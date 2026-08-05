# Plan 080: Coordinate feedback slots and adopt FeedbackSurface in OCR links

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report — do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer dispatched you and told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat d7aa49ae..HEAD -- Notinhas/Services/Diagnostics Notinhas/Features/Capture/OCRLinkPromptManager.swift Notinhas/Features/Capture/CaptureViewModel.swift NotinhasTests/Services/Diagnostics`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.
>
> **Reconciled 2026-07-29**: Planned-at advanced from `205939ae` to `d7aa49ae` after plan 079 landed (`FeedbackSurface`, `FeedbackToastMetrics`). Slot/OCR adoption work below is unchanged; frame excerpts now match post-079 `AppToastManager`.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/079-feedback-surface-native-material.md
- **Category**: tech-debt
- **Planned at**: commit `d7aa49ae`, 2026-07-29 (reconciled after 079)

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — depends on the shared surface from plan 079 and touches overlapping feedback presentation code.
- **Reviewer required**: `yes` — this changes interactive OCR link prompt presentation and global feedback positioning.
- **Rationale**: The implementation is mostly extraction/adoption, but focus, click-through, and panel-level behavior must be preserved.
- **Escalate when**: stacking requires a generalized notification center or more than two simultaneous feedback slots.

## Why this matters

The OCR link prompt intentionally sits above the bottom-center toast by using a hardcoded 100pt bottom margin. That works for one pairing, but it is not a system: another feedback panel can still collide, and the OCR prompt duplicates the toast's visual shell. This plan introduces explicit feedback slots and moves OCR link prompt chrome onto the shared `FeedbackSurface`, while preserving its clickable behavior.

## Current state

- `Notinhas/Services/Diagnostics/AppToastManager.swift` — one global non-interactive toast panel, positioned at top-center or bottom-center.
- `Notinhas/Features/Capture/OCRLinkPromptManager.swift` — separate clickable panel with a hardcoded bottom margin to avoid overlapping the toast.
- `Notinhas/Features/Capture/CaptureViewModel.swift` — shows both the optional OCR success toast and the OCR link prompt from the same capture result.

Relevant current excerpts:

```swift
// Notinhas/Services/Diagnostics/AppToastManager.swift (post-079)
private func frameForToast(
  message: String,
  position: AppToastPosition,
  variant: AppToastVariant
) -> CGRect? {
  guard let screen = targetScreen() else { return nil }
  let visibleFrame = screen.visibleFrame
  let maxWidth = min(
    FeedbackToastMetrics.defaultMaxWidth,
    visibleFrame.width - FeedbackToastMetrics.screenHorizontalInset
  )
  let size = FeedbackToastMetrics.measuredToastSize(
    for: message,
    maxWidth: maxWidth,
    variant: variant
  )

  let x = visibleFrame.midX - size.width / 2
  let y: CGFloat = switch position {
  case .topCenter:
    visibleFrame.maxY - size.height - 36
  case .bottomCenter:
    visibleFrame.minY + 36
  }
  return CGRect(x: x, y: y, width: size.width, height: size.height)
}
```

```swift
// Notinhas/Features/Capture/OCRLinkPromptManager.swift:17
private static let autoDismissDelay: TimeInterval = 10
fileprivate static let panelWidth: CGFloat = 380
/// Sits above the bottom-center toast slot so a "Copied to Clipboard"
/// success toast and this prompt never overlap.
private static let bottomMargin: CGFloat = 100
```

```swift
// Notinhas/Features/Capture/OCRLinkPromptManager.swift:78
newPanel.ignoresMouseEvents = false
newPanel.becomesKeyOnlyIfNeeded = true
newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
```

```swift
// Notinhas/Features/Capture/CaptureViewModel.swift:2480
AppToastManager.shared.show(
  message: L10n.Common.copiedToClipboard,
  style: .success,
  position: .bottomCenter
)
...
OCRLinkPromptManager.shared.show(links: detectedLinks)
```

Repo conventions to follow:

- Keep managers that own `NSPanel` lifecycle on the main actor.
- Use nonactivating panels for transient floating feedback.
- Preserve `ignoresMouseEvents = true` for passive toasts and `false` for clickable prompts.
- Keep OCR link rows accessible and clickable; do not demote them to text inside a passive toast.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `swiftformat Notinhas/Services/Diagnostics Notinhas/Features/Capture NotinhasTests/Services/Diagnostics` | exit 0 |
| Focused tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Diagnostics/FeedbackPresenterTests --skip-visual` | exit 0; new presenter tests pass |
| OCR/link tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Media/OCRLinkDetectorTests --skip-visual` | exit 0 |
| Broader gate | `./scripts/run-tests.sh --skip-visual` | exit 0, unless only documented pre-existing UI/environment failures appear |

## Suggested executor toolkit

- Use `macos-app-engineering` for `NSPanel` lifecycle and nonactivating panel behavior.
- Use `accessibility-audit` for the clickable prompt focus/keyboard behavior.
- Use `swift-conventions` for the extraction.

## Scope

**In scope**:

- `Notinhas/Services/Diagnostics/`
- `Notinhas/Features/Capture/OCRLinkPromptManager.swift`
- `Notinhas/Features/Capture/CaptureViewModel.swift` only if call ordering or slot metadata needs minor adjustment
- `NotinhasTests/Services/Diagnostics/`

**Out of scope**:

- Do not change OCR recognition/link detection logic.
- Do not change `L10n.OCR.*` strings except for accessibility labels strictly required by this plan.
- Do not change status bar processing spinner.
- Do not change Quick Access card action visuals.
- Do not introduce a general-purpose notification queue with history, persistence, or user settings.

## Git workflow

- Branch: `advisor/080-feedback-presenter-slots-and-ocr-prompt`
- Commit style: Conventional Commits, for example `refactor(ui): coordinate feedback panel slots`
- Do not push or open a PR unless the operator explicitly instructs it.

## Steps

### Step 1: Extract frame/slot calculation into a pure helper

Create a pure helper in Diagnostics, for example `FeedbackPanelPlacement`, that calculates frames from:

- target screen visible frame
- panel size
- slot
- margin

Recommended slot model:

```swift
enum FeedbackPanelSlot: Equatable {
  case topCenter
  case bottomCenter
  case bottomCenterRaised
}
```

Initial margins should preserve current behavior:

- `topCenter`: 36pt below visible maxY
- `bottomCenter`: 36pt above visible minY
- `bottomCenterRaised`: enough to sit above a regular bottom toast; use the current OCR prompt 100pt bottom margin as the compatibility value unless tests justify a computed offset

Keep this helper pure so it can be unit-tested without creating panels.

**Verify**: `rg -n "FeedbackPanelSlot|bottomCenterRaised|visibleFrame" Notinhas/Services/Diagnostics` → slot helper exists and does not depend on `NSPanel`.

### Step 2: Move AppToastManager to the shared placement helper

Update `AppToastManager.frameForToast` to delegate to `FeedbackPanelPlacement`.

Preserve:

- `AppToastPosition.topCenter`
- `AppToastPosition.bottomCenter`
- target screen resolution from mouse location
- max width `min(560, visibleFrame.width - 32)`
- current measurement behavior unless plan 079 intentionally extracted metrics

**Verify**: `rg -n "visibleFrame\\.minY \\+ 36|visibleFrame\\.maxY - size\\.height - 36" Notinhas/Services/Diagnostics/AppToastManager.swift` → these formulas no longer live directly in `AppToastManager`.

### Step 3: Adopt FeedbackSurface in OCRLinkPromptView

Replace OCR prompt's duplicate rounded-rectangle background/border with the `FeedbackSurface` from plan 079. The prompt content remains custom:

- link icon
- title
- link row buttons
- close button
- hover pause

Preserve `panelWidth = 380`, auto-dismiss delay, clickable rows, close button, and hover pause behavior.

Use the same semantic tone as an info feedback surface. Avoid hardcoded `Color.cyan`, `Color.blue`, and direct `AppToastStyle.info.backgroundColor` access; use the new feedback tokens from plan 079.

**Verify**:

- `rg -n "AppToastStyle\\.info\\.backgroundColor|AppToastStyle\\.info\\.borderColor|LinearGradient\\(" Notinhas/Features/Capture/OCRLinkPromptManager.swift` → no matches for duplicated toast chrome or hardcoded icon gradient in the prompt.
- `rg -n "FeedbackSurface" Notinhas/Features/Capture/OCRLinkPromptManager.swift` → prompt uses the shared surface.

### Step 4: Replace OCR prompt hardcoded margin with slot placement

Update `OCRLinkPromptManager.show` to use `FeedbackPanelPlacement` with the raised bottom slot. Remove `bottomMargin` from `OCRLinkPromptManager` unless it becomes a private alias to the shared placement constant for compatibility.

Preserve:

- the prompt sits above a bottom-center toast
- it remains centered on the screen under the pointer
- it can join all spaces and full-screen auxiliary spaces

**Verify**: `rg -n "bottomMargin" Notinhas/Features/Capture/OCRLinkPromptManager.swift` → no hardcoded local bottom margin remains.

### Step 5: Add placement and prompt tests

Add `FeedbackPresenterTests` covering:

- bottom-center slot x/y for a known visible frame
- top-center slot x/y for a known visible frame
- raised bottom slot y is greater than bottom-center y by a stable amount
- a prompt-size frame remains within visible horizontal bounds

If `FeedbackSurface` exposes token helpers from plan 079, add a test that OCR prompt info tone uses those helpers rather than `AppToastStyle` color properties.

**Verify**: `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Diagnostics/FeedbackPresenterTests --skip-visual` → exits 0.

### Step 6: Manual smoke gate

Run the app and manually smoke the OCR case if the environment has Screen Recording permission:

1. Enable OCR success toast preference if needed.
2. Capture an area containing a URL.
3. Confirm "Copied to clipboard" toast appears bottom-center.
4. Confirm the link prompt appears above it and is clickable.
5. Confirm hovering the prompt pauses dismissal.
6. Confirm close button dismisses it.

If Screen Recording is unavailable, record this as a manual gate pending TCC rather than weakening the implementation.

**Verify**: `./scripts/build_and_run.sh --no-video-module` → app builds and launches, or report the exact environment blocker.

## Test plan

- New pure placement tests in `NotinhasTests/Services/Diagnostics/FeedbackPresenterTests.swift`.
- Existing `OCRLinkDetectorTests` remain unchanged; run them to ensure the link data model is not affected.
- Manual OCR prompt smoke test for visual overlap/clickability.

## Done criteria

- [ ] `AppToastManager` uses shared placement helpers.
- [ ] `OCRLinkPromptView` uses `FeedbackSurface`.
- [ ] OCR prompt no longer owns duplicated toast background/border colors.
- [ ] OCR prompt still accepts mouse input.
- [ ] Bottom toast and OCR prompt have coordinated slots instead of unrelated hardcoded margins.
- [ ] Focused diagnostics tests pass.
- [ ] `swiftformat` has run on touched Swift files.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

Stop and report back if:

- The shared presenter design requires converting the OCR prompt into a passive toast.
- The prompt can no longer receive mouse clicks without making the app active in a disruptive way.
- Slot coordination requires stacking more than two simultaneous panels.
- Manual smoke shows the prompt overlaps a toast after the shared slot migration.

## Maintenance notes

This plan should leave Notinhas with explicit feedback placement slots, not a fully general notification system. If a future feature needs multiple simultaneous feedback panels, extend `FeedbackPanelPlacement` deliberately instead of adding another local `bottomMargin`.
