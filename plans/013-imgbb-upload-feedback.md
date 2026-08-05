# Plan 013: Give the ImgBB upload a visible feedback lifecycle (progress → success/error) with sound

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 0370153..HEAD -- Snapzy/Features/Annotate/Components/AnnotateBottomBarView.swift Snapzy/Features/Notinhas/NotinhasL10n.swift Snapzy/Shared/Localization/L10n.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (shares `AnnotateBottomBarView.swift` with plan 014)
- **Category**: bug (UX feedback gap)
- **Planned at**: commit `0370153`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — independent of plans 015 and 016; shares a file with 014 (coordinate on `annotateActionButtons` if same agent).
- **Reviewer required**: `no` — small, well-scoped UI change with manual verification gates.
- **Rationale**: Single method rewrite plus a few localization strings, reusing existing app infrastructure (`AppToastManager`, `SoundManager`). Deterministic scope.
- **Escalate when**: the change starts requiring modifications to `NotinhasUploadCoordinator` or `NotinhasImgBBUploadService` beyond reading `lastErrorMessage` — that means the design drifted; reclassify to `implementer`.

> **Numbering note**: This plan was originally drafted as "001" then renumbered to
> 013 to avoid colliding with the pre-existing plans in this directory. References
> to "002/003/004" in an earlier draft now mean 014/015/016.

## Why this matters

Today, after an ImgBB upload from the Annotate window, a successful upload is
completely silent: the link is copied to the clipboard but the user gets no
confirmation that the upload succeeded or that the URL is now on the clipboard.
Failures use a blocking `.alert`, which is inconsistent with the rest of the app
(capture, OCR, cloud upload all use the non-blocking `AppToastManager` toast).
This is the exact gap that motivated this work. Cloud upload already plays a
"Pop" sound and shows a "Uploaded to Cloud and copied link" toast — ImgBB should
match that quality bar.

## Current state

- `Snapzy/Features/Annotate/Components/AnnotateBottomBarView.swift` — owns the
  Annotate bottom bar and the ImgBB button + upload handler.
  - The ImgBB error is currently surfaced via SwiftUI `.alert` bound to
    `imgbbUploadError` (lines ~104-111) and via `@State private var imgbbUploadError` / `lastImgBBURL` (lines ~53-54).
  - The upload handler, `handleImgBBUpload()` (lines ~538-565):

```538:565:Snapzy/Features/Annotate/Components/AnnotateBottomBarView.swift
  private func handleImgBBUpload() {
    guard let apiKey = NotinhasImgBBConfiguration.apiKey else {
      imgbbUploadError = NotinhasL10n.imgbbMissingAPIKey
      return
    }
    guard let renderedImage = AnnotateExporter.renderFinalImage(state: state) else {
      imgbbUploadError = NotinhasL10n.imgbbInvalidImageData
      return
    }

    isImgBBUploading = true
    Task { @MainActor in
      defer { isImgBBUploading = false }
      let link = await imgbbUploadCoordinator.upload(
        finalImage: renderedImage,
        maxDimension: 2048,
        apiKey: apiKey
      )
      if let link {
        lastImgBBURL = link
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(link, forType: .string)
      } else {
        imgbbUploadError = imgbbUploadCoordinator.lastErrorMessage ?? NotinhasL10n.imgbbUploadFailed
      }
    }
  }
```

- The reusable toast infrastructure lives in
  `Snapzy/Services/Diagnostics/AppToastManager.swift`:
  - `AppToastManager.shared.show(message:style:position:duration:variant:iconMode:) -> AppToastHandle?`
  - `AppToastManager.shared.update(_:message:style:position:duration:variant:iconMode:)`
  - `AppToastManager.shared.dismiss(_:)`
  - Styles: `.info`, `.success`, `.warning`, `.error`. Icon modes: `.symbol`, `.spinner`. Default position `.bottomCenter`, default duration `2.5`.
- The precedent for exactly this pattern is the History cloud upload, which
  shows a spinner-free success toast + sound:

```355:377:Snapzy/Features/History/Managers/HistoryFloatingManager.swift
        SoundManager.play("Pop")
        AppToastManager.shared.show(
          message: L10n.PreferencesHistory.uploadedToCloudAndCopiedLink,
```

  And `AnnotateState` shows an in-progress → resolved toast lifecycle using a
  retained handle (model this pattern):

```1781:1878:Snapzy/Features/Annotate/AnnotateState.swift
    sensitiveRedactionToast = AppToastManager.shared.show(
      message: L10n.AnnotateUI.autoRedactionScanning,
      ...
      AppToastManager.shared.update(
        toast,
        message: message,
```

- `SoundManager.play(_ name: String)` is a static, sound-preference-aware call:
  `Snapzy/Shared/Services/SoundManager.swift:38`.
- Localization convention: strings live in `Snapzy/Shared/Localization/L10n.swift`
  inside `enum Notinhas` (starts around line 2993), each declared with the
  `string("annotate.notinhas.<slug>", defaultValue: ..., comment: ...)` helper,
  and re-exported through `Snapzy/Features/Notinhas/NotinhasL10n.swift`.

## Commands you will need

| Purpose        | Command                        | Expected on success |
|----------------|--------------------------------|---------------------|
| Format         | `./scripts/format.sh`          | exit 0              |
| Build + run    | `./scripts/build_and_run.sh`   | app builds and launches |
| Tests          | `./scripts/run-tests.sh`       | build + test suite pass |

(Exact commands from `AGENTS.md` / `scripts/`. There is no separate lint step.)

## Suggested executor toolkit

- Read `.agents/skills/capture-annotate-export/SKILL.md` (owns the ImgBB upload
  UX) and `.agents/skills/apple-design/SKILL.md` (toast/motion feel) before
  editing.

## Scope

**In scope** (the only files you should modify):
- `Snapzy/Features/Annotate/Components/AnnotateBottomBarView.swift`
- `Snapzy/Shared/Localization/L10n.swift` (append two strings inside `enum Notinhas`)
- `Snapzy/Features/Notinhas/NotinhasL10n.swift` (re-export the two new strings)

**Out of scope** (do NOT touch, even though they look related):
- `NotinhasUploadCoordinator.swift` / `NotinhasImgBBUploadService.swift` — the
  networking and error mapping already work and are unit-tested; only read
  `imgbbUploadCoordinator.lastErrorMessage`.
- The cloud upload path (`handleCloudUpload()`) and its progress bar — leave
  untouched.
- The missing-API-key gating of the button — that is plan 014. In this plan,
  keep the existing `guard let apiKey ... imgbbUploadError = ...` behavior for
  the missing-key case, but route it through the toast instead of the alert
  (see Step 3), so the two plans do not fight over behavior.

## Git workflow

- Branch: `advisor/013-imgbb-upload-feedback`
- Commit style: Conventional Commits (repo uses e.g. `feat(notinhas): ...`,
  `fix: copy annotation to clipboard`). Suggested message:
  `feat(notinhas): show ImgBB upload progress and success/error feedback`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the two new localization strings

In `Snapzy/Shared/Localization/L10n.swift`, inside `enum Notinhas` (near the
other `imgbb*` entries around lines 3015-3023), append:

```swift
static let imgbbUploading = string(
  "annotate.notinhas.imgbb-uploading",
  defaultValue: "Uploading to ImgBB…",
  comment: "Progress toast shown while an image uploads to ImgBB"
)
static let imgbbUploadedAndCopied = string(
  "annotate.notinhas.imgbb-uploaded-and-copied",
  defaultValue: "Uploaded to ImgBB and copied link",
  comment: "Success toast shown after an ImgBB upload copies the link to the clipboard"
)
```

In `Snapzy/Features/Notinhas/NotinhasL10n.swift`, add the matching re-exports
next to the existing `uploadToImgBB` / `imgbbUploadFailed` lines:

```swift
static let imgbbUploading = L10n.Notinhas.imgbbUploading
static let imgbbUploadedAndCopied = L10n.Notinhas.imgbbUploadedAndCopied
```

**Verify**: `./scripts/build_and_run.sh` → project compiles (you may close the
app after it launches).

### Step 2: Rewrite `handleImgBBUpload()` to drive a toast lifecycle + sound

Replace the body of `handleImgBBUpload()` so that:

1. On the missing-key / invalid-image guards, show an **error toast** instead of
   setting `imgbbUploadError` (see Step 3 for why the alert is going away).
2. Immediately before starting the async upload, show a **spinner progress
   toast** with no auto-dismiss (`duration: nil`) and retain its handle.
3. On success: `update(...)` the retained handle to a `.success` toast with
   `L10n.Notinhas.imgbbUploadedAndCopied` (default 2.5s duration) AND call
   `SoundManager.play("Pop")`, after copying the link to the clipboard.
4. On failure: `update(...)` the retained handle to an `.error` toast carrying
   `imgbbUploadCoordinator.lastErrorMessage ?? NotinhasL10n.imgbbUploadFailed`.

Target shape (adapt names to match surrounding code; keep it `@MainActor`):

```swift
private func handleImgBBUpload() {
  guard let apiKey = NotinhasImgBBConfiguration.apiKey else {
    AppToastManager.shared.show(message: NotinhasL10n.imgbbMissingAPIKey, style: .warning)
    return
  }
  guard let renderedImage = AnnotateExporter.renderFinalImage(state: state) else {
    AppToastManager.shared.show(message: NotinhasL10n.imgbbInvalidImageData, style: .error)
    return
  }

  isImgBBUploading = true
  let progressToast = AppToastManager.shared.show(
    message: NotinhasL10n.imgbbUploading,
    style: .info,
    duration: nil,
    iconMode: .spinner
  )

  Task { @MainActor in
    defer { isImgBBUploading = false }
    let link = await imgbbUploadCoordinator.upload(
      finalImage: renderedImage,
      maxDimension: 2048,
      apiKey: apiKey
    )
    if let link {
      lastImgBBURL = link
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(link, forType: .string)
      SoundManager.play("Pop")
      if let progressToast {
        AppToastManager.shared.update(progressToast, message: NotinhasL10n.imgbbUploadedAndCopied, style: .success)
      } else {
        AppToastManager.shared.show(message: NotinhasL10n.imgbbUploadedAndCopied, style: .success)
      }
    } else {
      let message = imgbbUploadCoordinator.lastErrorMessage ?? NotinhasL10n.imgbbUploadFailed
      if let progressToast {
        AppToastManager.shared.update(progressToast, message: message, style: .error)
      } else {
        AppToastManager.shared.show(message: message, style: .error)
      }
    }
  }
}
```

Note: `AppToastManager.update` only applies while the handle is still the active
presentation; the `else` branch (fresh `show`) is a safety net if the progress
toast was superseded. Keep both branches.

**Verify**: `./scripts/build_and_run.sh` → compiles and launches.

### Step 3: Remove the now-unused ImgBB error alert

The blocking `.alert` bound to `imgbbUploadError` is replaced by toasts. Remove
the alert modifier and its backing state:

- Delete the `.alert(NotinhasL10n.imgbbUploadFailed, isPresented: ...)` block
  (lines ~104-111).
- Delete `@State private var imgbbUploadError: String?` (line ~53).
- Keep `@State private var lastImgBBURL: String?` if it is still assigned in
  Step 2 (it is — used to remember the copied link). If the compiler warns it is
  unused otherwise, leave the assignment as in Step 2 so the warning does not
  appear.

**Verify**: `./scripts/build_and_run.sh` → compiles with no `imgbbUploadError`
references remaining. Then:
`rg -n "imgbbUploadError" Snapzy/` → **no matches**.

### Step 4: Format

Run `./scripts/format.sh`.

**Verify**: `./scripts/format.sh` → exit 0; `git diff` shows only two-space
indentation consistent with the file.

## Test plan

- No new unit test is required or practical: the changed logic lives in a
  SwiftUI view and drives `NSPasteboard` (process-global) and `AppToastManager`
  (NSPanel presentation), which the repo already treats as manual/CI-skipped
  (see `AnnotateExportSaveTests.swift:157-167`). Do NOT add a flaky pasteboard
  or toast test.
- The existing `SnapzyTests/Features/Notinhas/NotinhasImgBBUploadServiceTests`
  must remain green (you are not touching the service).
- **Manual verification (required — this is the acceptance gate)**:
  1. Ensure an ImgBB API key is set (Preferences → Annotate → ImgBB API Key).
  2. Capture an area, add at least one Notinhas note, click the ImgBB upload
     button (cloud-arrow icon, tooltip "Upload to ImgBB").
  3. Confirm: a spinner "Uploading to ImgBB…" toast appears, then flips to a
     green "Uploaded to ImgBB and copied link" success toast, a "Pop" sound
     plays, and the link is on the clipboard (paste to check).
  4. Temporarily use an invalid key and repeat: the spinner toast flips to a red
     error toast with the failure message; no blocking alert appears.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `./scripts/build_and_run.sh` builds and launches (exit 0 on build)
- [ ] `./scripts/run-tests.sh` passes (no regressions)
- [ ] `rg -n "imgbbUploadError" Snapzy/` returns no matches
- [ ] `rg -n "imgbbUploadedAndCopied|imgbbUploading" Snapzy/` returns the new string definitions + usages
- [ ] `./scripts/format.sh` exits 0
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row for 013 updated
- [ ] Manual verification above performed and passing

## STOP conditions

Stop and report back (do not improvise) if:

- `handleImgBBUpload()` no longer matches the "Current state" excerpt (the file
  drifted since `0370153`).
- Removing the alert reveals that `imgbbUploadError` is referenced somewhere
  else you were told is out of scope.
- The `AppToastManager.update` API signature differs from the one in
  "Current state" (someone changed the toast manager).
- A verification command fails twice after a reasonable fix attempt.

## Maintenance notes

- If plan 014 (missing-key button guard) also lands, the missing-key `guard` in
  Step 2 becomes mostly unreachable (button disabled) but should stay as a
  defensive fallback.
- A reviewer should confirm the toast is not shown behind the Annotate window
  (`AppToastManager` uses a `.statusBar`-level panel, so it floats above — no
  action needed, just verify visually).
- If a future change adds real byte-level upload progress, the single
  spinner→result toast can be upgraded to a determinate progress indicator; the
  handle-based lifecycle already supports `update`.
