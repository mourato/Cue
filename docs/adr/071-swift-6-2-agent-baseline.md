# ADR 071: Swift 6.2 agent baseline

## Status

Accepted for the Notinhas app, tests, and optional Video configurations.

## Decision

All owned Xcode configurations use `SWIFT_VERSION = 6.2`,
`SWIFT_STRICT_CONCURRENCY = complete`, and explicit
`SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`. `SWIFT_APPROACHABLE_CONCURRENCY`
and the existing upcoming-feature settings remain enabled where already
owned; they do not replace complete strict-concurrency checking. UI,
AppKit, and lifecycle entry points opt into `@MainActor` explicitly.

SwiftFormat is pinned by repository policy to Swift 6.2 syntax and four-space
indentation with the existing 120-column and generated/Pods/build exclusions.
SwiftLint owns the `Notinhas` and `NotinhasTests` surfaces through
`.swiftlint.yml`; checks are fail-closed and have separate full, changed, and
autofix commands. The focused baseline opts into `empty_string` and
`first_where`, both verified clean on the owned app and test surfaces. The
configuration preserves named pre-existing repository debt and compatibility
exceptions in `disabled_rules` (including high-churn style/size and legacy
rules); touched or new code must not expand those exceptions. Unrelated legacy
violations are not broad-cleaned as part of this baseline, and no new disabled
rule is used to silence a Swift 6.2 migration diagnostic.

The migration permits mechanical formatting and concurrency corrections in
owned source/tests. Capture, OCR, export, persistence, Video behavior, public
contracts, filters, geometry, and output formats remain unchanged. The
ScreenCaptureKit boundary uses a focused main-actor box for cached shareable
content and immutable value snapshots for captured display data. SDK imports
marked `@preconcurrency` remain limited to the specific legacy SDK boundary;
new broad `@unchecked Sendable` escapes are not permitted.

The optional Video module is part of the gate: use `make build-video` and
`make test-video`, which select the real `Notinhas Video` / `Debug+Video`
configuration through the canonical scripts. The default app uses `make build`
and `make test`.

## Validation toolchain

Observed on 2026-08-05:

| Tool | Version/details |
| --- | --- |
| Swift compiler | Swift 6.4 (`swift-driver` 1.168.4; target `arm64-apple-macosx27.0.0`) — the installed compiler used to validate the Swift 6.2 language baseline |
| Xcode | 27.0 (`27A5218g`) |
| SwiftFormat | 0.62.1 |
| SwiftLint | 0.65.0 |

## Agent command tiers

- Focused: `make format-check`, `make lint-changed`, and the relevant XCTest
  selector from `scripts/verification-map.tsv`.
- Full local: `make format-check`, `make lint`, `make build`, `make test`,
  `make build-video`, `make test-video`.
- Handoff: `make agent-check`, `make guidance-check`, `git diff --check`, and
  the manual capture/TCC checks reported by `verify-local`. Plan-only strict
  verification fails on unmapped paths while reporting manual-required gates;
  execute mode remains blocked until those manual gates are completed.

Build warnings are not suppressed. Existing SDK deprecations and concurrency
diagnostics exposed by the nonisolated baseline are recorded in build logs and
must be resolved at their owning boundary or explicitly reviewed before an
Xcode/toolchain upgrade; they are not made harmless with global
`@preconcurrency`, `@unchecked Sendable`, or warning-disabling flags.

## Upgrade and exception process

An upgrade must change the Xcode settings, formatter/lint configuration,
Make/script and CI/pre-commit commands, overlays, and this ADR together. Any
temporary exception names its owner, boundary, reason, and removal condition.
The exception is removed when the relevant SDK exposes Sendable/actor
annotations or the owning code can use an immutable snapshot.
