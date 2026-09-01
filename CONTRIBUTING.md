# Contributing to Cue

Thanks for contributing to Cue.

Cue is a macOS visual-handoff app built on a Snapzy fork: capture an area, add numbered pins and notes, and copy a clipboard-ready brief for developers and AI agents.

## Ways to contribute

- Report bugs via GitHub Issues
- Propose features or UX improvements aligned with the visual-handoff loop
- Improve documentation
- Submit code fixes or focused features
- Help test changes on macOS

## Before you start

- Search existing issues and pull requests before opening a new one.
- For larger changes, open an issue first so the approach can be discussed.
- Keep contributions focused. Small, reviewable pull requests move faster.
- Do not reintroduce Sparkle updates, About/Report UI, `snapzy://` aliases, or a public support funnel.

## Development setup

Use [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for local setup, cloning, opening the Xcode project, and running a debug build.

For archive, export, or DMG packaging, see [docs/BUILD.md](docs/BUILD.md).

## Project conventions

Cue uses a feature-based structure with limited nesting.

- Keep primary feature entry points at the root of each feature folder.
- Use `Components`, `Managers`, `Services`, and `Models` only when needed.
- Keep Cue-specific logic in `Cue/Features/Cue/`.
- Avoid unrelated renames or directory reshuffles in the same pull request.

See [docs/STRUCTURE.md](docs/STRUCTURE.md) for current architecture guidance.

## Contribution workflow

1. Create a branch from `main`.
2. Make one focused change.
3. Update documentation when behavior, setup, or workflow changes.
4. Validate the change locally.
5. Open a pull request with clear context and test notes.

## Coding guidelines

- Follow the existing Swift and SwiftUI style in the repository.
- Prefer clear, descriptive type and file names.
- Keep changes scoped to the problem being solved.
- Add comments only when the intent is not obvious from the code.
- Preserve existing user-facing behavior unless the pull request explicitly changes it.

## Validation

Before opening a pull request:

- The project builds in Xcode or via `xcodebuild`
- `./scripts/run-tests.sh` passes for affected areas
- The affected capture/annotate/export flow works on macOS
- Permission-sensitive flows are tested when relevant (Screen Recording, Accessibility)

Include manual test steps for capture, annotation, clipboard export, migration, or deep-link changes.

## Pull request checklist

- Describe what changed and why
- Link the related issue when one exists
- Keep the pull request focused and reviewable
- Include screenshots or short recordings for UI changes
- Note follow-up work or known limitations
- Confirm how you tested the change

## Commit messages

Use short, imperative commit messages. Prefixes such as `feat:`, `fix:`, `docs:`, `refactor:`, and `chore:` are preferred.

Examples:

- `fix: prevent duplicate quick access panels`
- `docs: update local build instructions`
- `feat(notinhas): keep marker order in export brief`

## Reporting bugs

When filing a bug report, include:

- macOS version
- Cue version or commit SHA
- Steps to reproduce
- Expected and actual behavior
- Screenshots or recordings if relevant
- Relevant lines from `~/Library/Logs/Cue/cue_*.txt` when diagnostics are enabled

## Security issues

Do not report security vulnerabilities in public issues. Use [GitHub Security Advisories](https://github.com/mourato/Cue/security/advisories/new) on this repository.
