# Plan 095: Remove the one-property AppEnvironment wrapper

Executor: implementation agent in an isolated worktree. Baseline:
`ce23ea3471f7f367fe470f2983245711f4bdbe29`; perform a drift check first.

Status: TODO
- **Planned at**: commit `ce23ea34`, 2026-08-20
Execution profile: implementer-fast; Low/Fast; independent and parallelizable;
reviewer required for compile verification.

## Why

`AppEnvironment` wraps exactly one `ScreenCaptureViewModel`, has one factory,
and is consumed only by `AppCoordinator`. It adds indirection without a
boundary, test seam, or second dependency.

## Scope

- Change `AppCoordinator` to store a `ScreenCaptureViewModel` directly and
  accept it in its initializer.
- Replace `environment.screenCaptureViewModel` at launch/deep-link call sites.
- Update `NotinhasApp` to construct the coordinator with the existing concrete
  view model.
- Delete `Notinhas/App/AppEnvironment.swift`.
- Do not add a replacement container or protocol; preserve `@MainActor` and
  lifecycle ordering.

## Validation

Map all `AppEnvironment` and `environment.` references before editing. Then
run:

```text
./scripts/verify-local.sh --base ce23ea34 --full --plan-only --strict
make format-check
make lint-changed
make agent-check
make build
make test
```

## Done criteria / STOP

There is no `AppEnvironment` type/reference, launch and deep-link behavior are
unchanged, and gates pass. Stop if another dependency is discovered; do not
turn this cleanup into a generalized dependency-injection refactor.
