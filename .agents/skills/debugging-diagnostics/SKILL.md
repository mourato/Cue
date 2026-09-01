---
name: debugging-diagnostics
description: Debugging guidance for Cue — capture permission failures, signing/TCC resets, annotate/export issues, and ImgBB upload errors.
---

# Debugging Diagnostics

Use for crashes, flaky capture/annotate, permission failures, wrong export output, or unexplained UI state.

## Method

1. Reproduce with a clear signature (action, permission state, signed vs ad-hoc build).
2. Narrow: status bar menu vs capture overlay vs Annotate canvas vs Cue export vs persistence vs ImgBB upload.
3. Fix with a regression note in the PR/commit; prefer a focused test when logic is pure (geometry, composer, decode).

## Cue Hotspots

- **Screen Recording not granted** — capture menu disabled or flows blocked (`ScreenCaptureManager`, `ScreenCaptureViewModel` / `CaptureViewModel`).
- **Accessibility not granted** — Smart Element, scrolling capture, or window resolver paths fail (`SmartElementQueryService`, `ActiveWindowResolver`).
- **Signing identity changes** — TCC grants reset; re-grant Screen Recording / Accessibility after ad-hoc resign. For local persistence checks, use `./scripts/test-tcc-local.sh` with its isolated default install path; only use `--install-path` and `--allow-system-install` when you intentionally target `/Applications`.
- **Export / clipboard** — notes panel missing from copied image; check `AnnotateExporter.composeNotinhasIfNeeded` and renderable note filter.
- **Geometry / hit-testing** — wrong pin order, move/delete not registering; check `CueNoteGeometry` and `CueAnnotateState`.
- **ImgBB upload** — missing API key (`notinhas.imgbb.apiKey`), network/API errors; never log key values.
- **Persistence** — corrupted annotation session JSON should fail soft; Cue payload on `PersistedAnnotationSession`.
- **UI lag on tool switch / selection / drag / notes** — a synchronous Keychain/disk/XPC read reached from a SwiftUI `body` that rebuilds on every `@Published` (classic: `NotinhasImgBBCredentialStore.isConfigured` → `CloudKeychainStore` inside `AnnotateBottomBarView` / `QuickAccessCardView`). Cache the flag as `@Published`; never read `securityd` per render.

## Performance / UI Hitch Method

- If per-view `body`/draw timings all look cheap but interactions still hitch, stop guessing per-view. The cost is usually a hidden syscall, not view construction.
- Capture real main-thread stacks: `sample <pid> <seconds> -file /tmp/out.txt` (or Instruments Time Profiler), then read the self-time leaf frames in Cue code. Align the sample window with active interaction (the main thread reads as idle in `mach_msg` otherwise).
- Confirm the fix perceptually (the user feeling the hitch is the reliable signal) and revert temporary instrumentation before committing.

## Logging Hygiene

- Prefer temporary, high-signal logs while diagnosing; do not ship noisy dumps.
- Never log full screenshots, page content, or API keys.

## Related

- AX / contrast → `swiftui-accessibility-audit`
- Build/sign → `delivery-workflow`
- Domain paths → `capture-annotate-export` (when present)
