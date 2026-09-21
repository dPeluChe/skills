# dPeluChe/skills

> Agent skills born from real workflows, not theory.

I run ~80 repos as a solo builder plus a small studio ([Iteris](https://iteris.tech)). These
skills exist because I use them every day to keep that manageable. If a skill is here, it
earned its place in my actual workflow first.

The repo ships three things: the **skills**, **flowkit** (the CLI that installs and wires
them), and the **git hooks** flowkit serves to every repo you point it at.

## Skills

| Skill | What it does |
|-------|-------------|
| [`kickoff`](./skills/kickoff/) | Resume your own project: where you left off, real stack vs docs claims, git and PR state, routed findings. Onboarding skills brief strangers; this one briefs the returning owner |
| [`doctos`](./skills/doctos/) | Documentation hygiene: audits `.md` files, enforces root rules, archives obsolete docs, standardizes `docs/` structure or the one your repo declares |
| [`pm-tasks`](./skills/pm-tasks/) | Task lifecycle: audits `TASK_TODO.md`, archives completed work to monthly files, scans code and markdown for stray tasks, checks a completed task really shipped before archiving it |
| [`standup`](./skills/standup/) | Recent progress: what shipped, what is in flight, new pendings. Two cadences, closing a session and the weekly or client report |
| [`ship`](./skills/ship/) | Close one PR cycle with gates and evidence: identity check, lint, build, LOC and secret gates, quality pass, bookkeeping, merge per repo policy, evidence table |
| [`deploy-doctor`](./skills/deploy-doctor/) | Infra and deploy diagnosis: state checklist before any fix (what actually runs, ports, env, logs, external services), one hypothesis at a time, stop after 3 failed fixes |
| [`writer`](./skills/writer/) | Prose that sounds human: edits drafts to remove AI-slop patterns while keeping the author's voice, or audits without rewriting. Bilingual EN and ES. Derived from [no-ai-slop](https://github.com/petergyang/no-ai-slop) (MIT) |
| [`social-posts`](./skills/social-posts/) | Announcements from things already built: launch, feature, progress and insight modes, per-channel voice, claims verified, writer as the final pass. Drafts only, never publishes |

Each skill's `SKILL.md` is the full spec. They work standalone.

### What you get in every one

- **Boundaries are machine-enforced.** Each skill declares `allowed-tools`, so an analysis skill literally cannot rewrite your project.
- **Standard exit vocabulary.** Every report ends in `DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT`, consumable by scripts and by other skills.
- **Injection-guarded.** Scanned TODOs, commit messages and PR bodies are treated as data, never as instructions.
- **A project logbook.** `kickoff` and `standup` write dated, append-only entries to `docs/JOURNAL/`: how the project was found and how it moved, accumulated into memory the next session reads.
- **Read-only by default.** When a request is ambiguous, the skills pick their read-only mode. Nothing is moved, archived or written without showing you the plan first.
- **Tested before shipped.** Each one passed assertion-based evals and field tests on real repos before landing here.

### How they compose

Small skills that hand off to each other, not one mega-skill:

```
kickoff / standup ──▶ doctos      (scoped work orders: verify + act, no full audit)
        │        └──▶ pm-tasks    (scoped work orders: verify + act, no full audit)
        │
        └──────────▶ docs/JOURNAL/   (dated logbook: kickoff/standup write it,
                                      all four read it, shared project memory)
```

Routed findings are **scoped work orders**, not suggestions: invoked right after a kickoff or
standup, doctos and pm-tasks verify the routed list and act on that only. The full audit stays
for periodic hygiene passes. The journal is the shared bus.

The pipeline is optional. Typical rhythm: `kickoff` when resuming, a micro `standup` closing
each work session, `ship` to close a PR, the full `standup` at the end of the week.

**Accelerator.** `kickoff` and `standup` use [trs](https://usetrs.dev)
(`npm i -g @dpeluche/trs`) when it is installed: `trs ingest` produces structure and
dependency-graph digests in seconds instead of dozens of exploration calls. They degrade
gracefully without it.

## Install

```bash
git clone https://github.com/dPeluChe/skills.git
cd skills && make install     # links the skills chain + ~/bin/flowkit
```

From then on, from any directory:

```bash
flowkit help       # every subcommand, one line each
flowkit install    # re-sync skills after a git pull
flowkit check      # validate every link without touching anything (exit 0/1)
flowkit hooks      # wire the centralized git hooks into the repo you are standing in
flowkit hooks --verify   # check the EFFECTIVE hook state, including a live secret probe
```

Full CLI reference: [docs/GUIDES/FLOWKIT.md](./docs/GUIDES/FLOWKIT.md).

As a Claude Code plugin instead:

```bash
/plugin marketplace add dPeluChe/skills
/plugin install doctos@dpeluche-skills
```

## Git hooks

`flowkit hooks` wires centralized pre-commit and pre-push guarantees into any repo, served
from this one via lefthook `remotes`, so no config is copied and every wired repo stays in
sync. It covers secret scanning (gitleaks, with a canary that proves the hook actually
blocks), lint health, file size, and the Claude Code harness guards.

What it sets up and why: [docs/GUIDES/HOOKS.md](./docs/GUIDES/HOOKS.md).

## Documentation

Structure declared in [`.doctos.yml`](./.doctos.yml), index in [docs/README.md](./docs/README.md).

| Where | What |
|---|---|
| [`docs/GUIDES/FLOWKIT.md`](./docs/GUIDES/FLOWKIT.md) | The CLI: every subcommand, the manual `make` and script equivalents, versioning |
| [`docs/GUIDES/HOOKS.md`](./docs/GUIDES/HOOKS.md) | Hooks in depth: gitleaks rules, baselines, lint health, loc health, harness guards |
| [`docs/GUIDES/DESLOP_AND_HYGIENE_DOCTRINE.md`](./docs/GUIDES/DESLOP_AND_HYGIENE_DOCTRINE.md) | The editorial and hygiene doctrine behind `writer` and `doctos` |
| [`docs/FEATURES/`](./docs/FEATURES/) | Design notes on specific mechanisms (canary determinism, CI backstop) |

## Credits and prior art

All skills are original writing (MIT, © Antonio Martinez Quintero / dPeluChe), distilled from
real sessions. Two carry explicit lineage: `writer` derives from
[no-ai-slop](https://github.com/petergyang/no-ai-slop) (MIT); `ship` and `deploy-doctor`
studied patterns from [git-workflow-skill](https://github.com/netresearch/git-workflow-skill),
[claude-git-pr-skill](https://github.com/aidankinzett/claude-git-pr-skill),
[superpowers](https://github.com/obra/superpowers) and the systematic-debugging methodology.
Patterns, not copied content.

## Philosophy

1. **Real workflows only.** No speculative skills. Each one solved a recurring problem across my projects before being published.
2. **One skill, one job.** `doctos` organizes docs, `pm-tasks` manages tasks. They hand off to each other instead of overlapping.
3. **Convention over configuration.** Skills encode opinionated structures so every project looks the same, and a repo that wants its own declares it explicitly.
4. **Boring standard format.** Plain `SKILL.md` with [Agent Skills](https://agentskills.io) frontmatter. Works in Claude Code today, portable elsewhere.

## Writing your own

Start from [`template/SKILL.md`](./template/SKILL.md). Rules of thumb that work for me:

- The `description` must say **when to trigger**, not just what it does. Include the exact phrases a user would say, typos included.
- Write modes and steps as numbered procedures the agent can follow mechanically.
- Show the output format you expect (tables, report layouts). Agents match examples better than adjectives.
- Define boundaries with other skills explicitly ("X never touches Y's territory").

## License

MIT, see [LICENSE](./LICENSE).
