# Plan 079: Extract a native-material FeedbackSurface

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report — do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer dispatched you and told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 205939ae..HEAD -- Notinhas/Services/Diagnostics/AppToastManager.swift Notinhas/Features/Capture/OCRLinkPromptManager.swift NotinhasTests/Services/Diagnostics`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `205939ae`, 2026-07-29

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — this establishes the shared component that later feedback work should use.
- **Reviewer required**: `yes` — this changes floating feedback chrome used across capture, annotate, history, and preferences.
- **Rationale**: The scope is localized but visual regressions are easy: material, contrast, sizing, and dark/light behavior must be checked together.
- **Escalate when**: the change requires modifying capture HUD, recording HUD, or history floating panel hosts; those are out of scope for this plan.

## Why this matters

Notinhas currently has at least two nearly identical feedback surfaces: the global toast and the OCR link prompt. The app also hardcodes toast background/text/border colors inside `AppToastStyle`, which makes future design-system changes harder and encourages parallel one-off surfaces. This plan extracts the visual shell into a reusable native macOS `FeedbackSurface` that can support non-interactive toasts now and clickable prompts in the next plan.

Use native macOS material for the first item: `FeedbackSurface` should use an `NSVisualEffectView` with `.hudWindow` as its default material, matching existing floating HUD direction in the app. Do not keep the toast as a purely RGB-filled rounded rectangle. Add a tokenized solid fallback for Reduce Transparency / higher contrast conditions so readability remains deterministic.

## Current state

- `Notinhas/Services/Diagnostics/AppToastManager.swift` — owns toast style, presenter, measurement, SwiftUI view, icon, and spinner in one file.
- `Notinhas/Features/Capture/OCRLinkPromptManager.swift` — separate clickable prompt that visually repeats the toast chrome and reuses `AppToastStyle.info` colors.
- `Notinhas/Features/Annotate/InlineAreaAnnotateWindow.swift` — existing native material reference for floating annotate HUD chrome.
- `Notinhas/Features/History/Managers/HistoryFloatingPanelController.swift` — existing material/solid fallback precedent for a floating panel.

Relevant current excerpts:

```swift
// Notinhas/Services/Diagnostics/AppToastManager.swift:12
enum AppToastStyle: Equatable {
  case info
  case success
  case warning
  case error

  var iconName: String { ... }
  var iconGradientColors: [Color] { ... }
  var backgroundColor: NSColor { ... }
  var borderColor: NSColor { ... }
  var textColor: NSColor { ... }
}
```

```swift
// Notinhas/Services/Diagnostics/AppToastManager.swift:423
.background(
  RoundedRectangle(cornerRadius: presentation.variant.cornerRadius, style: .continuous)
    .fill(Color(nsColor: presentation.style.backgroundColor))
)
.overlay(
  RoundedRectangle(cornerRadius: presentation.variant.cornerRadius, style: .continuous)
    .stroke(Color(nsColor: presentation.style.borderColor), lineWidth: 0.5)
)
```

```swift
// Notinhas/Features/Capture/OCRLinkPromptManager.swift:193
.background(
  RoundedRectangle(cornerRadius: 10, style: .continuous)
    .fill(Color(nsColor: AppToastStyle.info.backgroundColor))
)
.overlay(
  RoundedRectangle(cornerRadius: 10, style: .continuous)
    .stroke(Color(nsColor: AppToastStyle.info.borderColor), lineWidth: 0.5)
)
```

```swift
// Notinhas/Features/Annotate/InlineAreaAnnotateWindow.swift:1310
private func configure(_ view: NSVisualEffectView) {
  view.material = .hudWindow
  view.state = .active
  view.blendingMode = .withinWindow
  view.wantsLayer = true
  view.layer?.cornerRadius = cornerRadius
  view.layer?.cornerCurve = .continuous
  view.layer?.masksToBounds = true
}
```

Repo conventions to follow:

- SwiftUI/AppKit UI stays on the main actor when it owns windows or panels.
- Use `// MARK:` in large files.
- Use two-space Swift formatting and run `swiftformat` on touched Swift files.
- Match existing native material precedent: `NSVisualEffectView`, `.hudWindow`, `.active`, continuous corner curves, and transparent `NSHostingView` backgrounds.
- Do not reintroduce removed Snapzy features or broaden product scope.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `swiftformat Notinhas/Services/Diagnostics NotinhasTests/Services/Diagnostics` | exit 0 |
| Focused tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Diagnostics/FeedbackSurfaceTests --skip-visual` | exit 0; new diagnostics tests pass |
| Build | `./scripts/run-tests.sh --skip-visual` | exit 0, unless only documented pre-existing UI/environment failures appear |

## Suggested executor toolkit

- Use `apple-design` for native material, appearance, motion, and contrast choices.
- Use `accessibility-audit` before finalizing any reduced-transparency or contrast behavior.
- Use `swift-conventions` when extracting new Swift types.

## Scope

**In scope**:

- `Notinhas/Services/Diagnostics/AppToastManager.swift`
- New files under `Notinhas/Services/Diagnostics/` for shared feedback UI, for example:
  - `FeedbackSurface.swift`
  - `FeedbackStyle.swift`
  - `FeedbackIconView.swift`
- New tests under `NotinhasTests/Services/Diagnostics/`, for example:
  - `FeedbackSurfaceTests.swift`

**Out of scope**:

- Do not modify `OCRLinkPromptManager` beyond compile fixes required by moved type names. Full adoption belongs to plan 080.
- Do not change `QuickAccessIconButton`, `PreferencesCloudUploadHistoryView`, or status bar processing feedback. Plan 081 owns local microfeedback alignment.
- Do not change capture, recording, history, or annotate HUD material implementations.
- Do not change user-facing strings in this plan.

## Git workflow

- Branch: `advisor/079-feedback-surface-native-material`
- Commit style: Conventional Commits, for example `refactor(ui): extract feedback surface chrome`
- Do not push or open a PR unless the operator explicitly instructs it.

## Steps

### Step 1: Split feedback semantics from AppToastStyle colors

Create a small semantic style layer under `Notinhas/Services/Diagnostics/`:

- Keep the existing public call-site concept of `AppToastStyle` for compatibility if possible.
- Move display decisions into a new type such as `FeedbackTone` / `FeedbackStyle` / `FeedbackTokens`.
- Provide tokens for:
  - `iconName`
  - `iconColor`
  - `textColor`
  - `borderColor`
  - `solidBackgroundColor`
  - `materialOverlayTint`
- Prefer solid semantic icon colors over the current always-gradient icon treatment. If a subtle gradient is retained, it must be token-owned and optional, not hardcoded inside the icon view.

**Verify**: `rg -n "backgroundColor|borderColor|textColor|iconGradientColors" Notinhas/Services/Diagnostics/AppToastManager.swift` → no display-token ownership remains in `AppToastManager`; compatibility shims are allowed only if they delegate to the new token type.

### Step 2: Add FeedbackMaterialBackground

Add a SwiftUI/AppKit bridge for native material, modeled after `InlineAreaHudMaterialBackground` but owned by Diagnostics:

- Use `NSVisualEffectView`.
- Default material: `.hudWindow`.
- State: `.active`.
- Blending mode: `.withinWindow` when used as a SwiftUI background inside the panel content.
- Apply `cornerRadius`, `.continuous` corner curve, and `masksToBounds`.
- Make the SwiftUI hosting view transparent so the material is visible.
- Provide an explicit solid/tinted fallback path driven by SwiftUI environment values:
  - `accessibilityReduceTransparency`
  - `accessibilityContrast`
  - `colorScheme`

Target shape:

```swift
struct FeedbackMaterialBackground: NSViewRepresentable {
  let cornerRadius: CGFloat
  let material: NSVisualEffectView.Material

  func makeNSView(context: Context) -> NSVisualEffectView { ... }
  func updateNSView(_ nsView: NSVisualEffectView, context: Context) { ... }
}
```

**Verify**: `rg -n "NSVisualEffectView|\\.hudWindow|accessibilityReduceTransparency|accessibilityContrast" Notinhas/Services/Diagnostics` → all four concepts are present in the new feedback surface implementation.

### Step 3: Extract FeedbackSurface and reuse it from AppToastView

Create `FeedbackSurface<Content: View>` or a non-generic `FeedbackSurface` that accepts content via closure. It should own:

- corner radius
- material background
- solid fallback
- border
- shadow
- padding only if the API is for complete surface content; otherwise keep padding in the toast row

Update `AppToastView` to render its icon and text inside this surface. Preserve:

- `AppToastManager.show(...)` signature
- `AppToastManager.update(...)` signature
- `AppToastHandle`
- default duration behavior
- bottom/top center positioning behavior

**Verify**: `rg -n "AppToastManager\\.shared\\.show" Notinhas` → no call sites require source changes for the plan to compile.

### Step 4: Add token and sizing tests

Add focused tests that do not require WindowServer screenshots:

- every feedback tone has a non-empty SF Symbol name
- every variant has positive dimensions/padding
- regular and compact variants keep distinct min heights
- solid fallback colors are available for light and dark appearances if exposed through pure helpers
- `AppToastManager` measurement remains bounded by the same max-width rule if the measurement helper is made testable

Prefer pure tests against extracted token/metric helpers. Do not instantiate `NSPanel` in unit tests unless an existing diagnostics test pattern already does so safely.

**Verify**: `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Diagnostics/FeedbackSurfaceTests --skip-visual` → exits 0.

### Step 5: Format and run a broader compile gate

Run the formatter and a non-visual test/build gate.

**Verify**:

- `swiftformat Notinhas/Services/Diagnostics NotinhasTests/Services/Diagnostics` → exits 0
- `./scripts/run-tests.sh --skip-visual` → exits 0, unless only documented pre-existing UI/environment failures appear

## Test plan

- New `FeedbackSurfaceTests` in `NotinhasTests/Services/Diagnostics/`.
- Test pure tokens and metrics, not live panel display.
- Existing call sites remain covered by compile/build because `AppToastManager` API must not change.

## Done criteria

- [ ] `FeedbackSurface` exists under `Notinhas/Services/Diagnostics/`.
- [ ] `FeedbackSurface` uses native macOS `.hudWindow` material by default.
- [ ] A solid fallback exists for reduced transparency / contrast-sensitive contexts.
- [ ] `AppToastManager.show` and `update` call signatures are unchanged.
- [ ] `AppToastView` no longer owns its own rounded-rectangle background/border directly.
- [ ] Focused diagnostics tests pass.
- [ ] `swiftformat` has run on touched Swift files.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

Stop and report back if:

- Material rendering requires changing existing capture/recording/history HUD hosts.
- `FeedbackSurface` cannot compile without making `AppToastManager.show` call sites change.
- The solid fallback cannot be expressed without hardcoding unrelated global app colors.
- Unit tests need live display permissions or Screen Recording to pass.

## Maintenance notes

Future feedback components should use `FeedbackSurface` instead of copying rounded-rectangle chrome. Reviewers should check that `FeedbackSurface` remains visual-only: do not let it absorb panel lifecycle, toast duration, OCR link behavior, or Quick Access business logic.
