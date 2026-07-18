---
name: doctos
description: >
  Documentation hygiene and organization for any project. Audits .md files, enforces root-level rules
  (only README, CLAUDE, AGENTS, CONTRIBUTING, CHANGELOG, LICENSE at root), moves everything else into
  docs/ with standard subfolder structure (ARCHITECTURE/, FEATURES/, GUIDES/, RESEARCH/, ARCHIVED/).
  Renames inconsistent folders/files to UPPERCASE_SNAKE convention. Detects obsolete docs and archives them.
  Use this skill when the user mentions cleaning up docs, organizing markdown files, project structure,
  "too many files at root", "docs are a mess", "organize the project", "limpia los docs", "estructura",
  or wants to standardize documentation across projects. Also trigger on "doctos".
  Disambiguation: use pm-tasks instead when the request is about task content (backlogs, TODOs,
  archiving completed work); use kickoff instead when the user wants project state analysis, not reorganization.
allowed-tools: Read, Glob, Grep, Bash, Edit, Write
---

# Doctos — Documentation Hygiene & Organization

Enforces a clean, consistent documentation structure across any project. Moves stray files into `docs/`, renames to standard conventions, archives obsolete content, and delegates task-related work to pm-tasks.

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
    ├── TASK_TODO.md             ← (pm-tasks territory — don't touch content)
    │
    ├── TASK_COMPLETED/          ← (pm-tasks territory — don't touch content)
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

These are non-negotiable. Consistency across projects is the whole point.

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

**Everything else at root that is .md must move to docs/.** No exceptions. Files like `REFACTOR_PLAN.md`, `DATABASE_LOCK_FIX.md`, `UI_UX_ANALYSIS.md`, `PROJECT-SUMMARY.md` at root are violations — they belong in the appropriate docs/ subfolder.

## Agent instruction files (CLAUDE.md, AGENTS.md)

Allowed at root, but with their own hygiene rules — these files load into EVERY agent session, so every extra line is a recurring token cost, and agents trust them blindly:

- **Lean**: instructions only. Long walkthroughs and background belong in `docs/GUIDES/` or `docs/ARCHITECTURE/` with a one-line pointer.
- **No embedded code blocks**: reference scripts by path (`scripts/deploy.sh`) instead of pasting their content — pasted copies go stale silently and nobody notices until an agent follows the wrong version.
- **No stale claims**: the stack, commands and structure they describe must match reality. Audit them with the same stale-claims check as any doc — a CLAUDE.md that names the wrong auth library actively sabotages every session.
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
How-to documentation for humans. Setup, deployment, onboarding, coding conventions, testing strategies, development workflows.

**Examples:** `SETUP.md`, `DEPLOYMENT_GUIDE.md`, `CODING_RULES.md`, `TESTING.md`, `DEV_ONBOARDING.md`, `CSS_CONVENTIONS.md`

### RESEARCH/
Investigation, analysis, benchmarks, competitor research, technology evaluations. Content that informed decisions but isn't prescriptive.

**Examples:** `KNOWLEDGE_TOOLS.md`, `COMPETITOR_ANALYSIS.md`, `MODEL_BENCHMARKS.md`, `TECH_EVALUATION.md`

### JOURNAL/
The project's dated logbook: state-in-time reports, append-only, never edited after the fact. `KICKOFF_<YYMMDD>.md` (how the project was found when resuming — written by /kickoff) and `STANDUP_<YYMMDD>.md` (what happened in a window — written by /standup). Unlike RESEARCH/ (timeless investigations) or ARCHIVED/ (obsolete docs), JOURNAL/ entries are *born historical* — they describe a moment and stay valid as a record of it. Doctos never archives JOURNAL/ files by age; their age is the point.

**Examples:** `KICKOFF_260718.md`, `STANDUP_260725.md`

### ARCHIVED/
Documents that are no longer current but worth keeping for historical context. Every archived file must have an archival note at the top explaining why it was archived and what replaced it.

**Archival note format:**
```markdown
> **ARCHIVED** — 2026-04-05
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

---

## Mode: AUDIT (default, no arguments)

Full scan of the project's documentation health.

### Steps

1. **List all .md files at project root** — identify which are allowed vs violations
2. **Scan docs/ folder** — check subfolder names, file names, structure
3. **Check naming conventions** — find lowercase folders, inconsistent file names, .txt docs
4. **Detect obsolete documents** — two signals:
   - **Age**: files not modified in 90+ days (`git log -1 --format=%as -- <file>`). Exclude `docs/JOURNAL/` — dated logbook entries are meant to age
   - **Stale claims**: content that contradicts the project's reality — tech mentioned that is absent from package.json/Cargo.toml/deps, referenced files or routes that no longer exist, counts that no longer match ("22 prototypes" when 3 remain). Spot-check each doc's boldest claims against the codebase; a doc describing the wrong stack misleads every future reader (human or agent) and is worse than no doc
   - **Coverage gaps** (the inverse check): recent shipped work — new modules, features, commands visible in the last ~20 commits — that no doc mentions. Missing docs are findings too, not just misplaced ones. Report as "undocumented: X" with a suggested destination
5. **Check for task-related issues** — if task folders/files use non-standard names, flag for renaming and suggest running `/pm-tasks` after
6. **Check docs/README.md** — does it exist? does it have documentation rules?
7. **Audit agent instruction files** — apply the CLAUDE.md / AGENTS.md hygiene rules (see "Agent instruction files" section): flag embedded code blocks, stale tech claims, and task tracking inside them
8. **Report everything:**

```
## Doctos Audit — [Project Name]

### Root violations — 4 files should move to docs/
| File | Suggested destination |
|------|---------------------|
| REFACTOR_PLAN.md | docs/ARCHITECTURE/REFACTOR_PLAN.md |
| DATABASE_LOCK_FIX.md | docs/ARCHIVED/DATABASE_LOCK_FIX.md |
| UI_UX_ANALYSIS.md | docs/RESEARCH/UI_UX_ANALYSIS.md |
| DEV-WORKFLOW.md | docs/GUIDES/DEV_WORKFLOW.md |

### Naming issues — 3 items need renaming
| Current | Standard |
|---------|----------|
| docs/archived/ | docs/ARCHIVED/ |
| docs/agents.md | docs/AGENTS.md (or move to root) |
| docs/features/spec.txt | docs/FEATURES/SPEC.md |

### Task-related renaming — 2 items (delegate to pm-tasks)
| Current | Standard |
|---------|----------|
| docs/COMPLETED_TASK/ | docs/TASK_COMPLETED/ |
| docs/TASKS/TODO.md | docs/TASK_TODO.md |
> After renaming, run `/pm-tasks` to audit task content

### Missing structure
- docs/README.md — no documentation index
- docs/GUIDES/ — no guides folder (5 guide-like files are loose in docs/)
- docs/ARCHIVED/ — no archive folder (obsolete files mixed with active ones)

### Potentially obsolete — 2 files (90+ days untouched)
| File | Last modified | Suggestion |
|------|--------------|------------|
| docs/OLD_API_DESIGN.md | 2025-11-15 | Archive with note |
| docs/PHASE_1_SETUP.md | 2026-01-20 | Archive — Phase 1 complete |

### Summary
| Category | Issues |
|----------|--------|
| Root violations | 4 |
| Naming issues | 3 |
| Task renaming | 2 |
| Missing structure | 3 |
| Potentially obsolete | 2 |
| **Total** | **14** |

> Run `/doctos clean` to fix all issues
```

### Classification logic for root violations

When a .md file at root needs to move, classify it into the right subfolder:

| Content signals | Destination |
|----------------|-------------|
| Architecture, schema, design, stack, decisions, patterns | `ARCHITECTURE/` |
| Feature spec, PRD, requirements, phase plan | `FEATURES/` |
| Setup, deploy, install, workflow, conventions, testing, onboarding | `GUIDES/` |
| Research, analysis, benchmark, comparison, evaluation | `RESEARCH/` |
| Fix report, migration complete, old implementation, summary of past work | `ARCHIVED/` |
| Unclear / mixed content | Read the file to decide — if still ambiguous, ask the user |

---

## Mode: CLEAN (`/doctos clean`)

Executes all fixes identified in the audit.

### Steps

1. **Run audit first** — build the full list of issues
2. **Show the execution plan** to the user and ask for confirmation:

```
## Doctos Clean Plan — [Project Name]

### Will move (root → docs/):
1. REFACTOR_PLAN.md → docs/ARCHITECTURE/REFACTOR_PLAN.md
2. DATABASE_LOCK_FIX.md → docs/ARCHIVED/DATABASE_LOCK_FIX.md (+ archival note)
3. UI_UX_ANALYSIS.md → docs/RESEARCH/UI_UX_ANALYSIS.md
4. DEV-WORKFLOW.md → docs/GUIDES/DEV_WORKFLOW.md (renamed: hyphen → underscore)

### Will rename:
5. docs/archived/ → docs/ARCHIVED/
6. docs/features/spec.txt → docs/FEATURES/SPEC.md (converted to markdown)

### Will rename (task-related):
7. docs/COMPLETED_TASK/ → docs/TASK_COMPLETED/
8. docs/TASKS/TODO.md → docs/TASK_TODO.md (+ delete empty TASKS/ folder)

### Will create:
9. docs/README.md (documentation index + writing rules)
10. docs/GUIDES/ (folder)

### Will archive (with note):
11. docs/OLD_API_DESIGN.md → docs/ARCHIVED/OLD_API_DESIGN.md

Proceed? (y/n)
```

3. **After confirmation, execute:**
   - Use `git mv` where possible to preserve history
   - Create missing folders
   - Rename files/folders to standard convention
   - Add archival notes to files moved to ARCHIVED/
   - Convert .txt files to .md
   - Rename hyphens to underscores in file names (`DEV-WORKFLOW.md` → `DEV_WORKFLOW.md`)
   - **Repair inbound references**: after every move or rename, search the whole project for the old path/filename (other docs, CLAUDE.md pointers, code comments) and update each reference to the new location. Moving a file without fixing its inbound links converts organization into breakage — this step is what makes the clean safe
   - Create docs/README.md with documentation index and writing rules
   - If task-related files were renamed, remind user: "Task folders renamed. Run `/pm-tasks` to audit task content."

4. **Post-clean report:**

```
## Doctos Clean Complete

- Moved: 4 files from root to docs/
- Renamed: 3 files/folders
- Created: 2 (docs/README.md, docs/GUIDES/)
- Archived: 1 file (with note)

> Task folders were renamed. Run `/pm-tasks` to verify task content is clean.
```

### Handling edge cases

**File name conflicts:** If moving `ARCHITECTURE.md` from root to `docs/ARCHITECTURE/` but `docs/ARCHITECTURE/ARCHITECTURE.md` already exists — ask the user whether to merge, rename, or skip.

**Non-markdown files in docs/:** Shell scripts (`.sh`), config files, images — these are fine. Only audit `.md` and `.txt` files.

**Nested project structures:** For workspaces with sub-projects (e.g., a monorepo with `backend_api/` and `browser_extension/`), audit each sub-project independently. Don't move sub-project docs to the workspace root.

---

## Mode: INIT (`/doctos init`)

Creates the standard docs structure. Like pm-tasks init, this both creates from scratch and standardizes existing setups.

### Steps

1. **Scan what exists** (same as audit detection)
2. **Branch:**

#### A) Nothing exists — fresh setup

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

#### B) Existing non-standard setup — standardize

Same as CLEAN mode but more aggressive:
- Run the full audit
- Show the migration plan
- Execute after confirmation
- Create any missing standard folders

3. **Write docs/README.md** with documentation index and writing rules:

```markdown
# [Project Name] — Documentation

> Documentation index and writing guidelines for this project.

## Structure

| Folder | Contents |
|--------|----------|
| `ARCHITECTURE/` | Technical architecture, decisions, schemas |
| `FEATURES/` | Active feature specs and PRDs |
| `GUIDES/` | Setup, deployment, coding conventions |
| `RESEARCH/` | Analysis, benchmarks, evaluations |
| `ARCHIVED/` | Obsolete docs (with archival notes) |
| `TASK_TODO.md` | Pending tasks (managed by pm-tasks) |
| `TASK_COMPLETED/` | Completed task archive (managed by pm-tasks) |

## Root-level files (only these)

README.md, CLAUDE.md, AGENTS.md, CONTRIBUTING.md, CHANGELOG.md, LICENSE

## Writing rules

1. **No .md files at project root** except the allowed list above
2. **UPPERCASE_SNAKE_CASE** for all doc file names (`CODING_RULES.md`, not `coding-rules.md`)
3. **UPPERCASE** for all doc subfolders (`GUIDES/`, not `guides/`)
4. **No task tracking outside TASK_TODO.md** — use `/pm-tasks` for task management
5. **No code blocks in documentation summaries** — reference file paths and function names
6. **Archive, don't delete** — obsolete docs go to `ARCHIVED/` with a note, not to the trash
7. **Feature specs move to ARCHIVED/** when the feature ships — the code is now the source of truth
```

4. **If task structure is missing**, suggest: "No task tracking found. Run `/pm-tasks init` to set up TASK_TODO.md and TASK_COMPLETED/."

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

- **Language matching.** If the project's docs are in Spanish, keep Spanish. Don't translate filenames or content. But do standardize the casing: `arquitectura-tecnica.md` → `ARQUITECTURA_TECNICA.md`.

- **Never clobber, always Edit.** When touching an existing file (adding an archival note, fixing a link, updating an index), use targeted edits with exact match on the current content — never rewrite the whole file from memory. A full rewrite silently drops entries you didn't notice; a failed exact-match edit fails loudly, which is the safe direction.

- **End every report with a status line.** `**Status: DONE**` clean; `DONE_WITH_CONCERNS` (+ one line why); `BLOCKED`; `NEEDS_CONTEXT` when only the user can decide. Standard terminal vocabulary that other skills and scripts can consume.

- **Surface everything.** The audit should catch every issue in one pass. The user shouldn't need to run it twice to find new problems. Be thorough.
