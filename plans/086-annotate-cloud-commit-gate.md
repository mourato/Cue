# Plan 086: Block cloud re-upload after a failed local commit

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. This plan changes only the cloud-overwrite
> preflight; Save, Copy, and close timing remain owned by their existing paths.
> When done, update the status row for this plan in `plans/README.md` unless a
> reviewer dispatched you and told you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat f67a3ab9..HEAD -- Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift Notinhas/Features/Annotate/Services/AnnotateExporter.swift NotinhasTests/Features/Annotate/AnnotateExportSaveTests.swift`
> The exporter and test file are read-only dependencies in this plan. If the
> controller excerpts below do not match, stop before editing.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: MED
- **Depends on**: [Plan 085](085-annotate-local-commit-tail.md)
- **Category**: bug
- **Planned at**: commit `f67a3ab9`, 2026-08-11

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — both cloud-overwrite methods live in the same
  controller and must preserve their different clipboard fallbacks.
- **Reviewer required**: yes — a wrong guard can upload stale pixels or delete
  the previous cloud object.
- **Rationale**: The code change is small, but it protects a user-data and
  cloud-state invariant at a MainActor/AppKit boundary. No new abstraction or
  provider test harness is justified.
- **Escalate when**: The fix requires changing `CloudManager`, adding cloud
  dependency injection, changing upload/delete ordering after a successful
  local write, or touching credentials/provider implementations.

## Why this matters

The two cloud overwrite flows attempt the local rendered-file write, but they
continue into upload even when rendering or writing returned `false`. Because
`CloudManager.upload(fileURL:)` reads the source URL, this can upload the old
on-disk image while the UI later publishes a new cloud URL, deletes the old
object, marks the edit saved, and closes. A failed local commit must leave the
window open and prevent upload, old-object deletion, cloud-state mutation,
clipboard replacement, and close.

## Current state

The app is a Swift 6.2 macOS AppKit/SwiftUI application with strict
concurrency. `AnnotateWindowController` owns the Annotate window and the
cloud-overwrite action; `AnnotateExporter` owns the local rendered-file write;
`CloudManager` owns provider operations. Keep those owners separate.

Relevant current code:

- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:1309-1326`
  renders the Save overwrite, writes only inside an `if`, then captures
  `oldCloudKey` and starts upload regardless of the write result.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:1403-1421`
  repeats the same pre-upload gap for Copy.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:1340-1357`
  uploads, schedules deletion of the old key, mutates cloud state, and marks
  the edit saved; these effects must remain unreachable after local failure.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:1474-1490`
  intentionally has a different fallback after a *cloud* upload failure:
  Copy puts the rendered image on the clipboard and closes. Do not apply that
  fallback to a local-write failure.
- `Notinhas/Features/Annotate/Services/AnnotateExporter.swift:79-94`
  returns `false` when the image/source is unavailable or the atomic write
  throws. `saveToFile` does not throw an error for the controller to catch.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:1155-1163`
  already owns the localized `NSAlert` used for a Save As write failure. Reuse
  `showSaveErrorAlert()` while the cloud confirmation window is still open;
  do not add a second alert or hardcoded copy.

The required preflight shape is:

```swift
guard let renderedImage,
      AnnotateExporter.saveToFile(image: renderedImage, state: state)
else {
    showSaveErrorAlert()
    return
}
Self.persistCommittedSession(sessionSnapshot, for: sourceURL)
```

Place it before capturing `oldCloudKey`, `capturedState`, and `itemId`, and
before creating the upload `Task`. The exact formatting may follow the
repository formatter, but the guard and its position are load-bearing.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift | `git diff --stat f67a3ab9..HEAD -- Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift Notinhas/Features/Annotate/Services/AnnotateExporter.swift NotinhasTests/Features/Annotate/AnnotateExportSaveTests.swift` | Empty on the planned baseline, or reviewed drift before proceeding |
| Existing failure coverage | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateExportSaveTests` | Exit 0; existing false-return and readable-write tests pass |
| Formatting | `make format-check` | Exit 0; no SwiftFormat violations |
| Changed-file lint | `make lint-changed` | Exit 0; no changed Swift lint violations |
| Project gate | `make agent-check` | Exit 0; no unhandled changed surface |
| Plan surface | `./scripts/verify-local.sh --base f67a3ab9 --plan-only` | Exit 0; Annotate test coverage and any manual-required gate are visible |
| Full default suite | `make test` | Exit 0; no new failures |

## Suggested executor toolkit

- Use `.agents/skills/testing-xctest/SKILL.md` for the quiet XCTest command and
  the rule against introducing a cloud/network integration test here.
- Use `.agents/skills/capture-annotate-export/SKILL.md` for the invariant that
  the clipboard-ready visual handoff must never point at stale cloud pixels.
- Use the global `code-quality` guidance: keep the fix as two explicit guards;
  do not create a cloud coordinator or protocol for one controller owner.

## Scope

**In scope** — the only production/test files to modify:

- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift`
- `plans/README.md` status row

The following are read-only dependencies and must not be modified:

- `Notinhas/Features/Annotate/Services/AnnotateExporter.swift`
- `Notinhas/Features/Annotate/Services/AnnotationSessionStore.swift`
- `Notinhas/Services/Cloud/CloudManager.swift` and all cloud providers
- `NotinhasTests/Features/Annotate/AnnotateExportSaveTests.swift`

**Out of scope**:

- consolidating the Save and Copy cloud workflows into a new helper;
- changing upload failure fallbacks, old-object cleanup after successful upload,
  cloud history, cloud configuration, or credentials;
- changing normal local Save/Copy background failure behavior (Plan 087);
- changing Save As, manual-combine protection, rendering, Quick Access, or
  `AnnotateState`.

## Git workflow

- Branch: `advisor/086-annotate-cloud-commit-gate`
- Commit: `fix(annotate): gate cloud overwrite on local commit`
- Do not push or open a PR unless the operator instructs it.

## Steps

### Step 1: Add the local-commit guard to both cloud paths

In `performCloudReUploadAndClose()` and
`performCloudReUploadCopyAndClose()`, replace the current optional
`if let renderedImage { ... }` write block with the required `guard` from
"Current state". On a missing render or failed write, call the existing
`showSaveErrorAlert()` and return while the confirmed-overwrite window remains
open.

Only after the guard succeeds may the method persist the committed sidecar,
capture the old cloud key/state/item, create the upload task, delete the old
object, mutate cloud state, copy the cloud result, or close. Keep the Save
cloud-failure fallback and Copy cloud-failure fallback in their current
semantic roles; they run only after a successful local write and a later upload
failure.

**Verify**:

```sh
make format-check && make lint-changed
rg -n -U "guard let renderedImage,\\n\\s+AnnotateExporter\\.saveToFile" Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift
```

Expected: both cloud methods contain the guard; formatting and changed-file
lint exit 0.

### Step 2: Prove the failure boundary without adding network test machinery

Keep the existing `AnnotateExportSaveTests` false-return coverage. Do not add a
fake `CloudManager`, provider credentials, network calls, or a protocol solely
for this controller branch. Review the diff and confirm that the first
`Task {` in each cloud method occurs after the successful local-write guard.

For the manual failure check, use a disposable source image whose containing
directory or file cannot be atomically overwritten by the app, then invoke the
confirmed cloud-overwrite Save and Copy actions. Verify that the localized Save
Failed sheet appears, the editor stays open, the source file timestamp/content
is unchanged, no cloud upload/delete activity is logged, and the Copy path did
not replace the clipboard with a stale cloud link. Do not record credentials or
cloud URLs in the handoff.

**Verify**:

```sh
./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateExportSaveTests
```

Expected: exit 0. The manual check is required because the controller has no
safe headless window/cloud seam and adding one would exceed this plan.

### Step 3: Run delivery gates and record the plan status

Run the focused tests, `make format-check`, `make lint-changed`,
`make agent-check`, `./scripts/verify-local.sh --base f67a3ab9 --plan-only`, and
`make test`. Keep any manual-required Annotate output visible. Before the
executor commits, `git status -sb` must show only the in-scope files.

**Verify**: all applicable commands exit 0, the manual failure check is
recorded, and `plans/README.md` marks Plan 086 `DONE` only after review.

## Test plan

- Reuse `AnnotateExportSaveTests` for the writer's existing success and
  false-return contracts; no duplicate filesystem test is needed.
- Use the manual read-only/disposable-file check for the side-effect invariant:
  failed local write means no upload, delete, cloud mutation, clipboard
  replacement, or close.
- Run `make test` for the full quiet XCTest suite.
- Run the manual Save and Copy cloud-overwrite checks on macOS with the normal
  application permissions and an intentionally disposable file.

## Done criteria

- [ ] Both cloud-overwrite methods return immediately after a missing render or
      failed local write and present the existing localized Save Failed sheet.
- [ ] Sidecar persistence, upload, old-key deletion, cloud-state mutation,
      cloud-link/image clipboard fallback, and close are unreachable after
      local commit failure.
- [ ] Cloud upload failure behavior after a successful local write is unchanged
      for both Save and Copy.
- [ ] `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateExportSaveTests` exits 0.
- [ ] `make format-check`, `make lint-changed`, `make agent-check`, and
      `make test` exit 0.
- [ ] `./scripts/verify-local.sh --base f67a3ab9 --plan-only` exits 0 with its
      manual-required output recorded.
- [ ] Manual local-write failure checks for Save and Copy are recorded.
- [ ] No files outside Scope are modified; the Plan 086 status row is updated
      after delivery.

## STOP conditions

Stop and report instead of improvising if:

- `saveToFile` no longer returns a `Bool` or its failure behavior differs from
  the excerpt above;
- the cloud path must upload before writing the source file for a documented
  provider requirement;
- showing the existing alert would require closing the window first;
- a failed local write currently has a required product fallback that this plan
  would remove;
- the manual check would require exposing, recording, or changing cloud
  credentials;
- the fix requires editing `CloudManager`, a provider, persistence, or
  `AnnotateState`;
- a focused test or delivery gate fails twice after a reasonable fix attempt;
- the working tree contains unrelated changes in an in-scope file.

## Maintenance notes

- Keep the local-write guard immediately before the cloud task. Future changes
  must not move upload, delete, or cloud-state mutation ahead of it.
- The broader Save/Copy cloud sequence remains intentionally duplicated because
  their clipboard fallbacks differ. Extract it only after a second real owner or
  a safe test seam exists.
- Plan 087 handles failures in the detached normal local commit tail; do not
  silently fold that recovery UX into this cloud-only fix.
