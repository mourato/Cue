---
kind: project-overlay
extends: delivery-workflow
project: Cue
precedence: project
---

# Cue delivery checks

- Product-specific identifiers and commands for Cue belong in this overlay
  or repository guidance, not in the portable global `delivery-workflow` skill.
- Product intent: support the capture → annotate → clipboard-ready handoff.
- Canonical paths are `Cue/` and `CueTests/`.
- Swift 6.2 delivery baseline uses complete strict concurrency with
  nonisolated-by-default targets; compiler concurrency diagnostics must be
  fixed or explicitly documented, never hidden by broad unsafe annotations.
- Run `make format-check`, `make lint`, and `make lint-changed` for the
  formatter/lint contract. The full default gate is `make build` and
  `make test`; the optional module is covered by `make build-video` and
  `make test-video` using the `Cue Video` / `Debug+Video` configuration.
- Use `make agent-check` and
  `./scripts/verify-local.sh --base <ref> --full --plan-only --strict` for
  changed-surface planning. Preserve manual Screen Recording/Accessibility
  checks when the changed surface requires them.
- `make validate` is the canonical changed-surface entry and delegates to
  `make agent-check`.
- `make validate-lane` is the delivery wrapper around `make validate`; it
  records the explicit `origin/main` merge-base and watches the ignored
  `build/verification/` artifact output, cleaning only its `build/` parent
  when created by that run.
- Screen Recording and Accessibility permissions are required for affected capture and accessibility checks.
- Use `./scripts/build_and_run.sh`, `./scripts/run-tests.sh`, and `./scripts/verify-local.sh` for project validation. The default `run-tests.sh` mode is quiet; pass `--with-visual` only for an intentional on-screen UI integration run.
- The optional Video module is compile-time gated by `CUE_VIDEO_MODULE` and runtime-gated by `VideoModuleAvailability` / `videoModule.enabled` (default off). Manual validation of capture → annotate → export requires the relevant permissions.
- Preserve Cue branding and Snapzy fork compatibility. Do not reintroduce Sparkle, support endpoints, or unrelated recording/cloud features.
