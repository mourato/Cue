---
kind: project-overlay
extends: macos-app-engineering
project: Cue
precedence: project
---

# Cue application checks

- Product intent: support the capture → annotate → clipboard-ready handoff.
- Canonical paths are `Cue/` and `CueTests/`.
- Screen Recording and Accessibility permissions are required for affected capture and accessibility checks.
- Use `./scripts/build_and_run.sh`, `./scripts/run-tests.sh`, and `./scripts/verify-local.sh` for project validation.
- The optional Video module is compile-time gated by `CUE_VIDEO_MODULE` and runtime-gated by `VideoModuleAvailability` / `videoModule.enabled` (default off). Manual validation of capture → annotate → export requires the relevant permissions.
- Preserve Cue branding and Snapzy fork compatibility. Do not reintroduce Sparkle, support endpoints, or unrelated recording/cloud features.
- Keep SwiftUI `body` cheap and non-blocking. Never resolve Keychain/`securityd`, disk, or XPC synchronously in a `body` or in computed properties read during `body` (e.g. a credential `isConfigured`); cache presence as `@Published` and refresh only on mutation (init/save/clear/reload). A monolithic `@ObservableObject` re-renders its whole view tree on any `@Published` change, so one hidden synchronous read there hitches every interaction (tool switch, selection, drag start, notes).
