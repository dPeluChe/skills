---
name: ship
description: >
  Close a work cycle as a PR with mechanical gates and verifiable evidence: repo/branch identity
  check, lint 0 warnings, build/tests, LOC limit, secret scan on the diff, quality pass, task
  bookkeeping, PR on the CURRENT branch, and a merge step governed by the repo's merge policy
  (auto | ask) — ending with an evidence table (command + output, PR #, merge SHA). Use whenever
  the user wants to close/ship work as a PR: "haz pr merge", "cerremos los prs", "hagamos
  elmerge", "cierra este pr", "listo para merge?", "hay que hacer el pr", "valida lint y build y
  haz el pr", "ship it", "/ship". The user almost never types the slash — trigger from informal
  prose and typos. Disambiguation: standup closes a SESSION (journal delta across PRs); ship
  closes ONE PR cycle with gates — ship's evidence table is input for standup's journal entry.
  /simplify is a quality pass ship INVOKES; pm-tasks does the task archiving ship DELEGATES.
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, Skill
---

# Ship — PR closing with gates and evidence

Turns the user's dictated ritual (lint → build → review → PR → merge → bookkeeping) into one
mechanical flow. Every "done" claim carries its command and output — the report kills the
"¿seguro? ¿ya todo?" round-trips.

## Why this exists

Corpus evidence (~250 sessions): the same ritual dictated in prose 5-8 messages per cycle,
dozens of times; regressions shipped by skipping pre-push validation; branches created without
being asked; PRs merged (or left open) against the user's standing instruction for that repo;
real secrets (PATs, DB passwords, cloud keys) pasted into diffs and chats.

## Step 0: Identity gate (before anything else)

The workspaces bundle several repos in one tree (e.g. `workspace-dpeluche/` contains
`dpeluche.dev/`, `skills/`, and is ITSELF a git repo). The shell may reset cwd between commands.
Verify — and re-verify after any `cd`:

```bash
pwd && git rev-parse --show-toplevel   # am I in the repo I think I'm in?
git remote get-url origin              # does origin match the intended project?
git branch --show-current              # on the branch I think I'm on?
```

- If the git root is the WORKSPACE root but the work targets a child repo → cd into the child
  repo and re-verify. Never commit to the workspace root unless that IS the task.
- If the current branch is a protected main → create the feature branch is NOT the fix here:
  STOP and ask (the "never create branches unprompted" rule below still holds; moving existing
  commits to a branch is a recovery the user should see).
- Use absolute paths or `cd <repo> && ...` in every command. One compound command = one cwd.

## Config per repo (read from CLAUDE.md, fail loud on gaps)

Read the repo's CLAUDE.md for a `ship` config block. **Canonical format** (one schema so every
repo writes it the same way — without it the skill falls back to detect-and-confirm):

```yaml
# ship config
lint: npm run lint
build: NEXT_BUILD_DIR=.next-ci npm run build   # isolated variants welcome
test: npm run test                              # omit if none
merge_policy: auto                              # auto | ask (default ask)
required_proofs:
  - when: "convex/mcp*"                         # glob over touched files
    run: node scripts/mcp-smoke.mjs             # must exit 0 before merge
loc_limit: 500
simplify: 500   # run /simplify only if changed LOC > N (off = only on request)
reviewer: rigo                                  # team repos only
release_prefix: "STAGING RELEASE:|PROD RELEASE:" # only where applicable
branch_cleanup: delete                          # delete | keep | ask
```

Key semantics, with defaults only where safe:

- `lint` / `build` / `test` commands — **no safe default**: if absent, detect from manifest
  scripts and CONFIRM with the user once; never guess silently. Respect overrides like isolated
  build dirs (e.g. `NEXT_BUILD_DIR=.next-ci npm run build` — a normal build there kills the
  user's running dev server).
- `merge_policy: auto | ask` — default **ask**. `auto` = merge immediately once ALL gates and
  required proofs pass (the user's standing instruction in some solo repos: "no dejes los prs
  abiertos"). `ask` = draft → show exactly what will run → explicit OK → execute. Team repos and
  supervised flows are `ask` even if the session feels fluid.
- `required_proofs` — per-repo/per-area field tests that must pass BEFORE merge regardless of
  policy (e.g. "convex/mcp* touched → run scripts/mcp-smoke.mjs, exit 0"). Heavier flows declare
  heavier proofs; a green build is not proof that the feature works.
- `loc_limit` (default 500) · `simplify` (default 500; `off` = only on request) ·
  `reviewer` (team repos) · `release_prefix` rules ·
  `branch_cleanup: delete | keep | ask` (default ask).

## Step 1: Pre-gates (mechanical; any failure = stop with report)

1. **Lint**: repo's lint command, 0 errors AND 0 warnings; no new `eslint-disable` (or
   equivalent) introduced by the diff.
2. **Build/tests**: repo's commands, exit 0. Use the configured isolated variant when declared.
3. **LOC**: a file over `loc_limit` that IS part of the current work → do the split RIGHT
   THERE, same branch, same cycle, before creating the PR (the split is part of the work — not
   a separate PR). A legacy file over the limit that was barely touched or only detected in
   passing → do NOT block: create a task in docs/TASK_TODO.md (via pm-tasks) so it isn't lost,
   and continue.
4. **Secret scan on the diff**: `git diff` staged+unstaged against patterns for PATs/tokens
   (`dpat_`, `ghp_`, `sk-`, `AKIA`), private keys, DSNs/connection strings, passwords in env
   files. Any hit = HARD STOP, name the file:line, never commit. `.env*` files never enter a
   commit.

## Step 2: Quality pass

Invoke `/simplify` on the diff (the user's recurring "¿algo que optimizar/mejorar?"
formalized) only when the diff exceeds the `simplify` threshold (default 500 changed lines;
`off` = never automatically). Below the threshold, run it only on explicit request. Apply what
it finds or record why not. Future: per-area importance thresholds (e.g. anything touching
auth) — noted as an evolution, not implemented.

**Comment hygiene (always, regardless of the simplify threshold).** Scan the diff for comment
blocks longer than ~3 lines that narrate the logic. Reduce each to a terse WHY reference; if
the explanation is worth keeping, move it to the repo's docs/ and leave a one-line pointer in
the code (route to `/doctos` when the content is large enough to need placement).

## Step 3: Bookkeeping

- Docs whose claims the diff invalidates → fix if trivial, otherwise route to `/doctos`.
- Completed tasks → delegate to `/pm-tasks` (TASK_TODO.md → TASK_COMPLETED/YYMM.md).
- Repo uses Tasky MCP (e.g. henri) → sync the task there too (comment + status) so the two
  never diverge.

## Step 4: PR — on the CURRENT branch

- **Never create a new branch without being asked** (recurring correction in the corpus). The
  branch you're on is the branch that ships. Exception: commits stranded on a protected main —
  see Step 0.
- Title/description per repo convention; respect release prefixes where configured
  (e.g. `STAGING RELEASE:` / `PROD RELEASE:` only on staging/prod branches, never develop).
- Assign the configured reviewer in team repos.
- **gh CLI failure mode**: if `gh` fails (auth expired, TLS/keychain), report the EXACT error,
  ask the user to re-auth (`gh auth login`), retry ONCE — never loop on a broken gh.

## Step 5: Merge — governed by policy

- `auto`: gates green + required proofs green → merge now, then Step 6. Any gate or proof
  failed → behave as `ask`.
- `ask`: show the exact commands that WILL run (merge method, branch deletion) and WAIT for
  explicit OK. No merge, no PR close, no branch delete without it. Silence is not consent.

## Step 6: After the merge

`git checkout <default branch> && git pull` (repos with symlinked checkouts serve whatever
branch is checked out — returning to main is mandatory, not cosmetic). Branch cleanup per
config. Re-verify working tree is clean.

## Step 7: Evidence report (kills the "¿seguro?")

Close with a table — every row is a claim WITH its proof:

| Gate | Command | Result |
|---|---|---|
| Identity | `git remote get-url origin` | repo ✓ branch ✓ |
| Lint | `<cmd>` | 0 errors / 0 warnings |
| Build | `<cmd>` | exit 0 |
| Proofs | `<smoke/e2e cmd>` | N/N pass |
| Secrets | diff scan | clean |
| PR | — | #N · URL · merged SHA `abc123` (or OPEN, awaiting OK) |
| Tasks | — | moved: list (or none) |
| Docs | — | touched: list (or none) |

Anything not done says NOT DONE with the reason. This table is the natural input for the
micro-standup journal entry.

## Boundaries

- Never pushes directly to a protected default branch; everything goes through a PR.
- Never merges under `ask` without explicit OK; never closes PRs on its own initiative.
- A failed gate produces a report, not a workaround. Secrets found = hard stop.
- Ship orchestrates; repo-level git hooks (pre-commit/pre-push) remain the guarantee layer —
  recommend them once where gates exist only as prose.
