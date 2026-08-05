# Plan 014: Disable the ImgBB button when no API key is configured, with an explanatory tooltip

> **Numbering note**: Originally drafted as "002" then renumbered to 014 to avoid
> colliding with the pre-existing plans in this directory. References to
> "001/003/004" in an earlier draft now mean 013/015/016.

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 0370153..HEAD -- Snapzy/Features/Annotate/Components/AnnotateBottomBarView.swift`
> If the file changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a
> STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (coordinate with 013 if the same agent edits `annotateActionButtons`)
- **Category**: bug (UX feedback gap)
- **Planned at**: commit `0370153`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — independent of 015 and 016.
- **Reviewer required**: `no`.
- **Rationale**: One button declaration gains a computed `disabled`/`opacity`/tooltip, mirroring an existing pattern in the same file. No new APIs.
- **Escalate when**: the maintainer instead wants an interactive "Open Settings" affordance (see Maintenance notes) — that is a larger change and should be reclassified to `implementer`.

## Why this matters

The ImgBB upload button in the Annotate bottom bar is always enabled, even when
no ImgBB API key is configured. Clicking it in that state does nothing visible
except surface an error. Every other conditional action in this bar communicates
availability up front: the cloud button is only shown when cloud is configured,
and the background-cutout button disables itself with an explanatory tooltip when
unavailable. Bringing ImgBB in line removes a dead-click and tells the user
exactly what to do (add a key in Settings) before they click.

## Current state

- `Snapzy/Features/Annotate/Components/AnnotateBottomBarView.swift` — the ImgBB
  button is declared inside `annotateActionButtons`, always enabled except while
  uploading:

```390:396:Snapzy/Features/Annotate/Components/AnnotateBottomBarView.swift
      BottomBarButton(
        icon: isImgBBUploading ? "hourglass" : "icloud.and.arrow.up",
        tooltip: NotinhasL10n.uploadToImgBB
      ) {
        handleImgBBUpload()
      }
      .disabled(isImgBBUploading)
```

- The established "disabled + explanatory tooltip" pattern in the SAME file is
  the background-cutout button:

```139:158:Snapzy/Features/Annotate/Components/AnnotateBottomBarView.swift
  private var backgroundCutoutButton: some View {
    ...
    .disabled(!state.canUseBackgroundCutout || !state.hasImage || state.isCutoutProcessing)
    .opacity((!state.canUseBackgroundCutout || !state.hasImage) ? 0.4 : 1)
    .help(...)
  }
```

  (Note: `backgroundCutoutButton` actually lives in `AnnotateToolbarView.swift`;
  the equivalent enabled/disabled + opacity pattern in the bottom bar is the
  cloud button at lines ~403-419 and the trash button at lines ~439-443. Use the
  trash button's `.disabled(...).opacity(...)` shape as the local model.)

- Key availability is a pure computed check:
  `NotinhasImgBBConfiguration.apiKey` returns `String?` — `nil` when neither the
  UserDefaults key `notinhas.imgbb.apiKey` nor the `IMGBB_API_KEY` Info.plist
  value is set (`Snapzy/Features/Notinhas/Services/NotinhasImgBBConfiguration.swift:7-19`).
- The ImgBB key is configured in Preferences → **Annotate** tab
  (`PreferencesAnnotateSettingsView.swift:97`, `PreferencesTab.annotate` in
  `Snapzy/Features/Preferences/Models/PreferencesNavigationState.swift:13`).
- An existing string already reads as a perfect tooltip for the disabled state:
  `L10n.Notinhas.imgbbMissingAPIKey` = "Add an ImgBB API Key in Settings before
  uploading." (`L10n.swift:3018`), re-exported as `NotinhasL10n.imgbbMissingAPIKey`.

## Commands you will need

| Purpose        | Command                        | Expected on success |
|----------------|--------------------------------|---------------------|
| Format         | `./scripts/format.sh`          | exit 0              |
| Build + run    | `./scripts/build_and_run.sh`   | app builds and launches |
| Tests          | `./scripts/run-tests.sh`       | build + test suite pass |

## Scope

**In scope** (the only files you should modify):
- `Snapzy/Features/Annotate/Components/AnnotateBottomBarView.swift`

**Out of scope** (do NOT touch):
- The upload handler `handleImgBBUpload()` — that is plan 013. If 013 already
  landed, leave its missing-key fallback intact; if 013 has not landed, do not
  change the handler here.
- Any Preferences view. This plan does NOT add a settings deeplink (see
  Maintenance notes for why the toast route was rejected).
- `NotinhasImgBBConfiguration` — read-only.

## Git workflow

- Branch: `advisor/014-imgbb-missing-api-key-guard`
- Commit style: Conventional Commits. Suggested:
  `feat(notinhas): disable ImgBB upload until an API key is set`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add a computed availability flag

Near the other private computed properties used by `annotateActionButtons` (for
example just above `annotateActionButtons` or beside `tooltipText`), add:

```swift
private var isImgBBConfigured: Bool {
  NotinhasImgBBConfiguration.apiKey != nil
}
```

`NotinhasImgBBConfiguration.apiKey` is a `static var` that reads current
UserDefaults each call, so this re-evaluates on each view update — a key added in
Settings takes effect without relaunch when the view next renders.

### Step 2: Gate the ImgBB button

Update the ImgBB `BottomBarButton` (lines ~390-396) to disable + dim + swap the
tooltip when unconfigured, mirroring the trash button's shape:

```swift
BottomBarButton(
  icon: isImgBBUploading ? "hourglass" : "icloud.and.arrow.up",
  tooltip: isImgBBConfigured ? NotinhasL10n.uploadToImgBB : NotinhasL10n.imgbbMissingAPIKey
) {
  handleImgBBUpload()
}
.disabled(isImgBBUploading || !isImgBBConfigured)
.opacity(isImgBBConfigured ? 1 : 0.5)
```

**Verify**: `./scripts/build_and_run.sh` → compiles and launches.

### Step 3: Format

Run `./scripts/format.sh`.

## Test plan

- No unit test is practical (SwiftUI view state + UserDefaults-backed static).
  Do not add one.
- **Manual verification (acceptance gate)**:
  1. With NO ImgBB API key set, open an Annotate window: the ImgBB button is
     dimmed and disabled; hovering shows "Add an ImgBB API Key in Settings before
     uploading."
  2. Set a key in Preferences → Annotate → ImgBB API Key, return to the Annotate
     window (or open a new one): the button is enabled and its tooltip reads
     "Upload to ImgBB".

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `./scripts/build_and_run.sh` builds and launches
- [ ] `./scripts/run-tests.sh` passes (no regressions)
- [ ] `rg -n "isImgBBConfigured" Snapzy/Features/Annotate/Components/AnnotateBottomBarView.swift` shows the flag defined and used in both `.disabled` and the tooltip
- [ ] `./scripts/format.sh` exits 0
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row for 014 updated
- [ ] Manual verification above performed and passing

## STOP conditions

Stop and report back (do not improvise) if:

- The ImgBB `BottomBarButton` no longer matches the "Current state" excerpt.
- `NotinhasImgBBConfiguration.apiKey` is no longer a `String?` static.
- A verification command fails twice after a reasonable fix attempt.

## Maintenance notes

- **Why not an "Open Settings" button on the error?** The app's toast presenter
  (`AppToastManager`) uses `ignoresMouseEvents = true`, so toasts cannot carry an
  interactive action. Proactively disabling the button + a directive tooltip is
  the lowest-risk way to both prevent the dead-click and tell the user where to
  go. If the maintainer later wants a one-click jump to Settings, the hook exists
  — `AppStatusBarController.shared.openPreferencesWindow(tab: .annotate)` — and
  could be wired into an NSAlert with an "Open Settings" button; that is a
  deliberately separate, larger change.
- A reviewer should confirm the button re-enables after a key is added when a new
  Annotate window opens (the static re-reads UserDefaults each render).
