# AGENTS.md

Cue: Snapzy fork turning a screenshot into a pinned, annotated,
clipboard-ready visual brief; Swift 6.2 strict concurrency.

Commands: [Makefile](Makefile) is canonical; `make validate` delegates to
`make agent-check`. Project facts for global skills live in this file and in
the `docs/agents/` files linked below.

## Local routing

| Before | Read or load |
|---|---|
| Implementation, validation, or delivery | [Project workflow facts](docs/agents/project-workflow.md) |
| Delivery, build, test, or release | [docs/agents/delivery.md](docs/agents/delivery.md) |
| Review or retro | [Coding standards](CODING_STANDARDS.md) |
| Guidance governance or routing policy | [`project-standards`](.agents/skills/project-standards/SKILL.md) |
| Capture, annotate, or export work | [`capture-annotate-export`](.agents/skills/capture-annotate-export/SKILL.md) |
| Executing or reviewing a plan | [`plan-execute-review`](.agents/skills/plan-execute-review/SKILL.md) |
| Retained vs removed upstream surfaces | [ADR 070](docs/adr/070-retain-inherited-snapzy-surfaces.md) |

Other project skills live under `.agents/skills/`; choose the narrowest one.
