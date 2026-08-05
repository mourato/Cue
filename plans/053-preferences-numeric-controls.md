# Plan 053: Standardize Preferences numeric controls with stepped sliders and discrete alternatives

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat df0302d9..HEAD -- Notinhas/Shared/Components/SteppedSliderControl.swift Notinhas/Shared/Extensions/Binding+Stepped.swift Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift Notinhas/Features/Preferences/Components/PreferencesQuickAccessSettingsView.swift Notinhas/Features/Preferences/Components/PreferencesHistorySettingsView.swift Notinhas/Features/Preferences/Components/PreferencesAdvancedSettingsView.swift NotinhasTests/Shared/Components/SteppedSliderControlTests.swift`
> If an in-scope file changed since this plan was written, compare the current
> state below against the live code before proceeding. On a load-bearing
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: none; Plan 034's shared `SteppedSliderControl` is already shipped
- **Category**: tech-debt / usability
- **Planned at**: commit `df0302d9`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — one shared control API and three Preferences panes must stay consistent
- **Reviewer required**: `yes` — this changes a high-traffic settings surface, numeric semantics, and VoiceOver affordances
- **Rationale**: The work is bounded but requires a shared SwiftUI control API, `CGFloat`/`Double` binding compatibility, deliberate per-setting control selection, localization/accessibility review, tests, and a manual Preferences pass.
- **Escalate when**: A proposed API requires changing persisted preference types/ranges, changing defaults, altering configuration import/export, or adopting the control in Annotate/VideoEditor/Recording in the same change.

## Why this matters

Preferences currently contain 13 direct `Slider` call sites. They all snap to a
step, but most do not expose a direct `−/+` nudge affordance and several hide
the exact value inside the row description. This makes precise keyboard,
trackpad, and VoiceOver adjustment harder than necessary, while also treating
small finite choice sets and special values such as `0 = forever` as if they
were continuous measurements.

The outcome of this plan is a small, coherent family of controls: a reusable
stepped slider with an exact value and `−/+` buttons where a slider communicates
the range; native `Stepper`/numeric entry where exact discrete values matter;
and existing `Picker` controls where the setting is a small finite choice set.
Do not force every numeric preference into the slider variant.

## Current state

### Repository and verification conventions

- This is a Swift 5.9 macOS SwiftUI/AppKit app. Preferences are under
  `Notinhas/Features/Preferences/Components/` and use `SettingRow` for icon,
  title, description, and trailing content (`PreferencesSettingRow.swift:10-44`).
- Shared controls live under `Notinhas/Shared/Components/`; pure helper tests
  live under `NotinhasTests/Shared/Components/`.
- The canonical default-scheme verification is
  `./scripts/run-tests.sh --skip-visual`; use `./scripts/build_and_run.sh
  --no-video-module` for the default Debug build. Run `swiftformat` only on
  changed Swift paths.
- `docs/PREFERENCES.md` is the source of the user-facing preference inventory;
  preserve its existing ranges and meanings. History documents explicitly say
  `history.retentionDays` uses `0 = forever` and `history.maxCount` uses
  `0 = unlimited` (`docs/PREFERENCES.md:88-93`, `docs/HISTORY.md:53-59`).

### Existing shared control

`Notinhas/Shared/Components/SteppedSliderControl.swift:10-72` already renders
`[minus] [Slider] [plus]`, disables the buttons at the range ends, reuses
`SteppedValue.nudge`, forwards `onEditingChanged`, and uses
`L10n.Common.decrease` / `L10n.Common.increase`. It currently accepts only
`Binding<CGFloat>` and has no slot for an exact value label or endpoint labels.

`Notinhas/Shared/Extensions/Binding+Stepped.swift:11-57` supplies snapping and
clamping for `CGFloat`, `Double`, and `Float`; the helper and the binding use
the existing zero-anchored rounding semantics. Do not silently change ranges,
defaults, or persisted storage while generalizing the view.

### All Preferences slider cases

The following are the complete 13 `Slider` call sites under Preferences at the
planned commit:

| Setting | Current evidence | Current range / step | Recommended control |
|---|---|---:|---|
| Mouse highlight size | `PreferencesCaptureSettingsView.swift:525-532` | 30–100 / 2 | Stepped slider + visible value + `−/+`; the value is a measured size and benefits from live preview/dragging. |
| Mouse highlight animation duration | `PreferencesCaptureSettingsView.swift:534-543` | 0.3–2.0 s / 0.1 | Stepped slider + visible value + `−/+`; keep one-decimal formatting. |
| Mouse highlight opacity | `PreferencesCaptureSettingsView.swift:569-576` | 20–100% / 5% | Stepped slider + visible percentage + `−/+`; opacity is a classic bounded slider. |
| Keystroke font size | `PreferencesCaptureSettingsView.swift:590-599` | 12–32 pt / 1 | Stepped slider + visible value + `−/+`; size has a useful low/high direction. |
| Keystroke display duration | `PreferencesCaptureSettingsView.swift:616-625` | 0.5–5.0 s / 0.5 | Stepped slider + visible value + `−/+`; keep one-decimal formatting. |
| Quick Access overlay size | `PreferencesQuickAccessSettingsView.swift:38-54` | 0.75–1.5 / 0.25 (4 values) | Replace slider with a small explicit choice control, preferably a menu/segmented set labeled 75%, 100%, 125%, 150%. The current `S`/`L` endpoints hide the selected value. |
| Quick Access corner button size | `PreferencesQuickAccessSettingsView.swift:56-77` | 0.75–1.75 / 0.25 (5 values) | Same explicit choice control as overlay size; preserve all five existing values and expose the exact selected scale. |
| Quick Access auto-dismiss delay | `PreferencesQuickAccessSettingsView.swift:121-142` | 3–30 s / 1 | Stepped slider + current seconds value + `−/+`; the range is long enough for a slider but exact nudging matters. |
| Quick Access swipe sensitivity | `PreferencesQuickAccessSettingsView.swift:173-187` | 0.5–3.0 / 0.25 (11 values) | Stepped slider + current multiplier/percentage + `−/+`; retain the current percentage display. |
| History panel size | `PreferencesHistorySettingsView.swift:78-101` | 0.8–1.4 / 0.05 | Stepped slider + small/large endpoint labels + exact percentage + `−/+`; this is the strongest slider case in History. |
| Max displayed History items | `PreferencesHistorySettingsView.swift:103-120` | 3–20 / 1 | Stepper-only with an exact integer value; this is a count, not a perceptual continuum, and the range is small. |
| History retention days | `PreferencesHistorySettingsView.swift:123-141` | 0–90 days / 1; 0 = forever | Numeric field + bounded Stepper, or an explicit retention menu only if product intentionally narrows the allowed choices. Do not represent `∞` as an ordinary slider value without an explicit accessible label. |
| Max stored History items | `PreferencesHistorySettingsView.swift:143-160` | 0–1000 / 50; 0 = unlimited | Numeric field + bounded Stepper with an explicit “Unlimited” presentation for zero; a slider may remain as a secondary coarse control only if testing shows it is useful. |

The existing `PreferencesAdvancedSettingsView.swift:142-163` log-retention row
is the native Stepper exemplar: current value text beside a bounded Stepper.
The existing `PreferencesCaptureSettingsView.swift:545-558` ripple-count
`Picker` is the finite-choice exemplar and should remain a Picker.

### Explicitly out of this plan

- Do not change preference keys, defaults, ranges, persistence, configuration
  import/export, cleanup behavior, or runtime managers.
- Do not adopt the control in Annotate, Notinhas editor, VideoEditor, or the
  Recording waveform. Plan 034 deliberately established the shared control in
  Annotate/Notinhas while deferring Preferences/VideoEditor; this plan is the
  Preferences follow-up only.
- Do not replace native `Picker`, `Toggle`, `ColorPicker`, or existing Advanced
  `Stepper` rows unless the table above explicitly names the row.
- Do not add a generic “numeric settings mega-component” with product-specific
  descriptions, persistence, or formatting hidden inside it. Callers own
  labels, units, descriptions, and special-value presentation.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift | `git diff --stat df0302d9..HEAD -- <paths listed above>` | Empty output or only reviewed, unrelated drift |
| Format check | `swiftformat --lint Notinhas/Shared/Components/SteppedSliderControl.swift Notinhas/Shared/Extensions/Binding+Stepped.swift Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift Notinhas/Features/Preferences/Components/PreferencesQuickAccessSettingsView.swift Notinhas/Features/Preferences/Components/PreferencesHistorySettingsView.swift NotinhasTests/Shared/Components/SteppedSliderControlTests.swift` | exit 0 |
| Focused tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/SteppedSliderControlTests` | exit 0; all focused tests pass |
| Default tests | `./scripts/run-tests.sh --skip-visual` | exit 0; no new failures |
| Default build | `./scripts/build_and_run.sh --no-video-module` | Debug build succeeds and launches |
| Diff hygiene | `git diff --check` | exit 0 |

## Scope

**In scope** (only these files should be modified):

- `Notinhas/Shared/Components/SteppedSliderControl.swift`
- `Notinhas/Shared/Extensions/Binding+Stepped.swift` only if the shared
  generic/value helper needs a safe extension
- `NotinhasTests/Shared/Components/SteppedSliderControlTests.swift`
- `Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift`
- `Notinhas/Features/Preferences/Components/PreferencesQuickAccessSettingsView.swift`
- `Notinhas/Features/Preferences/Components/PreferencesHistorySettingsView.swift`
- `Notinhas/Features/Preferences/Components/PreferencesAdvancedSettingsView.swift`
  only if a small shared numeric-control presentation is adopted there

**Out of scope**:

- All files under `Notinhas/Features/Annotate/`, `Notinhas/Features/VideoEditor/`,
  and `Notinhas/Features/Recording/`
- `PreferencesKeys`, managers, services, importers, exporters, and docs unless
  a user-facing string is genuinely required and the operator expands scope
- New persisted settings or range/default changes
- Replacing the system `Stepper` with custom AppKit buttons

## Steps

### Step 1: Characterize the control semantics before changing layout

Add or extend pure tests in `SteppedSliderControlTests.swift` for every math
path the shared control will use: mid-range nudge, lower/upper clamping,
fractional steps, off-step snapping, disabled-at-boundary behavior, and the
`Double` path used by Preferences. If the implementation stays generic, test
the generic helper without duplicating the same assertions for each concrete
type. Preserve the current zero-anchored snapping behavior unless a failing
test proves it is inconsistent with an existing range.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/SteppedSliderControlTests` → exit 0 before changing call sites.

### Step 2: Generalize `SteppedSliderControl` without hiding caller semantics

Make the shared control work with the `Double` bindings used by Preferences as
well as the existing `CGFloat` callers. Prefer one generic SwiftUI view over
duplicated view bodies; if Swift 5.9 type inference makes a generic API
unreliable, add a small type-safe overload or adapter rather than `AnyView` or
stringly typed values.

Retain the current `−/+` behavior, clamping, `onEditingChanged` bracketing,
28pt button hit area, `.borderless` style, `.small` control size, and localized
`L10n.Common.decrease` / `increase` labels. Add caller-owned affordances needed
by Preferences, such as an optional trailing value view or a documented
composition pattern; do not embed units or product-specific formatting in the
shared component. Ensure the slider itself exposes a meaningful accessibility
value and the buttons remain separately focusable.

**Verify**: focused tests pass, `swiftformat --lint` on the changed shared files passes, and the default Debug build compiles with `./scripts/build_and_run.sh --no-video-module`.

### Step 3: Convert the scalar Preferences rows to the stepped slider variant

Adopt the shared control for the five Capture rows, Quick Access auto-dismiss
and swipe sensitivity, and History panel size. Preserve each existing binding,
range, step, reset behavior, description, and formatting. Add an exact current
value beside the control where it is currently only encoded in the description;
use monospaced digits for changing numeric labels. Preserve small/large endpoint
labels for History panel size and replace ambiguous endpoint-only presentation
with an exact value where necessary.

Use the component with `sliderWidth` values that fit the existing `SettingRow`
layout. Do not shrink `−/+` hit targets below the existing 28pt frame to make
the row fit; adjust spacing or the slider track width instead.

**Verify**: `rg -n '\bSlider\s*\(' Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift Notinhas/Features/Preferences/Components/PreferencesQuickAccessSettingsView.swift Notinhas/Features/Preferences/Components/PreferencesHistorySettingsView.swift` shows no direct slider for the seven converted scalar rows, and focused tests/build pass.

### Step 4: Replace small finite choices with explicit controls

Replace Quick Access overlay size and corner-button size sliders with explicit
finite choice controls. Keep their existing `Double` bindings and range
sources. The overlay offers 75%, 100%, 125%, and 150%; the corner-button
control must preserve its existing 75%, 100%, 125%, 150%, and 175% values.
Each option must expose its exact scale rather than only `S`/`L`.
Prefer the project’s existing menu-picker style unless the live Preferences
window has enough width for a clearly labeled segmented control.

Leave mouse-highlight ripple count as its existing 1–5 `Picker`; it is already
the correct discrete control and is a useful consistency reference.

**Verify**: the two scale rows no longer contain `Slider`; their selected value
is visible and the focused Preferences build passes.

### Step 5: Give count/retention settings precise discrete editing

Replace History max displayed items with the native bounded `Stepper` pattern
used by Advanced log retention, showing the current integer value.

For History retention days and max stored items, use a numeric entry + bounded
Stepper composition if it fits the current grouped form. The presentation must
make the special zero semantics explicit and accessible: “Forever” for
retention and “Unlimited” for max count, while preserving the stored integer
`0`. If the current macOS SwiftUI text-field/stepper composition cannot enforce
the existing bounds and special labels without validation regressions, stop and
report rather than falling back to a less precise slider. Do not silently change
the allowed increments or defaults.

**Verify**: focused Preferences tests/build pass; manually confirm typing,
increment/decrement, lower/upper bounds, zero special values, and reopening
Preferences preserve the existing stored values.

### Step 6: Accessibility, localization, and visual validation

Reuse existing common increase/decrease accessibility strings. Add localized
strings only if the new visible “Forever” / “Unlimited” or unit labels cannot
reuse existing localized copy; follow the repository localization pattern and
do not hardcode new user-facing English in a view.

Manually inspect Capture, Quick Access, History, and Advanced Preferences with
the optional Video module off and on where applicable. Verify the rows remain
aligned, values remain readable at minimum/maximum, disabled buttons are
communicated, VoiceOver can reach the slider/value/`−`/`+` or Stepper/text field
individually, and keyboard focus can make precise changes.

**Verify**: `git diff --check`, focused tests, and the full `--skip-visual`
suite pass; record any required real-window/manual gate in the handoff.

## Test plan

- Extend `NotinhasTests/Shared/Components/SteppedSliderControlTests.swift`
  using its existing pure-helper style. Cover scalar nudge/clamp/snap math for
  both existing `CGFloat` callers and Preferences `Double` callers, including
  fractional steps and exact endpoints.
- If the plan introduces pure formatting/binding helpers for `Forever` or
  `Unlimited`, test them in the same shared test file or a focused Preferences
  test file, covering zero, lower bound, upper bound, and ordinary values.
- Do not add brittle pixel snapshots. The row layout and accessibility behavior
  require a real Preferences-window smoke pass.
- Run `./scripts/run-tests.sh --skip-visual` after focused tests; do not enable
  the optional Video module unless the changed code is compiled by that target.

## Done criteria

- [ ] All 13 Preferences slider call sites have an explicit disposition:
  converted to the shared stepped slider, replaced by a Stepper/numeric
  control, or replaced by an explicit finite-choice Picker.
- [ ] Scalar stepped sliders expose exact current values and localized,
  separately focusable `−/+` buttons with correct endpoint disabling.
- [ ] Quick Access scale settings expose exact finite choices instead of only
  `S`/`L` endpoint labels.
- [ ] History counts and retention values preserve existing ranges, defaults,
  persisted keys, and `0` special semantics while allowing precise editing.
- [ ] `SteppedSliderControlTests` covers the shared math for Preferences value
  types and passes.
- [ ] `./scripts/run-tests.sh --skip-visual` exits 0.
- [ ] `./scripts/build_and_run.sh --no-video-module` builds successfully.
- [ ] `git diff --check` exits 0 and no out-of-scope files are modified.
- [ ] Manual Preferences and VoiceOver smoke checks pass or are explicitly
  recorded as environment-blocked.
- [ ] `plans/README.md` status row is updated by the executor/reviewer.

## STOP conditions

Stop and report instead of improvising if:

- A current range/default/key or configuration import/export contract differs
  from the excerpts above.
- Generalizing the shared control would require changing existing Annotate or
  Notinhas call-site behavior, duplicating a second divergent component, or
  weakening the current `onEditingChanged`/undo contract.
- The Quick Access scale controls require a new product value set; preserve the
  current overlay and corner-button values and stop rather than narrowing them.
- A numeric field cannot preserve the `0 = forever` / `0 = unlimited` semantics,
  bounds, localization, or accessibility without custom behavior outside this
  scope.
- The Preferences window clips, overflows, or makes `−/+` targets smaller than
  28pt; do not solve this by hiding values or removing the buttons.
- A test/build failure cannot be distinguished from a pre-existing failure.
- The implementation starts touching VideoEditor, Annotate, Recording,
  persistence, configuration migration, or unrelated Preferences controls.

## Maintenance note

Future numeric Preferences should choose a control based on semantics before
copying a slider row: continuous/perceptual bounded values use the stepped
slider variant; small finite sets use a Picker; exact discrete counts and wide
ranges use numeric entry plus Stepper. Callers remain responsible for units,
formatting, special values, and live descriptions. Any future reuse in
Annotate/VideoEditor must preserve their separate interaction and undo
contracts and should be planned as a distinct adoption round.
