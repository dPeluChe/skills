# dPeluChe/skills

> Agent skills born from real workflows — not theory.

I run ~80 repos as a solo builder + small studio ([Iteris](https://iteris.tech)). These skills exist because I use them every day to keep that manageable. If a skill is here, it earned its place in my actual workflow first.

## Skills

| Skill | What it does |
|-------|-------------|
| [`kickoff`](./skills/kickoff/) | Resume-your-own-project analysis — where you left off, real stack vs docs claims, git/PR state, routed findings. (Onboarding skills brief strangers; kickoff briefs the returning owner) |
| [`doctos`](./skills/doctos/) | Documentation hygiene — audits .md files, enforces root rules, archives obsolete docs, standardizes `docs/` structure |
| [`pm-tasks`](./skills/pm-tasks/) | Task lifecycle — audits `TASK_TODO.md`, archives completed work to monthly files, scans code and markdown for stray tasks |
| [`standup`](./skills/standup/) | Recent-progress report — what shipped, what's in flight, new pendings; internal or client-facing |

### How they compose

Small skills that hand off to each other, not one mega-skill:

```
kickoff ──▶ doctos     (docs findings, filtered)
   │
   └──────▶ pm-tasks   (task findings, filtered)

standup  ◀── pm-tasks  (TASK_COMPLETED/ anchors "what shipped")
```

Each one works standalone; the pipeline is optional. Typical rhythm: `kickoff` when resuming a project, `doctos`/`pm-tasks` to act on what it found, `standup` at the end of the week.

**Accelerator**: `kickoff` and `standup` use [trs](https://usetrs.dev) (`npm i -g @dpeluche/trs`) when available — `trs ingest` produces structure + dependency-graph digests in seconds instead of dozens of exploration calls. They degrade gracefully without it.

More coming as they mature from daily use.

## Install

### Claude Code (plugin)

```bash
/plugin marketplace add dPeluChe/skills
/plugin install doctos@dpeluche-skills
```

### Manual (symlink — updates with `git pull`)

```bash
git clone https://github.com/dPeluChe/skills.git
cd skills && ./scripts/install.sh          # symlinks all skills to ~/.claude/skills
./scripts/install.sh doctos                # or just one
```

### Manual (copy — editable, frozen)

```bash
./scripts/install.sh --copy doctos
```

## Philosophy

1. **Real workflows only.** No speculative skills. Each one solved a recurring problem across my projects before being published.
2. **One skill, one job.** `doctos` organizes docs; `pm-tasks` manages tasks. They hand off to each other instead of overlapping.
3. **Convention over configuration.** Skills encode opinionated structures (UPPERCASE docs folders, monthly task archives) so every project looks the same.
4. **Boring standard format.** Plain `SKILL.md` with [Agent Skills](https://agentskills.io) frontmatter — works in Claude Code today, portable elsewhere.

## Writing your own

Start from [`template/SKILL.md`](./template/SKILL.md). Rules of thumb that work for me:

- The `description` must say **when to trigger**, not just what it does — include the exact phrases a user would say.
- Write modes/steps as numbered procedures the agent can follow mechanically.
- Show the output format you expect (tables, report layouts) — agents match examples better than adjectives.
- Define boundaries with other skills explicitly ("X never touches Y's territory").

## License

MIT — see [LICENSE](./LICENSE).
