# Plan 012: Port `project-standards` governance skill for Notinhas

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 415d662..HEAD -- .agents AGENTS.md`
> Require plan 010 DONE (skills rebased). If `project-standards` already exists, STOP and reconcile instead of duplicating.
> If in-scope files changed since this plan was written, re-read live excerpts before proceeding.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: `plans/010-rebase-skills-notinhas.md`
- **Category**: docs / dx
- **Planned at**: commit `415d662`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `no` — must follow skill rebase; blocks plan 011
- **Reviewer required**: `yes` — governance must not contradict Snapzy `docs/` reality
- **Rationale**: Small markdown additions (`project-standards`, `SKILLS_INDEX.md`, AGENTS section) with an explicit adaptation brief from vozinha (no Prisma/Makefile copy-paste).
- **Escalate when**: operator wants GitHub `known-limitation` label automation that the repo cannot support, or wants to delete upstream `docs/`.

## Why this matters

Even after rebasing skills, nothing prevents the next agent from adding a fourth docs home, inventing Makefile targets, or letting `AGENTS.md` drift from `.agents/skills`. Vozinha’s `project-standards` skill is the governance pattern: one owner for where guidance lives, how skills are structured, and how knowledge is routed. Porting it — adapted to Notinhas/Snapzy — locks in the rebase and gives plan 011 a template to follow.

## Current state

- Source to adapt (read-only reference on disk): `/Users/usuario/Documents/Projects/vozinha/.agents/skills/project-standards/SKILL.md`
- That file is written for **Prisma/vozinha** (`make guidance-check`, MeetingAssistantCore modules, “No Root docs/”, audio model residency, SettingsDrillDownListRow, etc.). **Do not copy it verbatim.**
- Notinhas today:
  - `AGENTS.md` is canonical for agents but has **no** skills routing section.
  - `.agents/SKILLS_INDEX.md` is **missing** (old Picker documentation skill referenced it).
  - Upstream `docs/` **exists** (~22 engineering docs: `CAPTURE.md`, `ANNOTATE.md`, …) — keep it.
  - Commands live under `scripts/` (no Prisma `Makefile` guidance-check in this repo).
  - After plan 010: 13 skills are Notinhas-correct but unregistered in an index.
- Commit style already Conventional (`feat(notinhas): …`).
- Fork remotes documented in `AGENTS.md`: `origin` = `mourato/Notinhas`, `upstream` = `duongductrong/Snapzy`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Precondition | `rg -n -i 'Picker\|FontLoader\|\\./build\\.sh' .agents/skills \| head` | no matches (001 done) |
| Create skill | `mkdir -p .agents/skills/project-standards` | dir exists |
| Index exists | `test -f .agents/SKILLS_INDEX.md` | exit 0 after step |
| AGENTS skills section | `rg -n '## Skills|SKILLS_INDEX' AGENTS.md` | matches after step |
| Count skills | `ls -1 .agents/skills \| wc -l` | `14` (13 + project-standards) before plan 011 |

## Suggested executor toolkit

- Open vozinha’s skill only as a structure reference for section headings.
- Prefer Notinhas vocabulary from `AGENTS.md` (visual handoff, Snapzy fork, thin Notinhas module).

## Scope

**In scope**:
- Create `.agents/skills/project-standards/SKILL.md` (Notinhas-adapted)
- Create `.agents/SKILLS_INDEX.md` listing all skills after 010, plus `project-standards`, plus a **placeholder** row for `capture-annotate-export` (status: planned / not yet added — plan 011 fills it)
- Update `AGENTS.md` with a concise **Skills** section pointing at the index and ownership rules
- Light touch to `.agents/skills/documentation/SKILL.md` only if needed so it no longer claims a missing index without creating one (after this plan the index exists — update documentation skill Related/ownership lines to match)

**Out of scope**:
- Creating `capture-annotate-export` body (plan 011)
- Adding `make guidance-check`, deleting `docs/`, or importing Prisma module layout rules
- Creating GitHub labels or issues unless operator later asks
- Swift code changes
- Re-rebasing the 13 skills (001)

## Git workflow

- Branch: `advisor/012-project-standards`
- Commit example: `docs(agents): add project-standards skill and skills index`
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Confirm plan 010 completion

```bash
rg -n -i 'Picker|FontLoader|Grab Font|Sources/Picker|\./build\.sh|picker\.picked' .agents/skills
test ! -f .agents/skills/project-standards/SKILL.md
ls -1 .agents/skills | wc -l
```

**Verify**: leakage empty; `project-standards` absent; skill dir count is `13`.

### Step 2: Author Notinhas `project-standards` skill

Create `.agents/skills/project-standards/SKILL.md` using this required substance (English):

**YAML**
- `name: project-standards`
- `description:` must trigger on updating `AGENTS.md`, documenting project policy, aligning repository standards, skill registry hygiene, or known-limitation tracking.

**Body must include**

1. **Role** — canonical owner of project-level guidance governance for Notinhas (not Prisma).
2. **Scope Boundary** — AGENTS/skills/index policy only; implementation details stay in domain skills; delivery commands stay in `delivery-workflow`.
3. **When to Use** — AGENTS updates, skill authorship, docs routing questions, stale guidance cleanup.
4. **Limitation tracking** — prefer GitHub issues (via `gh`) for backlog/known limitations; do **not** create `KNOWN_LIMITATIONS.md`; if the repo lacks a `known-limitation` label, note that agents may use issue titles/body tags instead of inventing label automation.
5. **Agent documentation**
   - `AGENTS.md` is living agent policy.
   - Skill template section order: Role, Scope Boundary, When to Use, domain guidance, Verification (when relevant), Related Skills, References.
   - Keep `reuse → extend → create` for Notinhas helpers.
   - Clean registry: audit `.agents/skills` for stale/Picker leakage periodically.
   - Command surface sync: when `scripts/*` change, update `AGENTS.md` + `delivery-workflow` in the same change.
6. **Information routing (adapted — critical difference from vozinha)**
   - Reusable agent/ops guidance → `.agents/skills/…`
   - Durable agent policy → `AGENTS.md`
   - Upstream Snapzy engineering narrative → existing `docs/` (CAPTURE, ANNOTATE, …). **Do not** ban `docs/`; **do not** create a second parallel Notinhas-only docs tree for the same topics.
   - Pending work → GitHub issues, not new markdown backlog files at repo root.
   - Generated reports → `/tmp` or `.agents/reports/` (create dir only when needed).
7. **Consistency** — Conventional Commits; preserve Notinhas modules across `upstream` merges; UI changes note manual capture/annotate/clipboard checks.
8. **Evolution** — when a skill owner, script, or validation rule changes, update AGENTS + owning skill + index together; prefer deleting stale guidance over stacking duplicates.
9. **Language** — English for docs and code comments.
10. **Related** — `documentation`, `delivery-workflow`, and (placeholder ok) `capture-annotate-export`.
11. **Explicitly omit** Prisma-only rules: MeetingAssistantCore modules, `make guidance-check` / `make preview-check`, audio model residency, SettingsDrillDownListRow, “No Root docs/” absolute ban.

**Verify**:

```bash
rg -n 'Prisma|MeetingAssistantCore|make guidance-check|No Root `docs/`|modelResidencyTimeout|SettingsDrillDownListRow' .agents/skills/project-standards/SKILL.md
```

**Expected**: no matches.

```bash
rg -n 'docs/|AGENTS.md|SKILLS_INDEX|Conventional' .agents/skills/project-standards/SKILL.md
```

**Expected**: hits showing adapted routing.

### Step 3: Create `.agents/SKILLS_INDEX.md`

Create a compact catalog with columns: Skill | Owns | Reach for when…

Include all current skills after 001 plus `project-standards`. Add a clearly marked placeholder:

| `capture-annotate-export` | Visual handoff loop | *(planned — see `plans/011-capture-annotate-export-skill.md`)* |

Also include a short routing note: prefer the narrowest domain skill; use `project-standards` for governance; use `delivery-workflow` for commands.

**Verify**:

```bash
test -f .agents/SKILLS_INDEX.md
rg -n 'project-standards|delivery-workflow|capture-annotate-export' .agents/SKILLS_INDEX.md
wc -l .agents/SKILLS_INDEX.md
```

Index exists; lists governance + placeholder; keep it concise (roughly under ~120 lines).

### Step 4: Add Skills section to `AGENTS.md`

Append (or insert after Product Intent / Structure) a short section, for example:

```markdown
## Skills

Agent skills live under `.agents/skills/`. Start at `.agents/SKILLS_INDEX.md` for routing.
`project-standards` owns guidance governance (where docs live, skill template, anti-drift).
Keep Notinhas behavior guidance aligned with Product Intent above; do not reintroduce
unrelated product skills from other apps.
```

Do not duplicate the full index into `AGENTS.md`.

**Verify**:

```bash
rg -n 'SKILLS_INDEX|project-standards' AGENTS.md
```

### Step 5: Align `documentation` skill ownership lines

Edit `.agents/skills/documentation/SKILL.md` so it:
- Points to the now-real `.agents/SKILLS_INDEX.md`
- Describes `AGENTS.md` without claiming Picker loupe/fonts routing
- Does not require a `CLAUDE.md` symlink unless you also create it; preferred: mark `CLAUDE.md` as optional

**Verify**:

```bash
rg -n 'SKILLS_INDEX|CLAUDE|Picker|Grab Font|\./build\.sh' .agents/skills/documentation/SKILL.md
```

Must mention `SKILLS_INDEX`; must not reintroduce Picker/`./build.sh`/`Grab Font`.

### Step 6: Final counts and index status

```bash
ls -1 .agents/skills | sort
```

**Expected dirs** (14): the original 13 + `project-standards` (still **no** `capture-annotate-export` directory).

Update `plans/README.md` row 012 → DONE.

## Test plan

- Docs-only.
- Mechanical: Prisma leakage scan on the new skill (Step 2); index + AGENTS cross-links (Steps 3–4).
- Human: confirm routing still allows editing `docs/CAPTURE.md` when capture flows change (governance must not forbid it).

## Done criteria

- [ ] `.agents/skills/project-standards/SKILL.md` exists and contains zero Prisma/Makefile-specific rules listed in Step 2
- [ ] `.agents/SKILLS_INDEX.md` lists rebased skills + `project-standards` + placeholder for `capture-annotate-export`
- [ ] `AGENTS.md` links to the skills index / `project-standards`
- [ ] `documentation` skill no longer references a missing index as if present-without-creating-it
- [ ] Skill directory count is 14 (not 15)
- [ ] No Swift changes
- [ ] `plans/README.md` row for 012 is DONE

## STOP conditions

- Plan 010 not complete (Picker leakage still present).
- Operator insists on deleting or freezing all of `docs/` like vozinha — that conflicts with this fork; STOP for human decision.
- `project-standards` already exists with different policy — reconcile rather than overwrite silently.
- Need to invent `make guidance-check` because the skill “feels incomplete” — do not; this repo has no such target.

## Maintenance notes

- Plan 011 must replace the index placeholder and add the real skill directory.
- Reviewers: any new skill PR should update `SKILLS_INDEX.md` + owning Related links in the same change (this skill’s rule).
- Every ~90 days (or after major upstream merges), audit skills for Snapzy drift and Picker noun regression.
