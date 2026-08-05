# Plan 081: Standardize feedback accessibility, motion, and local state tokens

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report — do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer dispatched you and told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 50735320152d70b18a05cd52ef2dae84a119d3f6..HEAD -- Notinhas/Services/Diagnostics Notinhas/Features/QuickAccess/Components/QuickAccessIconButton.swift Notinhas/Features/Preferences/Components/PreferencesCloudUploadHistoryView.swift Notinhas/Features/Capture/CaptureViewModel.swift Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift Notinhas/Features/Annotate/AnnotateState.swift`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.
>
> **Reconciled 2026-07-29**: Planned-at advanced from `205939ae` to `50735320152d70b18a05cd52ef2dae84a119d3f6` after plans 079–080. Spinner lives in `FeedbackIconView`; toast scale animation is in `AppToastView`. Motion/a11y/token steps below are unchanged.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/079-feedback-surface-native-material.md, plans/080-feedback-presenter-slots-and-ocr-prompt.md
- **Category**: tech-debt
- **Planned at**: commit `50735320152d70b18a05cd52ef2dae84a119d3f6`, 2026-07-29 (reconciled after 079–080)

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — this aligns multiple feedback call sites after the shared surface and slots exist.
- **Reviewer required**: `yes` — accessibility and motion behavior must be reviewed in context.
- **Rationale**: This is a polish and consistency pass across several surfaces; it is not difficult, but it is easy to overreach.
- **Escalate when**: the work requires changing user-facing copy beyond feedback text policy or modifying capture/annotate business logic.

## Why this matters

After plans 079 and 080, Notinhas will have a shared visual surface and placement model. The remaining risk is behavioral inconsistency: some feedback animates regardless of Reduce Motion, some local success states use raw colors, and toast call sites decide progress/success/error patterns independently. This plan aligns accessibility, motion, and local microfeedback tokens without forcing every feedback into a toast.

## Current state

- `AppToastManager` animates panel alpha and `AppToastView` scale without checking Reduce Motion.
- `AppToastSpinnerView` spins indefinitely without a reduced-motion alternative.
- `QuickAccessIconButton` owns raw hover/pressed colors and scale feedback.
- `PreferencesCloudUploadHistoryView` uses a local `copied` flag with raw green/white/red button colors.
- ImgBB and sensitive-redaction flows already use a good progress-handle pattern; OCR and some failure flows use one-off toast calls.

Relevant current excerpts:

```swift
// Notinhas/Services/Diagnostics/AppToastManager.swift (AppToastView, post-079)
.scaleEffect(appeared ? 1.0 : 0.96)
.onAppear {
  withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
    appeared = true
  }
}
```

```swift
// Notinhas/Services/Diagnostics/FeedbackIconView.swift (FeedbackSpinnerView)
.onAppear {
  guard !isSpinning else { return }
  withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
    isSpinning = true
  }
}
```

```swift
// Notinhas/Features/QuickAccess/Components/QuickAccessIconButton.swift:73
private var buttonBackgroundColor: Color {
  if !isEnabled {
    Color.black.opacity(0.4)
  } else if isPressed {
    Color.white.opacity(0.5)
  } else if isHovering {
    Color.white.opacity(0.35)
  } else {
    Color.black.opacity(0.6)
  }
}
```

```swift
// Notinhas/Features/Preferences/Components/PreferencesCloudUploadHistoryView.swift:899
gridActionButton(
  icon: copied ? "checkmark" : "doc.on.doc",
  color: copied ? .green : .white,
  action: copyLink
)
```

```swift
// Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift:561
let progressToast = AppToastManager.shared.show(
  message: NotinhasL10n.imgbbUploading,
  style: .info,
  duration: nil,
  iconMode: .spinner
)
...
AppToastManager.shared.update(progressToast, message: NotinhasL10n.imgbbUploadedAndCopied, style: .success)
```

Repo conventions to follow:

- Existing Quick Access code reads `@Environment(\.accessibilityReduceMotion)` and disables sound/motion in several places. Match that pattern.
- Existing floating panels use `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` where SwiftUI environment is unavailable.
- Keep microfeedback local when it is immediate button state; do not replace button press states with global toasts.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `swiftformat Notinhas/Services/Diagnostics Notinhas/Features/QuickAccess Notinhas/Features/Preferences NotinhasTests/Services/Diagnostics NotinhasTests/Features/QuickAccess` | exit 0 |
| Diagnostics tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Diagnostics/FeedbackAccessibilityTests --skip-visual` | exit 0; new tests pass |
| Quick Access tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Features/QuickAccess/QuickAccessCoreTests --skip-visual` | exit 0 |
| Broader gate | `./scripts/run-tests.sh --skip-visual` | exit 0, unless only documented pre-existing UI/environment failures appear |

## Suggested executor toolkit

- Use `accessibility-audit` for announcements, Reduce Motion, Reduce Transparency, focus, and contrast.
- Use `interface-design` for token hierarchy and avoiding one-off color choices.
- Use `ux-writing` only if you change user-visible feedback copy.

## Scope

**In scope**:

- `Notinhas/Services/Diagnostics/`
- `Notinhas/Features/QuickAccess/Components/QuickAccessIconButton.swift`
- `Notinhas/Features/Preferences/Components/PreferencesCloudUploadHistoryView.swift`
- Narrow feedback-call-site updates in:
  - `Notinhas/Features/Capture/CaptureViewModel.swift`
  - `Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift`
  - `Notinhas/Features/Annotate/AnnotateState.swift`
- New focused tests under `NotinhasTests/Services/Diagnostics/`

**Out of scope**:

- Do not rewrite Quick Access card layout.
- Do not alter OCR, ImgBB, cloud upload, or redaction business logic.
- Do not add user preferences for toast style/duration.
- Do not add Notification Center notifications.
- Do not change localization keys unless needed for a concrete accessibility label or announcement.

## Git workflow

- Branch: `advisor/081-feedback-accessibility-and-local-state-tokens`
- Commit style: Conventional Commits, for example `refactor(ui): align feedback accessibility and state tokens`
- Do not push or open a PR unless the operator explicitly instructs it.

## Steps

### Step 1: Add feedback motion policy helpers

In Diagnostics, add a small policy helper used by the feedback presenter/view:

- SwiftUI path: read `@Environment(\.accessibilityReduceMotion)`.
- AppKit manager path: read `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.
- When Reduce Motion is on:
  - keep fade acceptable but remove scale/spring motion
  - avoid repeated spinner rotation when a static progress symbol plus text is sufficient, or use a system `ProgressView` behavior that respects platform settings

Do not disable feedback entirely.

**Verify**: `rg -n "accessibilityReduceMotion|accessibilityDisplayShouldReduceMotion" Notinhas/Services/Diagnostics` → feedback code checks motion settings.

### Step 2: Add feedback accessibility announcement policy

Add a narrow announcement policy for toast updates:

- passive success/warning/error/info toasts should expose message text to accessibility
- progress start/update/end should not spam repeated announcements
- clickable OCR prompt remains a normal accessible interactive surface from plan 080

Use platform-appropriate APIs only if already available/imported safely in AppKit/SwiftUI. If the implementation cannot reliably announce without side effects, add accessibility labels/values to the hosted SwiftUI content and record announcement as deferred in the PR notes.

**Verify**: `rg -n "accessibilityLabel|accessibilityValue|announcement|NSAccessibility" Notinhas/Services/Diagnostics` → the toast view has explicit accessibility semantics or a documented announcement helper.

### Step 3: Tokenize local microfeedback without converting it to toast

Introduce or reuse feedback token helpers from plan 079 for local state colors:

- Quick Access button states:
  - disabled
  - default
  - hover
  - pressed
- Preferences upload-history action states:
  - default copy
  - copied success
  - destructive delete

Keep these states local. Do not show a global toast for every Quick Access press or hover.

Update:

- `QuickAccessIconButton.buttonBackgroundColor`
- `PreferencesCloudUploadHistoryView.gridActionButton` / copied icon color

**Verify**:

- `rg -n "Color\\.black\\.opacity\\(0\\.6\\)|Color\\.white\\.opacity\\(0\\.35\\)|copied \\? \\.green" Notinhas/Features/QuickAccess/Components/QuickAccessIconButton.swift Notinhas/Features/Preferences/Components/PreferencesCloudUploadHistoryView.swift` → no raw local feedback colors remain for these states.
- `rg -n "Feedback.*Token|Feedback.*State" Notinhas/Features/QuickAccess/Components/QuickAccessIconButton.swift Notinhas/Features/Preferences/Components/PreferencesCloudUploadHistoryView.swift Notinhas/Services/Diagnostics` → state tokens are used.

### Step 4: Standardize progress toast lifecycle at call sites

Keep the good handle-based pattern already present in ImgBB and sensitive redaction. Audit current call sites and update only cases with true progress lifecycle where the UI already indicates processing:

- If a flow starts a long operation and later emits success/error, use one handle and `update`.
- If a flow only emits a terminal warning/error, leave it as a simple toast.
- Do not add new progress toasts for very fast operations just for consistency.

Candidate call sites to inspect:

- OCR in `CaptureViewModel` currently sets status-bar processing and then may show success/warning/error.
- cutout failures in `CaptureViewModel` are terminal only and should likely remain simple toasts.
- ImgBB in `AnnotateBottomBarView` already follows the desired pattern.
- sensitive redaction in `AnnotateState` already follows the desired pattern.

**Verify**: `rg -n "duration: nil|iconMode: \\.spinner|AppStatusBarController\\.shared\\.setProcessing" Notinhas/Features/Capture Notinhas/Features/Annotate` → long-operation feedback decisions are intentional and documented in code comments only where needed.

### Step 5: Add focused tests for policies/tokens

Add `FeedbackAccessibilityTests` covering pure policy helpers:

- reduced motion chooses no scale animation
- normal motion allows the current short animation
- success/warning/error/info tones expose non-empty accessibility labels or message semantics
- local state tokens return distinguishable success/destructive/default colors if exposed as pure helpers

Do not require VoiceOver, Screen Recording, or live windows in unit tests.

**Verify**: `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Diagnostics/FeedbackAccessibilityTests --skip-visual` → exits 0.

### Step 6: Manual accessibility smoke

If the environment permits:

1. Turn on Reduce Motion and trigger a toast. Confirm it fades without scale/spring motion.
2. Turn on Reduce Transparency and trigger a toast. Confirm it uses a solid readable surface.
3. Trigger OCR link prompt. Confirm close and link buttons have meaningful accessibility labels and Escape/focus behavior remains predictable if implemented.
4. Trigger Quick Access copy/save buttons. Confirm local press feedback still exists but does not rely on color alone where a persistent state is communicated.

If these settings cannot be toggled in the environment, record the manual gate as pending.

**Verify**: manual checklist completed or explicitly marked pending due to environment.

## Test plan

- New `FeedbackAccessibilityTests` for pure policy helpers.
- Existing Quick Access tests for unchanged core behavior.
- Manual accessibility smoke for motion/transparency and OCR prompt interaction.

## Done criteria

- [ ] Feedback views respect Reduce Motion.
- [ ] Feedback surface respects Reduce Transparency / contrast-sensitive fallback from plan 079.
- [ ] Toast content has explicit accessibility semantics or a narrowly documented announcement policy.
- [ ] Quick Access and Preferences local feedback states use shared tokens or token helpers.
- [ ] Long-operation call sites use handle/update where appropriate and terminal-only call sites stay simple.
- [ ] Focused diagnostics tests pass.
- [ ] `swiftformat` has run on touched Swift files.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

Stop and report back if:

- Accessibility announcements require a broad app-wide notification system.
- Tokenizing local feedback would require moving Quick Access into Diagnostics.
- A progress lifecycle change requires altering OCR/ImgBB/redaction business logic.
- Reduced-transparency fallback conflicts with the material strategy from plan 079.

## Maintenance notes

Reviewers should keep the distinction between feedback categories: global toast for transient app feedback, clickable prompt for user action, status-bar spinner for process state, and local microfeedback for immediate control state. The design system should align their tokens and motion, not collapse all of them into one UI component.
