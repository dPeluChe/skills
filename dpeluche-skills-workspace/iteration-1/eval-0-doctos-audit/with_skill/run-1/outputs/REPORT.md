# Doctos Audit — Acme Dashboard

> Audit mode only — no files were moved, renamed, or modified.
> Project: `/Users/peluche/dPeluCheData/PROJECTS/dPeluChe/_code_/dpeluche-skills/dpeluche-skills-workspace/iteration-1/doctos-audit/with_skill/project`

### Root violations — 2 files should move to docs/

| File | Suggested destination | Reasoning |
|------|----------------------|-----------|
| `REFACTOR_PLAN.md` | `docs/ARCHITECTURE/REFACTOR_PLAN.md` | State-management migration plan (Redux → Zustand): architecture/decisions content |
| `UI_ANALYSIS.md` | `docs/RESEARCH/UI_ANALYSIS.md` | Benchmark of Grafana/Metabase/Retool layouts: research/comparison content |

Allowed root files present and correct: `README.md`. (`TODO.md` is also a root violation, but it is task-related — see the task section below.)

### Naming issues — 4 items need renaming

| Current | Standard |
|---------|----------|
| `docs/archived/` | `docs/ARCHIVED/` |
| `docs/features/` | `docs/FEATURES/` |
| `docs/features/spec.md` | `docs/FEATURES/SPEC.md` (or a more descriptive `AUTH_SPEC.md` — content is the auth feature spec) |
| `docs/setup-guide.md` | `docs/GUIDES/SETUP_GUIDE.md` (move into GUIDES/ + hyphen → underscore, uppercase) |

### Task-related renaming — 2 items (delegate content to pm-tasks)

| Current | Standard |
|---------|----------|
| `TODO.md` (root) | `docs/TASK_TODO.md` |
| `docs/tasks_completed/` | `docs/TASK_COMPLETED/` |

> Doctos only renames these; content is pm-tasks territory. After renaming, run `/pm-tasks` to audit task content. pm-tasks will also want to look at:
> - `docs/TASK_COMPLETED/` has no `README.md`
> - Task checkboxes living outside TASK_TODO.md: roadmap checkboxes in root `README.md`, checklist items in `docs/setup-guide.md` and `docs/features/spec.md`
> - `docs/tasks_completed/2026_05.md` contains a YAML code block (docs writing rules say no code blocks in summaries — pm-tasks decides)

### Missing structure

- `docs/README.md` — no documentation index or writing rules
- `docs/GUIDES/` — missing (needed for `setup-guide.md`)
- `docs/ARCHITECTURE/` — missing (needed for `REFACTOR_PLAN.md`)
- `docs/RESEARCH/` — missing (needed for `UI_ANALYSIS.md`)

### Archival issues — 1 file

| File | Issue |
|------|-------|
| `docs/archived/OLD_API.md` | Correctly archived (deprecated v1 API, replaced by v2) but missing the standard archival note header (`> **ARCHIVED** — date / reason / current reference`) |

No files qualify as obsolete by age (all files last modified 2026-07-18, under the 90-day threshold).

### Summary

| Category | Issues |
|----------|--------|
| Root violations | 2 |
| Naming issues | 4 |
| Task renaming | 2 |
| Missing structure | 4 |
| Archival notes | 1 |
| **Total** | **13** |

> Run `/doctos clean` to fix all issues. Then run `/pm-tasks` to audit task content.
