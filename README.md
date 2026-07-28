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
| [`writer`](./skills/writer/) | Human-sounding prose — edits drafts to remove AI-slop patterns while preserving the author's voice, or audits without rewriting. Bilingual EN/ES. Derived from [no-ai-slop](https://github.com/petergyang/no-ai-slop) (MIT) |
| [`social-posts`](./skills/social-posts/) | Product announcements from things already built — launch/feature/avance/insight modes, per-channel voice (X/LinkedIn/FB), claims verified, writer as final pass. Drafts only, never publishes |
| [`ship`](./skills/ship/) | PR closing with gates and evidence — identity check, lint/build/LOC/secret gates, quality pass, bookkeeping, PR on the current branch, merge per repo policy (auto/ask), evidence table |
| [`deploy-doctor`](./skills/deploy-doctor/) | Infra/deploy diagnosis — state checklist before any fix (what actually runs, ports, env, logs, external services), one hypothesis at a time, stop after 3 failed fixes, root cause becomes a persistent rule |

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

### flowkit (recommended)

`flowkit` is the CLI for this repo — a generic manager for the skills + hooks + flow
layer. Install once and every operation (sync, doctor, hook wiring, upgrades) is one
command from any directory: `make install` links the skills chain AND drops a
`flowkit` symlink into `~/bin` (it warns with the exact `~/.zshrc` line if `~/bin`
is not in your PATH).

```bash
git clone https://github.com/dPeluChe/skills.git
cd skills && make install   # skills chain + ~/bin/flowkit

# from then on, from ANY directory:
flowkit help       # subcommands, one line each
flowkit install    # re-sync skills after a git pull
flowkit check      # doctor: validate every link without touching anything (exit 0/1)
flowkit prune      # sync + remove dead links left by renamed/deleted skills
flowkit hooks      # wire centralized git hooks into the repo you're standing in
flowkit upgrade    # lefthook/gitleaks versions + clone freshness (exit 1 if pending)
```

`flowkit hooks` accepts `--team` and `--include-parent` — same semantics as the
installer (see [Hooks](#hooks-lefthook--gitleaks) below). The CLI is pure dispatch:
all logic lives in `scripts/install.sh`, so the alternatives below stay equivalent.

### Claude Code (plugin)

```bash
/plugin marketplace add dPeluChe/skills
/plugin install doctos@dpeluche-skills
```

### Manual (make / scripts — alternative)

```bash
cd skills && ./scripts/install.sh          # links all skills (chain: ~/.claude/skills → ~/.agents/skills → repo)
./scripts/install.sh ship                  # or just one
./scripts/install.sh --check               # doctor: validate every link without touching anything (exit 0/1)
./scripts/install.sh --prune               # also remove dead links left by renamed/deleted skills
./scripts/install.sh --copy doctos         # copy instead of link (editable, frozen)
```

The chain goes through `~/.agents/skills` as a shared hub so other agent harnesses
can serve the same skills; the script creates both hops and is idempotent — run it
(or `flowkit install`) after every `git pull` that adds skills. `--check` also
validates the `~/bin/flowkit` link.

The `Makefile` wraps the same flows — `make help` lists them:

```bash
make install    # ./scripts/install.sh (also links ~/bin/flowkit)
make check      # ./scripts/install.sh --check
make prune      # ./scripts/install.sh --prune
make upgrade    # ./scripts/install.sh --upgrade
make harness    # ./scripts/install.sh --harness (Claude Code PreToolUse guards)
make test       # bash scripts/test-hooks.sh
```

## Hooks (lefthook + gitleaks)

Centralized git hooks served FROM this repo via lefthook `remotes` (refetched at most every
24h): every wired repo gets the same pre-commit/pre-push guarantees without copying config.

```bash
flowkit hooks [--team] [--include-parent]   # from inside the target repo (wires $PWD)
# equivalents from this repo's clone:
make hooks REPO=/path/to/repo           # solo repo → writes lefthook.yml
make hooks REPO=/path/to/repo TEAM=1    # team repo → lefthook-local.yml (globally ignored)
./scripts/install.sh --repo /path/to/repo [--team]
```

The installer checks minimum versions (lefthook ≥ 1.10, gitleaks ≥ 8.19), chains after an
existing husky setup instead of replacing it, builds a one-time gitleaks baseline
(`.gitleaks-baseline.json`) with a findings summary, links `FLOW_CLAUDE.md` into the target
repo's CLAUDE.md, and stamps a `## ship config` template (the block where each repo declares
its own `lint:` / `typecheck:` commands) if missing. It also counts embedded code fences in
CLAUDE.md/AGENTS.md (agent instruction files reference paths, they don't embed code — the
ship config yaml fence is the one canonical exception) and recommends `/doctos` to clean up;
detection only, never blocks.

Pointing `--repo` at a **workspace** (a git repo whose 1st-level children are git repos
themselves) wires every child instead — same solo/team logic per child, closing with a
child → result table. The parent is skipped by default (workspace roots carry their own
no-commit locks); add `--include-parent` to wire it too.

A global `core.hooksPath` is not a blocker when it holds **chain wrappers** (files that
delegate to `$(git rev-parse --git-dir)/hooks/<hook>`): the installer verifies pre-commit
and pre-push wrappers and installs the lefthook stubs into the repo's local `.git/hooks`,
where the chain picks them up. Missing wrappers fail the install with the culprit named.

`make upgrade` (or `./scripts/install.sh --upgrade`) reports installed lefthook/gitleaks
versions against the required minimums (plus `brew outdated` when brew exists) and how many
commits your clone sits behind `origin/main` — exit 0 all fresh, 1 something pending. It
never pulls for you; when behind it suggests `git pull && make install`.

Four layers, increasing cost:

| Layer | Budget | What runs |
|---|---|---|
| commit-msg | <1s | strips agent attribution trailers (Co-authored-by / Generated with / 🤖 footers) — authorship stays human: the person is the author, agents are tools |
| pre-commit | <2s | gitleaks on staged · hard block on staged `.env*` (except `.env.example`) · LOC warning >500 lines (never blocks) |
| pre-push | <30s | the repo's own `lint:` / `typecheck:` read from its `## ship config` block — fail-soft warning if absent; docs-only and deletion-only pushes skip · docs nudge when code is pushed with zero `.md` touched (never blocks) |
| `/ship` | minutes | full gate ritual: lint 0 warnings, build/tests, LOC, secret scan on the diff, quality pass, evidence table |
| CI | async | whatever the repo's pipeline adds on top — hooks complement CI, never replace it |

On agent attribution: the first line of defense is `includeCoAuthoredBy: false` in Claude
Code settings; the commit-msg hook is the net for configs that drift or agents that ignore
it. If stripping would empty the whole message, the original is kept untouched.

### Harness hooks (Claude Code)

Git hooks catch bad commits; these two PreToolUse guards catch the agent's tool call
before it runs. `git-guard.sh` (matcher `Bash`) blocks destructive git — `push --force`
(`--force-with-lease` passes), `reset --hard`, `clean -f`, `branch -D`, `filter-branch`,
`stash drop/clear`, `checkout -- .`, `update-ref -d` — plus our own bypasses `--no-verify`
and `LEFTHOOK=0`; escape hatch for a human-approved case: `FLOWKIT_GIT_GUARD=off`.
`secret-guard.sh` (matcher `Edit|Write`) runs the content through gitleaks with
`hooks/.gitleaks.toml` (regex fallback when gitleaks is absent) and refuses `.env*`
targets outright. `make harness` symlinks `~/.agents/hooks-harness` and merges both
entries into `~/.claude/settings.json` (idempotent; backup to `settings.json.bak` first);
`make check` validates them once installed.

## Credits & prior art

All skills are original writing (MIT, © Antonio Martinez Quintero / dPeluChe), distilled
from my real sessions. Two carry explicit lineage: `writer` derives from
[no-ai-slop](https://github.com/petergyang/no-ai-slop) (MIT); `ship` and `deploy-doctor`
studied patterns from [git-workflow-skill](https://github.com/netresearch/git-workflow-skill),
[claude-git-pr-skill](https://github.com/aidankinzett/claude-git-pr-skill),
[superpowers](https://github.com/obra/superpowers) and the systematic-debugging methodology —
patterns, not copied content.

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
