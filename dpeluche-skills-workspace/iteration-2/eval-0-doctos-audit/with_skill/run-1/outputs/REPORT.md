# Doctos Audit — Acme Dashboard

> Audit only — no files were changed. Run `/doctos clean` to execute fixes.

## Root violations — 3 files should move to docs/

| File | Suggested destination | Reason |
|------|----------------------|--------|
| `REFACTOR_PLAN.md` | `docs/ARCHIVED/REFACTOR_PLAN.md` (+ archival note) | Plan to migrate Redux → Zustand, but `package.json` already ships `zustand` and has no Redux dep, and no `redux` references exist in `src/`. Migration appears complete — the spec is obsolete. If the user says the migration is still in flight, destination becomes `docs/ARCHITECTURE/REFACTOR_PLAN.md` instead. |
| `UI_ANALYSIS.md` | `docs/RESEARCH/UI_ANALYSIS.md` | Benchmark of Grafana/Metabase/Retool — research content. |
| `TODO.md` | `docs/TASK_TODO.md` | Task tracking belongs in pm-tasks' standard location (see Task-related section). |

Allowed root files present and staying: `README.md`, `CLAUDE.md`. Non-md files (`package.json`, `src/`) are out of scope.

## Naming issues — 4 items need renaming

| Current | Standard |
|---------|----------|
| `docs/archived/` | `docs/ARCHIVED/` |
| `docs/features/` | `docs/FEATURES/` |
| `docs/features/spec.md` | `docs/FEATURES/SPEC.md` — though see "Potentially obsolete": likely `AUTH_SPEC.md` for clarity if kept |
| `docs/setup-guide.md` | `docs/GUIDES/SETUP_GUIDE.md` (move loose file into GUIDES/ + hyphen → underscore, uppercase) |

## Task-related renaming — 2 items (delegate to pm-tasks)

| Current | Standard |
|---------|----------|
| `docs/tasks_completed/` | `docs/TASK_COMPLETED/` |
| `TODO.md` (root) | `docs/TASK_TODO.md` |

Notes:
- `docs/TASK_COMPLETED/README.md` is missing (standard structure expects it — pm-tasks territory).
- Content inside `docs/tasks_completed/2026_05.md` is untouched by doctos.
- After renaming, run `/pm-tasks` to audit task content. pm-tasks will also want to pick up:
  - Roadmap checkboxes in `README.md` (task tracking in a non-task file).
  - Code TODOs: `src/auth.ts` (rate limiting TODO + silent token-refresh FIXME), `src/chart.tsx` (`TODO(UI-2)` — matches the open `UI-2` item in `TODO.md`).

## Agent instruction file issues — CLAUDE.md (3 violations)

| Issue | Detail | Fix |
|-------|--------|-----|
| Stale tech claim | Claims "State management: Redux with redux-toolkit slices" — `package.json` has `zustand`, no Redux anywhere in deps or `src/`. This misleads every agent session. | Update Stack section to Zustand. |
| Embedded code block | Full deploy bash script pasted inline (S3 sync + CloudFront invalidation). No `scripts/` dir exists, so the script lives only here and will go stale silently. | Move to `scripts/deploy.sh`, reference by path. |
| Task tracking | "Pending work" checklist (Redux migration, Playwright e2e, CI) inside CLAUDE.md. | Move items to `docs/TASK_TODO.md` via pm-tasks. Note: "Migrate legacy Redux slices" also contradicts the current stack. |

## Missing structure

- `docs/README.md` — no documentation index / writing rules.
- `docs/GUIDES/` — missing (needed for `setup-guide.md`).
- `docs/RESEARCH/` — missing (needed for `UI_ANALYSIS.md`).
- `docs/ARCHITECTURE/` — only needed if `REFACTOR_PLAN.md` is judged still active; don't create speculatively.

## Potentially obsolete / stale content

Git age check was inconclusive: all 9 .md files are untracked (never committed), so `git log -1` returns no dates. Findings below are from stale-claims analysis:

| File | Signal | Suggestion |
|------|--------|------------|
| `REFACTOR_PLAN.md` | Zustand already in deps, Redux absent — plan appears shipped | Archive with note (confirm with user) |
| `docs/features/spec.md` | Auth spec, but README roadmap still lists "Add user authentication" as pending — spec likely still active | Keep in `FEATURES/` (rename only); archive when auth ships |
| `docs/archived/OLD_API.md` | Correctly archived, but missing the standard archival note header (date, reason, replacement link) | Add archival note on top |
| `CLAUDE.md` | Redux claims (see above) | Update in place |

## Summary

| Category | Issues |
|----------|--------|
| Root violations | 3 |
| Naming issues | 4 |
| Task-related renaming | 2 |
| CLAUDE.md hygiene | 3 |
| Missing structure | 3 |
| Obsolete / stale | 3 |
| **Total** | **18** |

### Recommended order of operations
1. `/doctos clean` — moves, renames, missing folders, docs/README.md, archival notes (asks confirmation per plan; note these files are currently untracked, so plain `mv` — not `git mv` — applies until a first commit).
2. Fix `CLAUDE.md` content (stack claim, deploy script extraction, remove task list).
3. `/pm-tasks` — audit task content, absorb README roadmap + code TODOs into `TASK_TODO.md`.
