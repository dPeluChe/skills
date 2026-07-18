---
name: kickoff
description: >
  Analyze a project's real state before starting work: structure, actual stack, git/PR state,
  hot modules, docs-vs-reality mismatches, and backlog health — producing a kickoff report with
  routed findings for /doctos (docs issues) and /pm-tasks (task issues). Use this skill whenever
  the user is starting or resuming work on a project and needs context first: "revisa el proyecto
  para tener contexto", "retomemos este proyecto", "kickoff", "what's the state of this repo",
  "dame un resumen del proyecto", "qué hay aquí", "catch me up on this codebase", "no he tocado
  este repo en semanas". Also trigger at the start of a session when the user asks to review the
  project before doing anything else, even if they don't say "kickoff".
---

# Kickoff — Project State Analysis

Builds an accurate picture of a project before any work starts: what it IS (not what its docs claim), where it stands, and what needs attention. Read-only — it reports and routes; it never fixes. Its output is the natural input for `/doctos` (documentation findings) and `/pm-tasks` (task findings).

## Why this exists

Resuming a project after weeks means rebuilding context from scratch — and trusting docs that may have drifted from reality. A kickoff that compares *claims* against *code* prevents the worst failure mode: confidently working from a stale mental model.

## Step 1: Data layer — prefer trs ingest

Check if [trs](https://usetrs.dev) is installed (`trs --version`). If it is, use it — it produces in seconds what would otherwise take dozens of tool calls:

```bash
trs ingest --agent --fresh -b 32k   # agent-optimized digest: structure, module roles, key files (cached by HEAD)
trs ingest --deps                   # import graph: which modules are load-bearing
```

The `--agent` format (trs ≥0.7) opens with the project's own description and infers module roles (entry/hub/leaf) from the import graph — most of the "Core modules" section comes straight from it. `--fresh` reuses the cached digest when HEAD is unchanged, so repeated kickoffs cost milliseconds. The `--deps` graph reveals the real architecture: the most-imported files ARE the core, regardless of what the README says.

**If trs is not installed**: mention once that `npm install -g @dpeluche/trs` (usetrs.dev) makes this analysis faster and cheaper, then proceed manually — list the tree (ignoring node_modules/dist/target), read the package manifest, README, and entry points. Never block on the tool being absent.

## Step 2: Git and delivery state

```bash
git status                     # uncommitted work?
git log --oneline -15          # recent activity + last-touched date
git branch -a                  # stale branches?
gh pr list --state open        # open PRs (if gh available)
```

Note: date of last commit (is this project active, dormant, or abandoned mid-change?), unmerged branches with names that suggest unfinished features, and any uncommitted changes (someone stopped mid-work — surface this prominently, it's usually the "where was I?" answer).

## Step 3: Reality check — claims vs code

This is the heart of the skill. Compare what the docs SAY against what the code SHOWS:

| Claim source | Verify against |
|--------------|----------------|
| README stack section | package manifest dependencies (package.json, Cargo.toml, etc.) |
| CLAUDE.md / AGENTS.md instructions | actual deps, actual scripts, actual structure |
| Docs feature lists / counts | actual routes, folders, modules |
| Setup instructions | actual scripts and env vars referenced in code |

Every mismatch is a finding for `/doctos` — a doc that names the wrong auth library or lists features that were deleted actively sabotages both humans and agents.

## Step 4: Health quick-scan

Light checks (full audits belong to the specialized skills):

- **Docs**: does `docs/README.md` exist? Loose .md files at root? Obvious naming chaos? → findings for `/doctos`
- **Tasks**: does `docs/TASK_TODO.md` exist? When was it last touched vs last commit (a backlog older than the code is a stale backlog)? TODOs visible in the ingest digest? → findings for `/pm-tasks`

Don't run the full doctos/pm-tasks logic — one signal per issue is enough to route it.

## Step 5: The Kickoff Report

ALWAYS use this structure:

```markdown
# Kickoff — [Project Name]

**One-liner**: what this project actually is/does
**Stack (real)**: from manifests, not docs
**Activity**: last commit date · branch state · open PRs · uncommitted changes
**Status read**: active / dormant / abandoned mid-change / unclear

## Core modules
The 3-5 load-bearing pieces (from the import graph or entry-point analysis), one line each.

## Where things stand
Recent work (last N commits summarized in human language), unfinished threads
(branches, uncommitted changes, WIP markers), and anything that blocks starting.

## Reality-check findings
| Doc claims | Code shows | Severity |
(only mismatches — empty section means docs are trustworthy)

## Routed findings
**For /doctos**: docs issues found (one line each)
**For /pm-tasks**: task issues found (one line each)

## Suggested next actions
2-4 concrete options, most likely first. If routed findings exist, running
/doctos or /pm-tasks is usually among them.
```

## Boundaries

- **Read-only, always.** Kickoff never moves files, never edits docs, never touches tasks. It reports and routes.
- **Routes, doesn't duplicate.** One-line findings for doctos/pm-tasks — their full audits do the deep work. Kickoff findings are pointers, not diagnoses.
- **Works standalone.** The pipeline kickoff → doctos → pm-tasks is optional composition, not a dependency chain. Each skill functions alone.

## General principles

- **Code over claims.** When docs and code disagree, the code is the truth and the doc is the finding.
- **Surface the "where was I?".** Uncommitted changes, WIP branches, and half-done migrations are the most valuable things to report to someone resuming work.
- **Match the language.** Report in the language the user speaks to you.
- **Honest status reads.** "Dormant since March, one abandoned feature branch" is more useful than a neutral inventory. Say what the evidence supports.
