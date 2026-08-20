# Plan 091: Remove the one-campaign Feature Intro framework

Executor: implementation agent in an isolated worktree. Baseline:
`ce23ea3471f7f367fe470f2983245711f4bdbe29`; perform a drift check first.

Status: TODO
- **Planned at**: commit `ce23ea34`, 2026-08-20
Execution profile: implementer; Medium/Full; independent and parallelizable;
reviewer required because startup/menu behavior and localization are affected.

## Why

The generic `FeatureIntro` system is a 476-line JSON-driven campaign engine
serving one `whats_new.json` campaign with a hard-coded action mapping. This is
release-note machinery disguised as a runtime framework. The product already
has documentation/release notes; keeping the native onboarding/splash flow is
enough.

## Scope

- Remove `Notinhas/Shared/Components/FeatureIntro/` and
  `Notinhas/Resources/whats_new.json` after mapping all callers.
- Remove campaign pending/show calls from `AppCoordinator` and
  `AppStatusBarController`, including any menu item that exists only to launch
  the campaign.
- Remove only orphaned Whats New/Feature Intro localization entries and update
  `docs/APP_LIFECYCLE.md` (and any directly affected documentation).
- Preserve onboarding, startup splash, diagnostics, and unrelated status-bar
  actions. Do not introduce another release-note framework.

## Steps and validation

1. Confirm `FeatureIntroManager` is not used for onboarding or permission
   prompts; map `getPendingCampaign`, `showCampaign`, and `start_smart_capture`.
2. Delete the framework/resource and simplify the two lifecycle/menu owners.
3. Prune orphaned localization and document that release notes are external to
   startup runtime.
4. Run:

```text
./scripts/verify-local.sh --base ce23ea34 --full --plan-only --strict
make format-check
make lint-changed
make agent-check
make build
make test
```

Manually launch the app and verify the normal splash/onboarding path and the
status-bar menu still work; verify no campaign lookup or missing-resource log
appears.

## Done criteria / STOP

No runtime campaign framework/resource/call remains, normal startup behavior is
preserved, and gates pass. Stop if the mapping reveals a second campaign or if
the framework owns onboarding/permission state; split that behavior before
deleting it.
