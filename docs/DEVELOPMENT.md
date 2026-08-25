# Development

Set up Notinhas for local development and run it from source.

## Prerequisites

- macOS 26.0+
- Xcode 15.0+
- Command Line Tools: `xcode-select --install`

## Clone the repository

```bash
git clone https://github.com/mourato/Notinhas.git
cd Notinhas
```

## Open in Xcode

```bash
open Notinhas.xcodeproj
```

Build and run with `Cmd+R` using the **Notinhas** scheme (Video module off by default).

## Daily local version

The first commit made each day updates the app version to `<major>.<month>.<day>`
and increments the build number. Enable the tracked pre-commit hook once per
clone:

```bash
git config --local core.hooksPath scripts
```

Use `SKIP_DAILY_VERSION_BUMP=1` to skip one commit or
`FORCE_DAILY_VERSION_BUMP=1` to force a bump. The hook updates the four app
configurations only; test bundle versions are independent.

## Build from the terminal

```bash
xcodebuild -project Notinhas.xcodeproj -scheme Notinhas -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Output: `~/Library/Developer/Xcode/DerivedData/Notinhas-*/Build/Products/Debug/Notinhas.app`

## Run the local debug app

Use `./scripts/build_and_run.sh` as the canonical local entry point (build, launch,
verify, log streaming; Video module on by default). `./scripts/launch.sh` remains as a
legacy compatibility wrapper that forwards to `./scripts/build_and_run.sh --logs`.

```bash
./scripts/build_and_run.sh
./scripts/build_and_run.sh --no-video-module   # plain Notinhas scheme
```

With the default Video module, the script builds **Notinhas Debug.app** at:

```text
.build/xcode-derived-data/Build/Products/Debug+Video/Notinhas Debug.app
```

Debug uses bundle ID `com.mourato.notinhas.debug` so TCC grants stay separate from release `com.mourato.notinhas`.
Debug builds deliberately do not declare image document types, so they do not appear in Finder's **Open With** menu. Open an image explicitly during development with `open -a "Notinhas Debug" path/to/image.png` when needed.

If old duplicate Notinhas entries remain after upgrading, keep the installed app at `/Applications/Notinhas.app` and run:

```bash
./scripts/clean-launch-services.sh
```

The script unregisters stale Notinhas and Notinhas Debug paths, then registers only the canonical installed app. It does not delete app bundles or affect other applications.

Reset local Debug permissions:

```bash
tccutil reset ScreenCapture com.mourato.notinhas.debug
tccutil reset Microphone com.mourato.notinhas.debug
tccutil reset Accessibility com.mourato.notinhas.debug
```

## Run tests

Unit tests live in `NotinhasTests/`, a peer folder of `Notinhas/`.

```bash
./scripts/run-tests.sh
./scripts/run-tests.sh --with-visual   # explicit on-screen overlay/panel suites
./scripts/run-tests.sh --video-module   # optional Recording/VideoEditor XCTests
```

The default test command is quiet: the app's interactive host stays inactive,
visual overlay/panel suites are skipped, and app sounds are muted. Use
`--with-visual` only for an intentional UI integration run. Keep
`NOTINHAS_ALLOW_TEST_SOUNDS=1` unset except for an intentional audio
integration run.

Or directly:

```bash
xcodebuild test -project Notinhas.xcodeproj -scheme Notinhas -configuration Debug
```

Use `./scripts/run-tests.sh` for the quiet default; direct `xcodebuild test`
does not apply the repository's visual-suite skip list.

## Plan preflight (read-only)

Before dispatching or implementing a handoff plan, run the local preflight
command. It inspects plan metadata, `plans/README.md` dependency status,
explicit scope paths, drift since the plan’s `Planned at` SHA, and worktree
cleanliness. It does **not** commit, merge, push, or replace thermo review or
manual capture/TCC/WindowServer gates.

```bash
./scripts/plan-preflight.sh plans/047-local-plan-preflight.md \
  --scope scripts/plan-preflight.sh \
  --scope scripts/tests/plan-preflight.sh \
  --report build/plan-preflight/047.json --json
```

Use `--new-file <path>` for scope entries the plan will create. Prefer
`build/plan-preflight/` for generated reports (ignored by Git). Fixture
coverage: `scripts/tests/plan-preflight.sh`.

## Changed-surface verification (local)

After editing code, run the local verification planner to resolve which deterministic
checks apply to the touched paths. It reuses `./scripts/run-tests.sh` for XCTest
selectors, runs `bash -n` / `--help` for touched shell scripts, and surfaces
`manual-required` items instead of claiming full coverage.

```bash
./scripts/verify-local.sh --base main --plan-only
./scripts/verify-local.sh --base main --plan-only --strict
./scripts/verify-local.sh --base main --execute
./scripts/verify-local.sh --full --execute   # explicit full-suite delegate
```

Reports are written to `build/verification/` by default. Fixture coverage:
`scripts/tests/verify-local.sh`.

This command narrows local deterministic feedback. It does **not** replace the full
`./scripts/run-tests.sh` gate, visual overlay suites, or manual Screen Recording /
Accessibility / TCC / WindowServer / clipboard checks when those surfaces change.

## Local Git integration protocol

After preflight and changed-surface verification succeed, use the integration
protocol runner to standardize commit → merge → cleanup → push. Default mode is
**dry-run** (no Git side effects). `--apply` requires explicit source/target
refs, remote name, evidence path, and `--reviewed-commit` matching the source
tip. The command never force-pushes, auto-resolves conflicts, or marks plans
`DONE` in `plans/README.md`; integrated thermo review remains mandatory.

```bash
./scripts/integrate-plan.sh --dry-run \
  --source-branch advisor/049-local-git-integration-protocol \
  --target-branch main --remote origin

./scripts/integrate-plan.sh --apply --fetch --cleanup \
  --source-branch advisor/049-local-git-integration-protocol \
  --target-branch main --remote origin \
  --evidence build/integration/049-evidence.json \
  --reviewed-commit <source-sha>
```

Evidence manifests use `kind: notinhas-integration-evidence` and reference
passing preflight JSON plus a `verify-local` report for the source commit.
Fixture coverage: `scripts/tests/integrate-plan.sh`.

## Optional Video module

`./scripts/build_and_run.sh` includes the Video module by default. Opt out with
`--no-video-module` or `ENABLE_VIDEO_MODULE=0`. In Xcode, select the
**Notinhas Video** scheme (or keep **Notinhas** for a build without the module).

Enable at runtime under **Preferences → Advanced** when compiled in.

## Related docs

- [BUILD.md](BUILD.md) — archive, export, DMG packaging
- [RELEASES.md](RELEASES.md) — GitHub Release workflow
- [MIGRATION.md](MIGRATION.md) — Notinhas upgrade path
