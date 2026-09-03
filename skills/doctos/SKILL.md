---
name: doctos
description: >
  Documentation hygiene and organization for any project. Audits .md files, enforces root-level rules
  (only README, CLAUDE, AGENTS, CONTRIBUTING, CHANGELOG, LICENSE at root), moves everything else into
  docs/ with standard subfolder structure (ARCHITECTURE/, FEATURES/, GUIDES/, RESEARCH/, ARCHIVED/).
  Renames inconsistent folders/files to UPPERCASE_SNAKE convention. Detects obsolete docs and archives them.
  Use this skill when the user mentions cleaning up docs, organizing markdown files, project structure,
  "too many files at root", "docs are a mess", "organize the project", "limpia los docs", "estructura",
  "revisa los md", "actualiza los docs", "ordena los docs", "los docs estan desactualizados" (the
  user almost never types the slash: trigger from informal prose and typos),
  or wants to standardize documentation across projects. Also trigger on "doctos".
  Disambiguation: use pm-tasks instead when the request is about task content (backlogs, TODOs,
  archiving completed work); use kickoff instead when the user wants project state analysis, not reorganization.
allowed-tools: Read, Glob, Grep, Bash, Edit, Write
---

# Doctos: Documentation Hygiene & Organization

Enforces a clean, consistent documentation structure across any project. Moves stray files into `docs/`, renames to standard conventions, archives obsolete content, and delegates task-related work to pm-tasks.

**Reference routing.** This file is the always-loaded core: the rules and the mode logic. The output formats load on demand:

| Load | When |
|---|---|
| `references/report-templates.md` | Producing an AUDIT report, showing a CLEAN plan or its post-clean report, or writing the `docs/README.md` that INIT creates |

## The value-to-reread bar (what deserves to exist)

Structure is not enough: a tidy folder full of docs nobody rereads still costs tokens to scan and confuses readers. **A doc earns its place only if someone will reopen it AND no other source already shows what it says.** Apply this bar in every audit, alongside the structure and freshness checks. The referent shifts by repo type: in a code repo the other source is the code and tooling ("how to register a user" restates the command); in a content repo there may be NO other source, which is exactly when the document has the most value (a legal analysis is worth keeping precisely because nothing else shows it). Ask "is there another source that already shows this?", not "does the code show this?".

- **Keep**: decisions and their *why* (ADRs), hard-won fixes / past errors that were painful to solve (the historical record that stops the team re-suffering them), setup that is genuinely non-obvious, and anything a README should link as context.
- **Cut (flag for ARCHIVED/ or deletion)**: generic how-tos that restate what running the obvious command already teaches. The litmus test the user gave: *"how to register a user" is not worth documenting; a deployment guide is worth it ONLY if the deploy differs from just running the commands.* If a guide would be replaced by one line ("run `X`"), it is that one line: put it in the README, not a GUIDE.
- **The cost is real**: every doc that survives gets reread by humans and re-scanned by agents. Verbose, generic, or never-reopened docs are not neutral: they dilute the signal and cost tokens. Concise and functional beats complete.

This is a judgement call, so doctos **flags** low-value docs as findings ("low reread value: generic how-to, consider README one-liner or delete") and lets the user decide; it never deletes prose on its own.

## Repo type: is the content the product?

Before applying the layout and naming rules below, detect the repo type. Those rules assume `.md` files are documentation ABOUT a system (code). Some repos are the opposite: the documents ARE the product (a bylaw / reglamento, contracts, a research corpus, a book). Moving a content file into `docs/GUIDES/` is like moving `src/` into `docs/`.

**Detection (cheap):** no dependency manifest at root (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Gemfile`, and the like) AND more than half the files are documents (`.md`, `.pdf`, `.docx`, `.odt`) means a **content repo**. Otherwise treat it as a code/docs repo, the default this skill was written for.

**In a content repo, the default layout does not apply. Instead:**
- **Do not move the content into `docs/`.** `docs/` holds only META about the repo (how the material is organized, how to contribute, a changelog). The content itself lives organized **by domain**: by area, topic, or the material's own structure, never folded into the technical taxonomy.
- **The technical taxonomy has no slot for content.** ARCHITECTURE / FEATURES / GUIDES / RESEARCH all describe documentation about a system; a bylaw or a contract fits none of them. Do not force content into them. Use domain folders that fit the material and that a reader of that material would expect.
- **Match the audience's language and literacy in folder names.** These repos get opened by non-technical readers (neighbors, older people, clients), often in Spanish. `archivo/` is understood; `ARCHIVED/` is not. Use readable, localized names (`archivo/`, `guias/`, `borradores/`), not UPPERCASE English. The UPPERCASE English convention below is for technical / code repos.

This is the same spirit as the published-site guard and the "respect documented conventions" rule: when a repo has its own working structure, doctos reports hygiene findings but never imposes the default layout on top of it.

## The declared structure: `.doctos.yml`

The layout below is the DEFAULT, not a law. A repo declares its own in `.doctos.yml` at the
root, and doctos audits against what is declared instead of against the default. This is what
lets projects with different shapes (ADRs, Diataxis, a team convention in lowercase, a docs
folder that is not `docs/`) use the skill without being told to rename everything.

```yaml
docs_root: docs                 # where documentation lives
naming: UPPERCASE_SNAKE         # or kebab-case, or lowercase
folders:                        # folder: what belongs in it
  ARCHITECTURE: architecture, schemas, decisions, technical trade-offs
  GUIDES: setup, deploy, onboarding, conventions
  ARCHIVED: obsolete docs, each with an archival note
root_allowed: [CONTRIBUTING.md] # extra .md tolerated at the repo root
```

**The descriptions are not decoration: they are the routing table.** Classifying a stray file
means matching its content against what each folder is for, so a declared taxonomy works with
the existing logic and needs no special case.

**Why the root and not `docs/`.** The file says WHERE documentation lives, so it cannot live
inside it: a repo with `documentation/` or `website/docs/` would need doctos to guess the
location of the file that tells it the location. At the root it sits with the other tooling
config (`.gitignore`, `lefthook.yml`), it is found in one look, and it is **committed, never
gitignored**: the structure has to travel with the clone and a change to it has to show up in a
PR like any other decision.

**Verify it, do not obey it.** A config that lies is worse than none, because it makes a mess
look sanctioned. Before using a declared structure, check it against reality and report the
drift as findings: folders declared that do not exist, folders that exist and are not declared,
a `docs_root` that is absent. Then audit against the declaration.

**`docs/README.md` stays the human door, and it is DERIVED.** Its structure table is generated
from this file and carries a line saying so, because the same list kept by hand in two places
drifts and then nobody knows which one is true. When the two disagree, `.doctos.yml` wins and
the difference is a finding.

**Precedence.** The published-site guard still wins over everything (moves break live URLs). A
declaration beats the content-repo heuristic, since it is explicit where the heuristic guesses.
The default applies only when there is no file. `/doctos init` writes the file with the default
values, and CLEAN offers to add it when it is missing, always as one more confirmed line in the
plan, never silently.

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
- `archived/` or `Archived/` or `ARCHIVE/` → `ARCHIVED/`
- `tasks_completed/` or `COMPLETED_TASK/` → `TASK_COMPLETED/`
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
- **No embedded code blocks**: reference scripts by path (`scripts/deploy.sh`) instead of pasting their content: pasted copies go stale silently and nobody notices until an agent follows the wrong version. **Exception: the `## ship config` yaml fence is REQUIRED by flowkit** (the git hooks and `/ship` parse it from CLAUDE.md): never flag it as embedded code; it is structured config, not a pasted walkthrough.
- **No stale claims**: the stack, commands and structure they describe must match reality. Audit them with the same stale-claims check as any doc: a CLAUDE.md that names the wrong auth library actively sabotages every session.
- **No task tracking**: pending/completed lists belong in `docs/TASK_TODO.md` (pm-tasks' protected-zone rule covers these files too).

## Subfolder purposes

Understanding what goes where prevents misclassification:

### ARCHITECTURE/
Technical architecture, system design, data flow, schema docs, ADRs (Architecture Decision Records), technical decisions, stack choices.

**Examples:** `ARCHITECTURE.md`, `DATABASE_SCHEMA.md`, `API_DESIGN.md`, `DECISIONS.md`, `STACK.md`, `DESIGN_PATTERNS.md`

### FEATURES/
Active feature specs for current or upcoming work. These describe *how something will be built* before it's built. Once the feature ships, the spec moves to `ARCHIVED/` (the implementation is now the source of truth, not the spec).

**Examples:** `26_APRIL_AGENTS.md`, `VOICE_INTEGRATION_SPEC.md`, `PRD_PHASE_2.md`

### GUIDES/
How-to documentation for humans, but only the NON-OBVIOUS kind (see the value-to-reread bar). Setup/deployment/onboarding/conventions that differ from just running the standard commands. A deployment guide earns its place when the deploy has real steps beyond `npm run deploy`; a "how to register a user" guide does not: that is a README line at most. Cut the generic, keep the surprising.

**Examples:** `DEPLOYMENT_GUIDE.md` (when non-trivial), `CODING_RULES.md`, `TESTING.md`, `CSS_CONVENTIONS.md`, each only if it says something the code/commands don't already show.

### RESEARCH/
Investigation, analysis, benchmarks, competitor research, technology evaluations. Content that informed decisions but isn't prescriptive.

**Examples:** `KNOWLEDGE_TOOLS.md`, `COMPETITOR_ANALYSIS.md`, `MODEL_BENCHMARKS.md`, `TECH_EVALUATION.md`

### JOURNAL/
The project's dated logbook: state-in-time reports, append-only, never edited after the fact. `KICKOFF_<YYMMDD>.md` (how the project was found when resuming, written by /kickoff) and `STANDUP_<YYMMDD>.md` (what happened, written by /standup, which may append several timestamped sections to the same day's file as work sessions close). One file per day per type; past days are closed records. Unlike RESEARCH/ (timeless investigations) or ARCHIVED/ (obsolete docs), JOURNAL/ entries are *born historical*: they describe a moment and stay valid as a record of it. Doctos never archives JOURNAL/ files by age; their age is the point.

**Examples:** `KICKOFF_260718.md`, `STANDUP_260725.md`

### ARCHIVED/
Documents that are no longer current but worth keeping for historical context. Every archived file must have an archival note at the top explaining why it was archived and what replaced it.

**Archival note format:**
```markdown
> **ARCHIVED**: 2026-04-05
> This document is no longer current. [Reason: replaced by X / feature shipped / approach changed / no longer relevant].
> Current reference: [link to replacement if any]

---

[original content below unchanged]
```

### TASK_COMPLETED/
Managed exclusively by pm-tasks. Doctos only renames the folder if it uses a non-standard name (`tasks_completed/`, `COMPLETED_TASK/`, etc.) but never touches the content inside.

## Modes

| Command | Mode | What it does |
|---------|------|-------------|
| `/doctos` | Audit | Scan project, report all issues, suggest fixes |
| `/doctos clean` | Clean | Execute fixes: move, rename, archive |
| `/doctos init` | Init | Create docs/ structure from scratch |

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
4. **Detect obsolete documents**, signals:
   - **Age**: files not modified in 90+ days (`git log -1 --format=%as -- <file>`). Exclude `docs/JOURNAL/`: dated logbook entries are meant to age
   - **Low reread value** (the value-to-reread bar above): a guide that restates what the obvious command already teaches (generic login/CRUD/register how-tos), a walkthrough that would collapse to a one-line README pointer, or a doc nobody would reopen. Flag as "low reread value: [generic how-to / restates the command / never reopened], consider README one-liner or ARCHIVED/". Keep decision records, hard-won fixes, and non-obvious setup regardless of length: those are exactly what justifies a doc.
   - **Stale claims**: content that contradicts the project's reality: tech mentioned that is absent from package.json/Cargo.toml/deps, referenced files or routes that no longer exist, counts that no longer match ("22 prototypes" when 3 remain). Spot-check each doc's boldest claims against the codebase; a doc describing the wrong stack misleads every future reader (human or agent) and is worse than no doc
   - **Derived artifact vs its source** (applies to code AND content repos, often the highest-value finding): a file that is an export of a source drifts silently when the source changes and the export is not regenerated. Detection is cheap: same base name, different extension; compare mtime and size. In a content repo the source is the `.md` and the derived files are the exported `.pdf` / `.docx`; in a code repo the source is the `.ts` and the derived files are the generated `.d.ts` / OpenAPI / snapshots. Flag any derived file older than or materially diverging from its source ("`X.pdf` is 13 months older than `X.md`: stale export, readers may be trusting the old version"). Field case: three generations of a bylaw's PDF/DOCX lagged the Markdown source for 13 months with nobody noticing. This is not a doc-repo special case; it is the general form of the stale-claims check.
   - **Coverage gaps** (the inverse check): recent shipped work (new modules, features, commands visible in the last ~20 commits) that no doc mentions. Missing docs are findings too, not just misplaced ones. Report as "undocumented: X" with a suggested destination
   - **Prioritize via the journal**: if `docs/JOURNAL/` has recent `KICKOFF_*`/`STANDUP_*` entries, read the latest ones first and start the stale-claims and coverage checks on the files/features they mention: recently-moved areas are where docs lie first. The journal doesn't change what you detect, it changes where you look first
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

Executes all fixes identified in the audit.

### Steps

1. **Run audit first**: build the full list of issues
1b. **Freshness verdict per file being moved.** Structure and content rot together: a file worth relocating is a file worth 30 seconds of scrutiny, and moving a stale doc to a tidy folder just gives the lie a better address. For every file in the move plan, check `git log -1 --format=%as -- <file>` and spot-check its boldest claim against the codebase. Attach a verdict to each plan line: ✅ vigente · 🟡 revisar (old but spot-check passed: add a review task) · 🔴 deprecated (contradicts reality: goes to ARCHIVED/ with note instead of its planned destination, plus a task to replace it). Real case that motivated this: a `project_definition.md` moved during a cleanup turned out to describe a *different project entirely* (copied from another repo, never adapted). Structure-only cleaning would have promoted it to ARCHITECTURE/.
2. **Show the execution plan** to the user and ask for confirmation, using the **CLEAN plan format** in `references/report-templates.md` (grouped into Will move / Will rename / Will rename task-related / Will create / Will archive, ending in "Proceed? (y/n)").

3. **After confirmation, execute:**
   - Use `git mv` where possible to preserve history
   - Create missing folders
   - Rename files/folders to standard convention
   - Add archival notes to files moved to ARCHIVED/
   - Convert .txt files to .md
   - Rename hyphens to underscores in file names (`DEV-WORKFLOW.md` → `DEV_WORKFLOW.md`)
   - **Repair inbound references**: after every move or rename, search the whole project for the old path/filename (other docs, CLAUDE.md pointers, code comments) and update each reference to the new location. Moving a file without fixing its inbound links converts organization into breakage: this step is what makes the clean safe
   - Create docs/README.md with documentation index and writing rules
   - If task-related files were renamed, remind user: "Task folders renamed. Run `/pm-tasks` to audit task content."

4. **Post-clean report:** use the **CLEAN post-clean report format** in `references/report-templates.md` (counts of moved / renamed / created / archived, plus the pm-tasks reminder).

### Handling edge cases

**File name conflicts:** If moving `ARCHITECTURE.md` from root to `docs/ARCHITECTURE/` but `docs/ARCHITECTURE/ARCHITECTURE.md` already exists: ask the user whether to merge, rename, or skip.

**Published docs sites:** if the audit flagged `docs/` as a published site (CNAME / index.html / _config.yml / Pages workflow), CLEAN must refuse every move or rename under `docs/`: only in-place content fixes (stale claims, archival notes prepended without moving the file) are allowed. Say so explicitly in the plan.

**Non-markdown files in docs/:** Shell scripts (`.sh`), config files, images: these are fine. Only audit `.md` and `.txt` files.

**Nested project structures:** For workspaces with sub-projects (e.g., a monorepo with `backend_api/` and `browser_extension/`), audit each sub-project independently. Don't move sub-project docs to the workspace root.

---

## Mode: INIT (`/doctos init`)

Creates the standard docs structure. Like pm-tasks init, this both creates from scratch and standardizes existing setups.

### Steps

1. **Scan what exists** (same as audit detection)
2. **Branch:**

#### A) Nothing exists: fresh setup

Create the full structure:
```
docs/
├── README.md
├── ARCHITECTURE/
├── FEATURES/
├── GUIDES/
├── RESEARCH/
└── ARCHIVED/
```

Only create subfolders that the project likely needs. A small utility doesn't need `RESEARCH/`. Detect project size/type from:
- Number of source files
- package.json / Cargo.toml dependencies
- Existing documentation volume

Minimum for any project: `docs/README.md` + `docs/GUIDES/`

#### B) Existing non-standard setup: standardize

Same as CLEAN mode but more aggressive:
- Run the full audit
- Show the migration plan
- Execute after confirmation
- Create any missing standard folders

3. **Write `.doctos.yml`** with the default values (or the structure agreed for this repo), so the layout is declared, versioned and visible in diffs instead of living only inside this skill.

4. **Write docs/README.md** with documentation index and writing rules, using the **INIT docs/README.md template** in `references/report-templates.md` (structure table, root-level files, and the seven writing rules). For a content repo, adapt it per the note there.

5. **If task structure is missing**, suggest: "No task tracking found. Run `/pm-tasks init` to set up TASK_TODO.md and TASK_COMPLETED/."

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
