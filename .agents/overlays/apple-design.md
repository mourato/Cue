---
kind: project-overlay
extends: apple-design
project: Cue
precedence: project
---

# Cue visual checks

- Product intent: support the capture → annotate → clipboard-ready handoff.
- Canonical paths are `Cue/` and `CueTests/`.
- Screen Recording and Accessibility permissions are required for affected capture and accessibility checks.
- Use `./scripts/build_and_run.sh`, `./scripts/run-tests.sh`, and `./scripts/verify-local.sh` for project validation.
- The optional Video module is compile-time gated by `CUE_VIDEO_MODULE` and runtime-gated by `VideoModuleAvailability` / `videoModule.enabled` (default off). Manual validation of capture → annotate → export requires the relevant permissions.
- Preserve Cue branding and Snapzy fork compatibility. Do not reintroduce Sparkle, support endpoints, or unrelated recording/cloud features.
