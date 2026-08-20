# Plan 094: Prune dead wallpaper quality flags

Executor: implementation agent in an isolated worktree. Baseline:
`ce23ea3471f7f367fe470f2983245711f4bdbe29`; perform a drift check first.

Status: TODO
- **Planned at**: commit `ce23ea34`, 2026-08-20
Execution profile: implementer-fast; Low/Fast; independent and parallelizable;
reviewer optional after focused compile check.

## Why

`WallpaperQualityConfig` declares `usePrecomputedBlur`, `showDebugOverlay`,
and `logPerformanceMetrics`, but no code reads them. Keep the live
`maxResolution` and `blurRadius` constants, including `blurRadius` used by the
Video-gated state, and remove only the unread flags/comments.

## Scope and validation

Confirm the three flags have no readers, remove them from
`Notinhas/Services/Wallpaper/WallpaperQualityConfig.swift`, and leave all
wallpaper capture/blur behavior unchanged. Run:

```text
./scripts/verify-local.sh --base ce23ea34 --full --plan-only --strict
make format-check
make lint-changed
make agent-check
make build
make test
```

## Done criteria / STOP

Only live constants remain and default/Video-gated compilation is unaffected.
Stop if a generated/configuration consumer or a real Video reader appears;
retain that flag or update the consumer explicitly rather than deleting a
runtime contract.
