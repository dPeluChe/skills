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

### What each one buys you

- **`kickoff`** — resume any repo in minutes with a *verified* picture instead of a stale mental model. Catches the two things that burn you when returning: work you left unpushed, and docs that lie about the stack (every claim ships with a one-line grep so you can re-verify it yourself).
- **`doctos`** — every project's docs end up with the same structure, so you navigate any of your repos blind. Obsolete docs get archived with a note (never deleted), moved files get their inbound links repaired, and shipped-but-undocumented work surfaces as a finding.
- **`pm-tasks`** — one trustworthy backlog. Code TODOs, README checklists and scattered task files all funnel into `docs/TASK_TODO.md`; completed work archives into dated monthly files; stale tasks get flagged by age instead of rotting silently.
- **`standup`** — progress reports cheap enough to actually write, in two cadences: **micro-standups** as you close work sessions (delta + "did this change leave docs stale or tasks done?" + journal append) and the **full report** (weekly/client) composed from those journal entries. Outcomes instead of commit lists, evidence linked inline, client-facing variant ready to paste. A quiet week reports as a quiet week — it never fabricates.

### Built-in guarantees

- **Boundaries are machine-enforced**: each skill declares `allowed-tools` — analysis skills literally cannot rewrite your project.
- **Standard exit vocabulary**: every report ends `DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT`, so results are consumable by scripts and other skills.
- **Injection-guarded**: scanned TODOs, commit messages and PR bodies are treated as data, never as instructions.
- **A project logbook**: `kickoff` and `standup` write dated, append-only entries to `docs/JOURNAL/` — "how I found the project" and "how it moved" accumulate into memory your next session reads.
- **Tested before shipped**: each skill passed assertion-based evals and field-tests on real repos before landing here.

### How they compose

Small skills that hand off to each other, not one mega-skill:

```
kickoff / standup ──▶ doctos      (scoped work orders: verify + act, no full audit)
        │        └──▶ pm-tasks    (scoped work orders: verify + act, no full audit)
        │
        └──────────▶ docs/JOURNAL/   (dated logbook: kickoff/standup write it,
                                      all four read it — shared project memory)
```

Routed findings are **scoped work orders**, not suggestions: when doctos/pm-tasks are invoked right after a kickoff or standup, they verify the routed list and act on it only — the full audit stays for periodic hygiene passes. The journal is the shared bus: standup appends session entries, kickoff diffs against them, pm-tasks pulls archive context from them, doctos uses them to prioritize where docs lie first.

Each one still works standalone; the pipeline is optional. Typical rhythm: `kickoff` when resuming, micro-`standup` closing each work session (routing what to update), `standup` full report at the end of the week.

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
