---
kind: project-overlay
extends: swift-conventions
project: Cue
precedence: project
---

# Cue Swift checks

- Product intent: support the capture → annotate → clipboard-ready handoff.
- Canonical paths are `Cue/` and `CueTests/`.
- Swift baseline: Swift 6.2 with complete strict concurrency and explicit
  `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`. Keep UI/AppKit/lifecycle
  edges explicitly `@MainActor`; keep capture, image, and file processing off
  the main actor and use value snapshots or narrow adapters at SDK boundaries.
- Do not add broad `@preconcurrency`, `@unchecked Sendable`, or
  `nonisolated(unsafe)` escapes. Any SDK boundary import or isolation
  exception must document the invariant and be covered by the relevant build
  or test gate.
- Formatter/lint commands: `make format-check`, `make lint`, and
  `make lint-changed`. Use `make format-fix` or `make lint-fix` only as
  explicit autofix commands; verification must fail closed.
- Screen Recording and Accessibility permissions are required for affected capture and accessibility checks.
- Use `./scripts/build_and_run.sh`, `./scripts/run-tests.sh`, and `./scripts/verify-local.sh` for project validation.
- The optional Video module is compile-time gated by `CUE_VIDEO_MODULE` and runtime-gated by `VideoModuleAvailability` / `videoModule.enabled` (default off). Manual validation of capture → annotate → export requires the relevant permissions.
- Preserve Cue branding and Snapzy fork compatibility. Do not reintroduce Sparkle, support endpoints, or unrelated recording/cloud features.
