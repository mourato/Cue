# Plan 093: Remove the disabled backdrop crossfade path

Executor: implementation agent in an isolated worktree. Baseline:
`ce23ea3471f7f367fe470f2983245711f4bdbe29`; perform a drift check first.

Status: TODO
- **Planned at**: commit `ce23ea34`, 2026-08-20
Execution profile: implementer; Medium/Full; independent but serialize with
other Capture/Annotate window edits; reviewer required; manual capture check.

## Why

`BackdropTransitionEffect.isEnabled` is permanently `false`, so the duration,
reduce-motion decision, animation parameter, and crossfade plumbing are dead.
The active behavior is already an immediate layer-content swap.

## Scope

- Delete `Notinhas/Services/Capture/BackdropTransitionEffect.swift`.
- Remove the `animated` parameter and transition branching from the backdrop
  methods in `AreaSelectionWindow.swift`; keep the existing immediate
  `CATransaction` behavior and backdrop visibility handling.
- Delete or rewrite only the transition-specific tests in
  `AreaSelectionOverlayBackdropTransitionTests.swift`; retain coverage for
  visible/invisible backdrop final state if it no longer depends on animation.
- Do not alter backdrop capture, luma-only behavior, overlay geometry, or
  unrelated animations.

## Validation

Map every `BackdropTransitionEffect`, `applyBackdrop(... animated:)`, and
transition test before editing. Then run:

```text
./scripts/verify-local.sh --base ce23ea34 --full --plan-only --strict
make format-check
make lint-changed
make agent-check
make build
make test
```

Manual gate: with Screen Recording permission, perform an area selection over
visible and luma-only content and verify the backdrop appears/disappears with
the same final state and no visual regression. Do not enable a replacement
animation.

## Done criteria / STOP

No transition type/flag/parameter remains, final backdrop behavior is covered,
and capture gates pass. Stop if a real animation is enabled by a runtime or
accessibility setting not visible in the baseline; preserve that path and
narrow the deletion.
