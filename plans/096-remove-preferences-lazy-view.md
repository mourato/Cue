# Plan 096: Remove the single-use Preferences LazyView

Executor: implementation agent in an isolated worktree. Baseline:
`ce23ea3471f7f367fe470f2983245711f4bdbe29`; perform a drift check first.

Status: TODO
Execution profile: implementer-fast; Low/Fast; independent and parallelizable;
reviewer required because Preferences is user-facing.

## Why

`LazyView` is a 24-line generic wrapper used only by the nine tab bodies in
`PreferencesView`. It adds a custom deferred-construction layer without a
measured need; direct SwiftUI tab content is the native, shorter model.

## Scope

- Replace the nine `LazyView { ... }` wrappers in
  `Notinhas/Features/Preferences/PreferencesView.swift` with their direct view
  content, preserving tab identifiers/order and selection behavior.
- Delete `Notinhas/Common/Components/LazyView.swift`.
- Do not add another lazy container, alter Preferences layout, or change tab
  state ownership.

## Validation

Confirm `LazyView` has no uses outside `PreferencesView`, then run:

```text
./scripts/verify-local.sh --base ce23ea34 --full --plan-only --strict
make format-check
make lint-changed
make agent-check
make build
make test
```

Manual gate: open Preferences, switch through every tab, close/reopen it, and
verify selection, settings loading, and appearance remain unchanged. If a
measurable startup or memory regression appears, stop and report the evidence;
do not retain a generic wrapper speculatively.

## Done criteria / STOP

`LazyView` is gone, all Preferences tabs compile and behave normally, and the
focused gates pass. Stop if a second caller or measured deferred-initialization
requirement is found; narrow the plan to that concrete requirement.

