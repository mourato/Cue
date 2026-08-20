# Plan 092: Shrink the WindowSpacing API to live modifiers

Executor: implementation agent in an isolated worktree. Baseline:
`ce23ea3471f7f367fe470f2983245711f4bdbe29`; perform a drift check first.

Status: TODO
Execution profile: implementer-fast; Low/Fast; independent and parallelizable;
reviewer required for compile verification.

## Why

`NSWindow+WindowSpacing.swift` exposes configuration fields and helpers that
have no callers. Keep the four modifiers actually used by Annotate/Video UI;
delete the API surface that invites configuration of nonexistent layout.

## Scope

Keep only `windowToolbarPadding()`, `windowBottomBarPadding()`,
`windowContentHPadding()`, and `windowTrafficLightsInset()` plus the configuration
fields those implementations directly read. Remove unused helpers and fields
such as toolbar/bottom-bar height, corner-radius, and available-width helpers.
Do not change `NSWindow+TrafficLights.swift` or visual constants unless the
compiler proves a retained modifier needs a minimum adjustment.

## Validation

Before editing, map references in all configurations and Video-gated callers.
After editing, verify the removed symbols have no references, then run:

```text
./scripts/verify-local.sh --base ce23ea34 --full --plan-only --strict
make format-check
make lint-changed
make agent-check
make build
make test
```

## Done criteria / STOP

The file contains only live spacing API, Annotate and Video-gated callers
compile, and gates pass. Stop if an unlisted helper has a real caller or if
pruning a field changes a measured layout; add only that field/helper with its
caller documented.

