# Plan 090: Delete unused SwiftUI style extensions

Executor: implementation agent in an isolated worktree. Baseline:
`ce23ea3471f7f367fe470f2983245711f4bdbe29`; perform a drift check first.

Status: TODO
Execution profile: implementer-fast; Low/Fast; independent and parallelizable;
reviewer required for the deletion/compile check.

## Why

`View+ButtonStyle.swift` and `View+CornerRadius.swift` define custom
`.button(...)` and `.rounded(...)` APIs with no production or test call sites.
They add names and implementation that the native SwiftUI styles and existing
shape APIs already cover.

## Scope

- Confirm zero references to the custom `button` and `rounded` extensions,
  excluding unrelated standard calls and the extension declarations.
- Delete `Notinhas/Shared/Extensions/View+ButtonStyle.swift` and
  `Notinhas/Shared/Extensions/View+CornerRadius.swift`.
- Do not replace call sites because the caller map is expected to be empty.
- Do not add a replacement abstraction or dependency.

## Validation

```text
./scripts/verify-local.sh --base ce23ea34 --full --plan-only --strict
make format-check
make lint-changed
make agent-check
make build
make test
```

## Done criteria / STOP

The two files are gone, no custom extension reference remains, and the default
build/tests pass. Stop if a real caller appears after excluding declaration
lines; update this plan's scope rather than silently changing its styling.

