# Doctos, output templates (load when producing a report or running CLEAN/INIT)

The reasoning for each mode lives in `SKILL.md`. These are the output formats, kept here so the
always-loaded skill stays lean. Load this file at the report/output step of a mode, not before.

## AUDIT report format

```
## Doctos Audit: [Project Name]

### Root violations: 4 files should move to docs/
| File | Suggested destination |
|------|---------------------|
| REFACTOR_PLAN.md | docs/ARCHITECTURE/REFACTOR_PLAN.md |
| DATABASE_LOCK_FIX.md | docs/ARCHIVED/DATABASE_LOCK_FIX.md |
| UI_UX_ANALYSIS.md | docs/RESEARCH/UI_UX_ANALYSIS.md |
| DEV-WORKFLOW.md | docs/GUIDES/DEV_WORKFLOW.md |

### Naming issues: 3 items need renaming
| Current | Standard |
|---------|----------|
| docs/archived/ | docs/ARCHIVED/ |
| docs/agents.md | docs/AGENTS.md (or move to root) |
| docs/features/spec.txt | docs/FEATURES/SPEC.md |

### Task-related renaming: 2 items (delegate to pm-tasks)
| Current | Standard |
|---------|----------|
| docs/COMPLETED_TASK/ | docs/TASK_COMPLETED/ |
| docs/TASKS/TODO.md | docs/TASK_TODO.md |
> After renaming, run `/pm-tasks` to audit task content

### Missing structure
- docs/README.md: no documentation index
- docs/GUIDES/: no guides folder (5 guide-like files sit directly in `docs/`, not in a subfolder: SETUP.md, DEPLOY.md, TESTING.md, …)
- docs/ARCHIVED/: no archive folder (obsolete files mixed with active ones)

### Potentially obsolete: 2 files (90+ days untouched)
| File | Last modified | Suggestion |
|------|--------------|------------|
| docs/OLD_API_DESIGN.md | 2025-11-15 | Archive with note |
| docs/PHASE_1_SETUP.md | 2026-01-20 | Archive: Phase 1 complete |

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

## CLEAN plan format (shown for confirmation before executing)

```
## Doctos Clean Plan: [Project Name]

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

## CLEAN post-clean report format

```
## Doctos Clean Complete

- Moved: 4 files from root to docs/
- Renamed: 3 files/folders
- Created: 2 (docs/README.md, docs/GUIDES/)
- Archived: 1 file (with note)

> Task folders were renamed. Run `/pm-tasks` to verify task content is clean.
```

## INIT docs/README.md template (the file INIT writes)

```markdown
# [Project Name]: Documentation

> Documentation index and writing guidelines for this project.

## Structure

> Derived from `.doctos.yml` at the repo root. Edit that file, not this table.

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
4. **No task tracking outside TASK_TODO.md**: use `/pm-tasks` for task management
5. **No code blocks in documentation summaries**: reference file paths and function names
6. **Archive, don't delete**: obsolete docs go to `ARCHIVED/` with a note, not to the trash
7. **Feature specs move to ARCHIVED/** when the feature ships: the code is now the source of truth
```

The rows come from the `folders:` block of `.doctos.yml`, and the naming rules from its
`naming:` key. Do not hand-write a table that disagrees with the file: it drifts, and then
neither one is trusted.

For a content repo (see `SKILL.md`, "Repo type"), adapt this template: the structure table reflects the domain folders that fit the material, not the technical taxonomy, and the folder names match the audience's language (`archivo/`, `guias/`), not UPPERCASE English.
