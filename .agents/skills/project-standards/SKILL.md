---
name: project-standards
description: Use when updating AGENTS.md, documenting project policy, aligning repository standards, skill registry hygiene, or tracking known limitations.
---

# Project Operational Standards

## Role

Canonical owner of project-level guidance governance for Cue.

- Own AGENTS alignment, documentation policy, skill registry, and information-routing standards.
- Keep project guidance synchronized with current `scripts/`, skills, and fork workflow.
- Keep skill-authoring mechanics aligned with the local `.agents/skills/` structure.

## Scope Boundary

- Use this skill for AGENTS maintenance, policy updates, skill registry, and repository standards.
- Implementation details stay in domain skills (`capture-annotate-export` and
  the global `macos-app-engineering` skill, with its Cue overlay).
- Delivery commands and merge gates stay in the global `delivery-workflow` skill
  and its Cue overlay.

## When to Use

Use when the user asks to update AGENTS, document project policy, track known limitations, align repository standards, add or retire skills, or resolve where guidance should live.

## Limitation Tracking

- **Track in GitHub Issues**: Register known limitations and intentional trade-offs via `gh issue create`.
- **Avoid markdown backlog files**: Do not maintain `KNOWN_LIMITATIONS.md` or similar root backlogs.
- **Labels**: Use a `known-limitation` label when the repo has it; otherwise tag issues clearly in title/body.
- **Issue quality**: Each issue should include context, impact, and a clear future direction or acceptance criteria.

## Agent Documentation

- **Living guidance**: `AGENTS.md` reflects current tools, scripts, skills, and product intent.
- **Skill template**: Prefer section order — Role, Scope Boundary, When to Use, domain guidance, Verification (when relevant), Related Skills, References.
- **Reuse policy**: `reuse → extend → create` for Cue helpers before new types.
- **Clean registry**: Periodically audit `.agents/skills` for stale guidance or Picker-era leakage.
- **Command surface sync**: When `scripts/*` change, update `AGENTS.md` and the
  global `delivery-workflow` overlay in the same change.
- **Preview standard**: Keep preview-related guidance in the global
  `macos-app-engineering` skill and its overlay.
- **Fork awareness**: Preserve `Cue/Features/Cue/` across `upstream` merges; do not delete Cue modules during conflict resolution.

## Information Routing

Route new knowledge in this order:

1. **Skill absorption** (`.agents/skills/...`) for reusable operational guidance.
2. **AGENTS.md** for durable agent policy and product intent.
3. **Shared upstream-derived docs** (`docs/CAPTURE.md`, `docs/ANNOTATE.md`,
   etc.) for engineering narrative of shared flows — **do not** ban `docs/`;
   **do not** duplicate the same topics in a parallel Cue-only tree.
4. **GitHub issues** for backlog items, known limitations, and follow-up work.
5. **Deletion** for stale or duplicate files with no current operational value.

Generated report artifacts: prefer `/tmp` or `.agents/reports/` (create only when needed).

## Consistency

- **Commit messages**: Conventional Commits (`feat(notinhas):`, `fix:`, `docs(agents):`, `chore:`).
- **Branch workflow**: One writer per isolated branch; preserve unrelated worktree changes.
- **UI quality gate**: Manual capture → annotate → clipboard checks when UI or export paths change.
- **Language**: English for documentation and code comments.

## Evolution

- Review project guidance every ~90 days and whenever scripts, skill registry, or major upstream merges change.
- When a command, skill owner, or validation rule changes, update `AGENTS.md` and the owning skill together. Update other documentation that describes the affected routing or policy when needed.
- Prefer deleting stale guidance over stacking duplicates. One canonical owner per rule.

## Related Skills

- `../documentation/SKILL.md`
- Global `delivery-workflow` and `.agents/overlays/delivery-workflow.md`
- `../capture-annotate-export/SKILL.md`

## References

- `AGENTS.md`
- `.agents/skills/`
