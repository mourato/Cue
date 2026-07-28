---
kind: project-overlay
extends: delivery-workflow
project: Notinhas
precedence: project
---

# Notinhas delivery checks

- Product-specific identifiers and commands for Notinhas belong in this overlay
  or repository guidance, not in the portable global `delivery-workflow` skill.
- Product intent: support the capture → annotate → clipboard-ready handoff.
- Canonical paths are `Notinhas/` and `NotinhasTests/`.
- Screen Recording and Accessibility permissions are required for affected capture and accessibility checks.
- Use `./scripts/build_and_run.sh`, `./scripts/run-tests.sh`, and `./scripts/verify-local.sh` for project validation.
- The optional Video module is compile-time gated by `NOTINHAS_VIDEO_MODULE` and runtime-gated by `VideoModuleAvailability` / `videoModule.enabled` (default off). Manual validation of capture → annotate → export requires the relevant permissions.
- Preserve Notinhas branding and Snapzy fork compatibility. Do not reintroduce Sparkle, support endpoints, or unrelated recording/cloud features.
