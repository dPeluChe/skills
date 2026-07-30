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
flowkit hooks --verify   # check the EFFECTIVE hook state: config + hooksPath + merged jobs
                         # + gitleaks config in use + canary secret probe, exit 0/1
flowkit unhook     # clean removal from the current repo: stubs, OUR configs, OUR exclude entries
flowkit upgrade    # lefthook/gitleaks versions + clone freshness (exit 1 if pending);
                   # inside a wired repo it also refreshes that repo's lefthook remotes cache
flowkit about      # what flowkit is + this repo's detected flow status (for agents landing cold)
flowkit version    # flowkit 0.1.4 (<short sha>) — also --version / -v
```

`flowkit hooks` accepts `--team` and `--include-parent` — same semantics as the
installer (see [Hooks](#hooks-lefthook--gitleaks) below). The CLI is pure dispatch:
all logic lives in `scripts/install.sh`, so the alternatives below stay equivalent.

Versioning: the root `VERSION` file follows a `0.1.x` scheme, bumped manually per PR
that touches the tooling — PRs touching `bin/` `scripts/` `hooks/` bump VERSION patch.

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
its own `lint:` / `typecheck:` commands) if missing. The template is **stack-aware**: if the
repo has `.github/workflows/*.yml`, real lint/typecheck/build/test commands are extracted and
pre-filled (each marked `# from <workflow> -- verify`); otherwise the TODO examples match the
detected stack (Cargo.toml → cargo, package.json → npm, pyproject.toml → ruff/pytest,
go.mod → go). It also counts embedded code fences in
CLAUDE.md/AGENTS.md (agent instruction files reference paths, they don't embed code — the
ship config yaml fence is the one canonical exception) and recommends `/doctos` to clean up;
detection only, never blocks. If `docs/` looks like a **published site** (CNAME, index.html,
_config.yml, or a Pages workflow), that recommendation degrades to *findings only — do NOT
reorganize; fix in place*, and the same guard is a rule inside the doctos skill itself.

Baseline findings get **context labels**: a finding inside a `test`/`fixture`/`spec` file, or
whose line reads like a regex literal (`\b`, `[0-9A-Z]{`…), is tagged `[likely
detector/fixture]` and shows its REAL line in the report — everything else stays redacted.
The closing agent copy-block carries full detail per item: fence counts per file, baseline
`file:line` + label, and the stack's suggested ship-config commands ready to paste.

**What a baseline cannot see (field lesson).** A clean baseline means "no secret in THIS
repo's history" — not "no secret to rotate". A real leak that lived in a *base* repo you
forked or split from never appears here, so scanning this repo forever marks it resolved. If
a credential was ever exposed anywhere, rotating it at the provider console stays a human
action; gitleaks green is not a rotation receipt.

**Verify a repo-local `.gitleaks.toml` actually loads.** A malformed local config (e.g. an
`AllowList` as a list where gitleaks expects a map) makes gitleaks fail to load and the scan
pass **green without checking anything** — a false green worse than no rule. After adding or
editing a repo-local config, run `flowkit hooks --verify`: the canary stages a synthetic
secret and confirms the effective hook actually blocks it. A rule you have not watched go red
is not verified.

**Writing ABOUT a secret-shaped string** (documenting why a finding is benign, a false
positive, or public-by-design) trips the same scan that flagged it — you cannot record the
"why" without re-triggering. Append an inline `gitleaks:allow` comment to that specific line
(`# gitleaks:allow`, `// gitleaks:allow`, `<!-- gitleaks:allow -->`): gitleaks skips exactly
that line, so the explanation can live next to the value. For the harness `secret-guard`
(which runs on Edit/Write before a file exists), the same inline marker on the line is
honored via `hooks/.gitleaks.toml`. Do NOT weaken a rule to document one string.

### Repo-local gitleaks rules (`.gitleaks.toml`)

The central `hooks/.gitleaks.toml` covers the token shapes that circulate across these repos
(dpat_/GitHub-PAT/AWS/Sentry/Postgres/ITERIS) plus the gitleaks defaults and a docs allowlist.
**Most repos need no repo-local config** — if yours only consumes standard tokens (JWT, BYO
keys the user types and never commits), the central rules already cover it; adding a local
file would only *remove* coverage. Add one **only** when your project mints its OWN format
that none of the central rules match (field case: 40-char alphanumeric CSPRNG tokens sail
through a central scan as "no leaks found"). When present, the repo-local `.gitleaks.toml`
**replaces** the central one for the pre-commit scan, the install baseline and the verify
canary — so it must carry its own coverage forward. Recommended pattern:

```toml
title = "my-project rules"

[extend]
useDefault = true          # keep the full gitleaks default ruleset

[[rules]]
id = "my-project-token"
description = "my-project 40-char CSPRNG token"
regex = '''\b[a-f0-9]{40}\b'''
```

Honest note on precedence: the repo-local file **replaces** the central config. gitleaks
`[extend]` can also chain to a `path`, but the central file lives in a per-machine lefthook
cache (`.git/info/lefthook-remotes/…`), so extending it by path is **NOT portable** — a
repo-local config should either redeclare the central rules it cares about or accept
defaults + its own rules. When a repo has no `.gitleaks.toml`, `flowkit hooks` adds a
one-line nudge to the agent copy-block; the file is never stamped automatically — whether a
generic fixed-length regex is worth its false positives is the project's decision.

**The install ends with an honest verification** (`flowkit hooks --verify`) that measures
**efficacy, not just wiring**: config present; the hooks git will *actually run* (the
effective `core.hooksPath`) invoke lefthook for pre-commit, pre-push AND commit-msg; the
**merged config resolves real jobs** (`lefthook dump` — a repo with only the personal
`lefthook-local.yml` overlay merges ZERO jobs and the gate is silently inert: verify names
exactly that state); which gitleaks config is in use (repo-local `.gitleaks.toml` vs
central); and a **canary probe**: a synthetic AWS-style key is staged in an *isolated*
temporary index (`GIT_INDEX_FILE` — the real index is never touched, the temp index is
removed) and the **effective pre-commit hook** — the exact file git executes
(`core.hooksPath` local > global > `.git/hooks`) — is run against it. The verdict is the
hook's: exit ≠ 0 **plus** explicit "leaks found" evidence (a crash without evidence is not a
working gate; exit 0 means the commit would have sailed through). One pass covers
config → hooksPath → lefthook → merged jobs → gitleaks, so a placebo state (stubs wired,
zero jobs merged) fails by canary, not just by the jobs diagnostic — which stays, because it
*names* the cause the canary only detects. No effective pre-commit hook at all is its own
FAIL. In particular, a repo whose LOCAL `core.hooksPath` points at a tracked
hooks dir (e.g. a versioned `.githooks/`) gets a plain **"hooks NOT active in this repo"**
with the two ways out: PR the exact lefthook delegation line into the project's own hooks,
or skip consciously. No false "wired ok". `--verify` also flags **orphan stubs** (lefthook
hooks with no resolvable config — they break every push) and points to `flowkit unhook`.

A deliberate gap is a decision, not a permanent failure: declare it inside the
`## ship config` block of CLAUDE.md as a nested map —

```yaml
hooks_skip:
  pre-push: "CI runs the same lint on every push"
```

— and `--verify` reports `ok pre-push (skipped: reason)` instead of failing forever on a
hook the project consciously does not run (the canary is skipped too when pre-commit itself
is the declared gap). The one-line `hooks_skip: pre-push: "reason"` form is also accepted;
any *other* shape (e.g. a flow list) gets a loud `hooks_skip present but unparseable --
declaration ignored` warning — a security declaration is never dropped in silence.

`flowkit unhook` is the clean exit: removes the lefthook stubs from the effective hooksPath
and `.git/hooks`, deletes OUR config files (`lefthook.yml`/`lefthook-local.yml` referencing
this repo — a tracked or foreign one is respected with a notice), clears our
`.git/info/exclude` entries, and reports a table of everything removed.

**Team repos (`--team`) stay portable**: the `FLOW_CLAUDE.md` import references a
machine-local path, so it goes to `CLAUDE.local.md` (supported by Claude Code, added to
`.git/info/exclude`) — the committed CLAUDE.md only receives the portable `## ship config`
block. The baseline asks *"share baseline with team (commit) or keep personal (git
exclude)? [s/P]"* — default personal (`.git/info/exclude`); answer `s` to commit
`.gitleaks-baseline.json` so the whole team grandfathers the same findings. Solo mode keeps
today's behavior (import in CLAUDE.md, baseline committable).

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
never pulls for you; when behind it suggests `git pull && make install`. Run from inside a
**wired** repo, it additionally runs `lefthook install` there to refresh that repo's remotes
cache ("remotes refreshed") so a just-merged hooks change lands now instead of after the 24h
refetch window.

Four layers, increasing cost:

| Layer | Budget | What runs |
|---|---|---|
| commit-msg | <1s | strips agent attribution trailers (Co-authored-by / Generated with / 🤖 footers) — authorship stays human: the person is the author, agents are tools |
| pre-commit | <2s | gitleaks on staged (repo-local `.gitleaks.toml` wins over the central config) · hard block on staged `.env*` (except `.env.example`) · LOC warning >500 lines (never blocks) |
| pre-push | <30s | the repo's own `lint:` / `typecheck:` read from its `## ship config` block — fail-soft warning if absent; docs-only and deletion-only pushes skip · docs nudge when code is pushed with zero `.md` touched (never blocks) |
| `/ship` | minutes | full gate ritual: lint 0 warnings, build/tests, LOC, secret scan on the diff, quality pass, evidence table |
| CI | async | whatever the repo's pipeline adds on top — hooks complement CI, never replace it |

**Known gap — pre-push scope is staged/pushed, CI scope is the whole tree.** The pre-push
`lint:` runs the repo's own command as declared; if that command is staged-scoped (only the
files in the push), a warning that a change *propagates* into a file the commit didn't touch
(e.g. a type edit whose inference ripples) passes the hook and fails a full-scope CI. This is
structural, not a bug: the hook is first-line defense over *what you push*, never a substitute
for CI's full-tree pass. Two honest options per repo: (a) declare a full-scope `lint:` in
`## ship config` and accept the extra seconds, or (b) keep it staged-fast and let CI be the
backstop. flowkit does not choose for you — it runs what the block declares.

**CI backstop (planned, not yet generated).** The one layer flowkit does not wire yet is the
CI pass. When it lands it will be **generated from the same `## ship config` block** the hooks
read — never hand-written in a separate `ci.yml`. Rationale from a field report: a repo whose
gate list was duplicated across `pre-commit` and `ci.yml` drifted, and a fixer step (`prettier
--write`) that exits 0 without converging shipped a file CI then rejected. One source the hooks
and CI both consume is the only structure that cannot diverge — the same anti-divergence
principle behind reading commands from `## ship config` instead of copying them.

`merge_policy` (read by `/ship`) binds only the ship skill — a web merge or `gh pr merge`
bypasses it entirely. It is the reminder, not the lock; the lock is server-side branch
protection (require PR + approval), worth enabling once per supervised repo. Enforcement
scale: memory < tool-read config < server-side protection < compiler invariant.

Hook output is pinned compact (`output: [summary, execution_out, failure]` in
`hooks/lefthook-base.yml`): jobs print only their real output plus the short summary — no
ASCII banner burying the one error that matters when stdout is redirected. lefthook cannot
condition output on TTY from config, so compact is the permanent mode; humans read it
faster too.

On agent attribution: the first line of defense is `includeCoAuthoredBy: false` in Claude
Code settings; the commit-msg hook is the net for configs that drift or agents that ignore
it. If stripping would empty the whole message, the original is kept untouched.

### Harness hooks (Claude Code)

Git hooks catch bad commits; these two PreToolUse guards catch the agent's tool call
before it runs. `git-guard.sh` (matcher `Bash`) blocks destructive git — `push --force`
(`--force-with-lease` passes), `reset --hard`, `clean -f`, `branch -D`, `filter-branch`,
`stash drop/clear`, `checkout -- .`, `update-ref -d` — plus our own bypasses `--no-verify`
and `LEFTHOOK=0` (detected only in ASSIGNMENT position on the command — a prose mention in
a PR body or echo is data, never a trigger); escape hatch for a human-approved case:
`FLOWKIT_GIT_GUARD=off` (from the environment or assigned on the command itself).
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
