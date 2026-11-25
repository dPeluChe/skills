---
name: doctos
description: >
  Documentation hygiene for any project: audits .md files, keeps the root to README,
  CLAUDE, AGENTS, CONTRIBUTING, CHANGELOG and LICENSE, moves the rest into docs/ (ARCHITECTURE,
  FEATURES, GUIDES, RESEARCH, ARCHIVED, or the structure a repo declares), renames to
  UPPERCASE_SNAKE and archives obsolete docs. Trigger from informal prose and typos, slash or
  not: "limpia los docs", "ordena los docs", "revisa los md", "actualiza los docs", "los docs
  estan desactualizados", "estructura", "docs are a mess", "too many files at root", "doctos",
  or standardizing docs across projects. Not pm-tasks (task content: backlogs, TODOs,
  archiving); not kickoff (state analysis, not reorganization).
allowed-tools: Read, Glob, Grep, Bash, Edit, Write
---

# Doctos: Documentation Hygiene & Organization

Enforces a clean, consistent documentation structure across any project. Moves stray files into `docs/`, renames to standard conventions, archives obsolete content, and delegates task-related work to pm-tasks.

**Reference routing.** This file is the always-loaded core: the rules and the mode logic. The details load on demand, per mode or step:

| Load | When |
|---|---|
| `references/report-templates.md` | Writing any report or plan, or the `docs/README.md` INIT creates |
| `references/subfolders.md` | The classification table does not decide a file, or archiving (the archival note) |
| `references/clean.md` / `references/init.md` | Running that mode: its full steps and edge cases |
| `references/obsolete-signals.md` | AUDIT step 4: detecting obsolete documents |
| `references/content-repos.md` | The repo-type check finds a content repo |
| `references/doctos-yml.md` | The repo has `.doctos.yml`, or INIT/CLEAN writes one |

## The value-to-reread bar (what deserves to exist)

Structure is not enough: a tidy folder full of docs nobody rereads still costs tokens to scan and confuses readers. **A doc earns its place only if someone will reopen it AND no other source already shows what it says.** Apply this bar in every audit, alongside the structure and freshness checks. The referent shifts by repo type: in a code repo the other source is the code and tooling ("how to register a user" restates the command); in a content repo there may be NO other source, which is exactly when the document has the most value (a legal analysis is worth keeping precisely because nothing else shows it). Ask "is there another source that already shows this?", not "does the code show this?".

- **Keep**: decisions and their *why* (ADRs), hard-won fixes / past errors that were painful to solve (the historical record that stops the team re-suffering them), setup that is genuinely non-obvious, and anything a README should link as context.
- **Cut (flag for ARCHIVED/ or deletion)**: generic how-tos that restate what running the obvious command already teaches. The litmus test the user gave: *"how to register a user" is not worth documenting; a deployment guide is worth it ONLY if the deploy differs from just running the commands.* If a guide would be replaced by one line ("run `X`"), it is that one line: put it in the README, not a GUIDE.
- **The cost is real**: every doc that survives gets reread by humans and re-scanned by agents. Verbose, generic, or never-reopened docs are not neutral: they dilute the signal and cost tokens. Concise and functional beats complete.

This is a judgement call, so doctos **flags** low-value docs as findings ("low reread value: generic how-to, consider README one-liner or delete") and lets the user decide; it never deletes prose on its own.

## Repo type: is the content the product?

Detect it first. **No dependency manifest at the root AND more than half the files are
documents** (`.md`, `.pdf`, `.docx`, `.odt`) means a **content repo** (a bylaw, contracts, a
corpus, a book): the documents ARE the product. There the default layout does not apply:
content stays organized by domain, `docs/` holds only meta, and folder names follow the
audience's language (`archivo/`, not `ARCHIVED/`). Details: `references/content-repos.md`.
Load it whenever the check says content repo.

## The declared structure: `.doctos.yml`

The layout below is the DEFAULT, not a law. A repo declares its own in a committed
`.doctos.yml` at the root (`docs_root`, `naming`, `folders` with one line of purpose each,
`root_allowed`), and doctos audits against the declaration instead of the default. Core rules:

- **Verify it, do not obey it.** Report drift first: declared folders missing, existing folders
  undeclared, an absent `docs_root`. A config that lies makes a mess look sanctioned.
- **The folder descriptions are the routing table** for classifying stray files.
- **`docs/README.md` is derived** from it; when they disagree, `.doctos.yml` wins and the
  difference is a finding. The root `README.md` carries a two-line pointer block.
- **Precedence:** published-site guard > `.doctos.yml` > content-repo heuristic > default.
  Writing or adding the file is always one more confirmed line in a plan, never silent.

The schema, the README block, why it lives at the root and the survey behind the default:
`references/doctos-yml.md`. Load it when the file exists, or when INIT or CLEAN writes it.

## The standard structure

Every project should converge to this layout:

```
proyecto/
├── README.md                    ← project overview, setup, usage
├── CLAUDE.md                    ← Claude Code instructions (if used)
├── AGENTS.md                    ← agent architecture (if applicable)
├── CONTRIBUTING.md              ← contribution guide (if applicable)
├── CHANGELOG.md                 ← release history (if maintained)
├── LICENSE                      ← license file (if applicable)
│
└── docs/
    ├── README.md                ← documentation index + writing rules
    ├── TASK_TODO.md             ← (pm-tasks territory, don't touch content)
    │
    ├── TASK_COMPLETED/          ← (pm-tasks territory, don't touch content)
    │   ├── README.md
    │   └── YYMM.md
    │
    ├── ARCHITECTURE/            ← technical architecture, decisions, diagrams
    │
    ├── FEATURES/                ← active sprint specs, design docs, PRDs
    │
    ├── GUIDES/                  ← setup, deployment, onboarding, coding rules, testing
    │
    ├── RESEARCH/                ← investigation, analysis, benchmarks, comparisons
    │
    ├── JOURNAL/                 ← dated project-state log: kickoff snapshots, standup reports
    │
    └── ARCHIVED/                ← obsolete docs with archival note
```

## Naming conventions

These are non-negotiable **for code / docs repos**. Consistency across projects is the whole point. (Content repos are the exception: see "Repo type" above. There, folder names match the audience's language and literacy, e.g. `archivo/` not `ARCHIVED/`.)

| Element | Convention | Example |
|---------|-----------|---------|
| `docs/` directory | lowercase | `docs/` (never `DOCS/` or `Docs/`) |
| Subfolders inside docs/ | UPPERCASE | `ARCHITECTURE/`, `FEATURES/`, `GUIDES/` |
| Markdown files | UPPERCASE_SNAKE_CASE | `CODING_STANDARDS.md`, `API_REFERENCE.md` |
| The only exception | `docs/README.md` | Standard convention for index files |

**Renaming rules:**
- `archived/` or `Archived/` or `ARCHIVE/` or `archives/` → `ARCHIVED/`
- `tasks_completed/` or `COMPLETED_TASK/` or `TASKS_COMPLETED/` → `TASK_COMPLETED/`
- `features/` → `FEATURES/`
- `task_todo.md` or `TODO.md` → `TASK_TODO.md`
- `agents.md` (lowercase) → `AGENTS.md`
- `arquitectura-tecnica.md` → `ARCHITECTURE/ARQUITECTURA_TECNICA.md` (move + rename)
- `project_evolution.md` → `PROJECT_EVOLUTION.md`
- `.txt` docs files → convert to `.md`

## Root-level rules

Only these files are allowed at the project root:

| File | Required? | Purpose |
|------|-----------|---------|
| `README.md` | Yes | Project overview, quick start, usage |
| `CLAUDE.md` | If using Claude Code | Instructions for Claude Code agent |
| `AGENTS.md` | If project has agents | Agent architecture and blueprints |
| `CONTRIBUTING.md` | Optional | Contribution guidelines |
| `CHANGELOG.md` | Optional | Release notes and version history |
| `LICENSE` | Optional | License file (no .md extension) |
| `CODE_OF_CONDUCT.md` | Optional | Community standards |
| `SECURITY.md` | Optional | Security policy |

**Everything else at root that is .md must move to docs/** (in a code / docs repo). Files like `REFACTOR_PLAN.md`, `DATABASE_LOCK_FIX.md`, `UI_UX_ANALYSIS.md`, `PROJECT-SUMMARY.md` at root are violations: they belong in the appropriate docs/ subfolder. The exception is a content repo (see "Repo type" above): there the `.md` files ARE the product and stay in their domain structure, only meta-docs about the repo go in `docs/`.

## Agent instruction files (CLAUDE.md, AGENTS.md)

Allowed at root, but with their own hygiene rules: these files load into EVERY agent session, so every extra line is a recurring token cost, and agents trust them blindly:

- **Lean**: instructions only. Long walkthroughs and background belong in `docs/GUIDES/` or `docs/ARCHITECTURE/` with a one-line pointer.
- **No embedded code blocks**: reference scripts by path (`scripts/deploy.sh`) instead of pasting their content: pasted copies go stale silently and nobody notices until an agent follows the wrong version. **Exception: the `## preship config` yaml fence is REQUIRED by flowkit** (the git hooks and `/preship` parse it from CLAUDE.md): never flag it as embedded code; it is structured config, not a pasted walkthrough.
- **No stale claims**: the stack, commands and structure they describe must match reality. Audit them with the same stale-claims check as any doc: a CLAUDE.md that names the wrong auth library actively sabotages every session.
- **No task tracking**: pending/completed lists belong in `docs/TASK_TODO.md` (pm-tasks' protected-zone rule covers these files too).

## Subfolder purposes

What belongs in each folder, with examples, the JOURNAL rules and the **archival note format**
every ARCHIVED/ file needs: `references/subfolders.md`. The classification table under AUDIT
decides most moves; load the reference when it does not, or before archiving (CLEAN). Two rules that hold without loading it: JOURNAL/ entries are never
archived by age, and TASK_COMPLETED/ content belongs to pm-tasks (doctos may only rename the folder).

## Modes

| Command | Mode | What it does |
|---------|------|-------------|
| `/doctos` | Audit | Scan project, report all issues, suggest fixes |
| `/doctos clean` | Clean | Execute fixes: move, rename, archive |
| `/doctos init` | Init | Create docs/ structure from scratch |

**Picking the mode from prose.** The user almost never types the slash, so the request itself
decides. Read the verb, not the topic:

| The user says | Mode |
|---|---|
| "revisa los docs", "como estan los md", "audita", any question about the state | AUDIT |
| "limpia", "ordena", "organiza", "muevelos", "arregla la estructura" | CLEAN |
| "no hay docs", "arma la estructura", "empieza la documentacion" | INIT |

**When the request is ambiguous ("estructura", "docs"), run AUDIT.** It is the only read-only
mode: it costs the user one extra sentence to then ask for the clean, while guessing CLEAN moves
files nobody agreed to move. CLEAN still shows its plan and waits for confirmation, so the
inference decides which report you produce, never whether something gets written.

## Scoped invocation (routed findings)

When doctos is invoked right after `/kickoff` or `/standup` handed it routed findings ("README claim X went stale", "3 loose .md at root"), don't run the full project audit: **verify the routed list and act on it only**:

1. Take each routed finding and verify it yourself (trust, but verify: the router saw a diff-scoped partial picture)
2. Fix the confirmed ones (with the usual confirmation for moves/renames)
3. Note anything adjacent you spotted while verifying, but don't expand into a full sweep
4. Report with the standard status line

This is what makes doctos usable *during* development: targeted work orders in minutes. The full audit remains the tool for periodic hygiene passes.

---

## Mode: AUDIT (default, no arguments)

Full scan of the project's documentation health.

### Steps

0. **Detect repo type first** (see "Repo type" above): check for a root dependency manifest and the document-to-file ratio. If it is a content repo, do NOT propose the default layout or UPPERCASE English folders; report hygiene findings against the repo's own domain structure and use readable localized names. State "content repo: findings against its own structure, default layout not imposed" in the header so CLEAN inherits it.
0a. **Read `.doctos.yml` if it exists** (see "The declared structure"): run the drift check first (declared folders missing, existing folders undeclared, absent `docs_root`) and report it, then audit against the declaration instead of the default layout. State "declared structure: auditing against .doctos.yml" in the header so CLEAN inherits it. When the file is absent, note it once and offer to write it with the defaults.
1. **List all .md files at project root**: identify which are allowed vs violations
1a. **Published-site guard**: if `docs/` contains `CNAME`, `index.html`, or `_config.yml`, or `.github/workflows/` has a Pages deploy workflow (`configure-pages`, `deploy-pages`, `jekyll`, `github-pages`, `mkdocs gh-deploy`), then `docs/` is a **published site**: the whole run degrades to **findings only: do NOT reorganize; fix in place**. Report every issue as usual, but never move, rename, or restructure anything under `docs/` (moves break live URLs). Mark the audit header with "docs/ is a published site: findings only" so CLEAN mode inherits the restriction. **Report this ONLY when the guard fires.** When `docs/` is a normal documentation folder, say nothing about it: a "docs/ is not a published site" line is noise, it states the default and confuses the reader into thinking it means something. This guard applies to full AUDIT too, not just scoped runs.
2. **Scan docs/ folder**: check subfolder names, file names, structure
3. **Check naming conventions**: find lowercase folders, inconsistent file names, .txt docs
4. **Detect obsolete documents.** Load `references/obsolete-signals.md` for how to detect and
   word each signal: **age** (90+ days, `docs/JOURNAL/` excluded), **low reread value**,
   **stale claims** (spot-check each doc's boldest claim against the code), **derived artifact
   older than its source** (`X.pdf` vs `X.md`, generated vs source), **coverage gaps** (recent
   shipped work no doc mentions). Start where the latest `docs/JOURNAL/` entries point.
5. **Check for task-related issues**: if task folders/files use non-standard names, flag for renaming and suggest running `/pm-tasks` after
6. **Check docs/README.md**: does it exist? does it have documentation rules?
7. **Audit agent instruction files**: apply the CLAUDE.md / AGENTS.md hygiene rules (see "Agent instruction files" section): flag embedded code blocks, stale tech claims, and task tracking inside them
7b. **Essay-comments in code (in passing, no full sweep)**: comment blocks over ~3 lines that narrate the logic, noticed while verifying other findings, are findings too: report each with a suggested docs/ destination (usually ARCHITECTURE/ or GUIDES/) so the block shrinks to a one-line WHY pointer in code
8. **Report everything.** Wording rules so the report reads clearly to someone who doesn't know doctos's model:
   - **Always use literal paths**, not the bare word "docs". "3 files loose in `docs/`" is ambiguous (the folder? documentation in general?); write "3 files directly inside `docs/`, not yet sorted into a subfolder (ARCHITECTURE/GUIDES/…)". Name the actual files.
   - `docs/` in a finding ALWAYS means the literal `docs/` directory at the repo root: never "documentation" as a concept. If you mean the concept, write "the documentation".
   - Only report findings, not clean checks: a line confirming a rule already holds ("root is clean", "docs/ is not a published site") is noise: omit it. The report is a list of what to fix, not a checklist of what passed.

Use the **AUDIT report format** in `references/report-templates.md` (load it at this step). It groups findings into Root violations, Naming issues, Task-related renaming, Missing structure, Potentially obsolete, and a Summary table with a total.

### Classification logic for root violations

When a .md file at root needs to move, classify it into the right subfolder:

| Content signals | Destination |
|----------------|-------------|
| Architecture, schema, design, stack, decisions, patterns | `ARCHITECTURE/` |
| Feature spec, PRD, requirements, phase plan | `FEATURES/` |
| Setup, deploy, install, workflow, conventions, testing, onboarding | `GUIDES/` |
| Research, analysis, benchmark, comparison, evaluation | `RESEARCH/` |
| Fix report, migration complete, old implementation, summary of past work | `ARCHIVED/` |
| Unclear / mixed content | Read the file to decide: if still ambiguous, ask the user |

---

## Mode: CLEAN (`/doctos clean`)

Executes the audit's fixes. Load `references/clean.md` before planning: it has the steps, the
freshness verdict per moved file, inbound-reference repair and the edge cases. Rules that hold
without loading it:

- **Nothing moves before the user confirms the plan** (CLEAN plan format in
  `references/report-templates.md`, ending in "Proceed? (y/n)").
- **Published docs site** (CNAME / index.html / _config.yml / Pages workflow under `docs/`):
  refuse every move or rename there; only in-place content fixes. Say so in the plan.
- **Every move repairs its inbound references** (other docs, CLAUDE.md pointers, comments).
- `git mv` to keep history; on a name conflict, ask (merge, rename or skip).

---

## Mode: INIT (`/doctos init`)

Creates the structure from scratch, or standardizes an existing setup (CLEAN rules apply,
confirmation first). It writes only the folders the project needs (minimum `docs/README.md` +
`docs/GUIDES/`), `.doctos.yml`, the two-line pointer in the root `README.md` and `docs/README.md`
from its template. Steps: `references/init.md`. Load it before running INIT.

---

## Relationship with pm-tasks

Doctos and pm-tasks are complementary but have clear boundaries:

| Responsibility | Doctos | pm-tasks |
|---------------|--------|----------|
| Folder/file naming | Renames `tasks_completed/` → `TASK_COMPLETED/` | N/A |
| Folder/file content | Never touches task content | Manages task lifecycle |
| Moving .md to docs/ | Yes | No |
| Archiving old docs | Yes (to ARCHIVED/) | No |
| Archiving completed tasks | No | Yes (to TASK_COMPLETED/) |
| Task checkboxes in random .md | No (that's pm-tasks scan) | Yes, extracts and centralizes |
| docs/README.md | Creates with structure rules | N/A |

**Handoff pattern:** Doctos renames task-related folders/files to standard names, then tells the user to run `/pm-tasks` to audit the content. Doctos never reads, modifies, or interprets task content.

---

## General principles

- **Ask before every destructive action.** Moving and renaming files can break references. Always show the plan and get confirmation.

- **Use git mv.** Preserve history. Never copy+delete when git mv is available.

- **Don't create empty folders.** Only create subfolders that will have content. A brand new project doesn't need RESEARCH/ if there's no research yet. Create folders as needed, not speculatively.

- **Archive, never delete.** If a document is obsolete, move it to ARCHIVED/ with a note. Someone might need it later for context. The only exception is truly empty or duplicate files.

- **Classify thoughtfully.** When moving a file to docs/, read it first if the destination isn't obvious from the filename. A file called `IMPLEMENTATION.md` could be ARCHITECTURE/ (design doc), GUIDES/ (how-to), or ARCHIVED/ (past implementation). The content decides.

- **Respect sub-projects.** In workspaces with multiple projects, each sub-project owns its own docs/. Don't centralize sub-project docs at the workspace level.

- **Respect documented conventions: they outrank the default layout.** Before flagging a structural deviation (flat `docs/` with no subfolders, `CHANGELOG.md` living in `docs/`, a specific file location), check whether the repo DOCUMENTS it on purpose (a numbered rule in CLAUDE.md, a note in `docs/README.md`, a CONTRIBUTING convention). If it does, that is an intentional choice, not debt: do NOT flag it, or at most note it once as "intentional per <ref>, respected". doctos standardizes repos that have no opinion; it does not override repos that have one. A skill that fights a documented convention makes the maintainer decline its findings by hand every run: exactly the friction it exists to remove. The structure rules in this skill are the DEFAULT for the undecided, never a mandate over the decided.

- **Language matching.** If the project's docs are in Spanish, keep Spanish. Don't translate filenames or content. But do standardize the casing: `arquitectura-tecnica.md` → `ARQUITECTURA_TECNICA.md`.

- **Never clobber, always Edit.** When touching an existing file (adding an archival note, fixing a link, updating an index), use targeted edits with exact match on the current content: never rewrite the whole file from memory. A full rewrite silently drops entries you didn't notice; a failed exact-match edit fails loudly, which is the safe direction.

- **End every report with a status line.** `**Status: DONE**` clean; `DONE_WITH_CONCERNS` (+ one line why); `BLOCKED`; `NEEDS_CONTEXT` when only the user can decide. Standard terminal vocabulary that other skills and scripts can consume.

- **Surface everything.** The audit should catch every issue in one pass. The user shouldn't need to run it twice to find new problems. Be thorough.
