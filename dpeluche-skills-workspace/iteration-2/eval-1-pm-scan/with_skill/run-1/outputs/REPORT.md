# Task Audit + Scan — Acme Dashboard

**Date**: 2026-07-18
**Mode**: Audit + full scan (read-only, no changes made)
**Task file found**: `TODO.md` at root (non-standard — should be `docs/TASK_TODO.md`)
**Archive found**: `docs/tasks_completed/` (non-standard — should be `docs/TASK_COMPLETED/`)
**Task keys**: Mostly plain checkboxes; one key in use (`UI-2`)
**Language**: English

---

## Task counts (across all sources)

| Source | Pending | Completed |
|--------|---------|-----------|
| TODO.md (root) | 2 | 1 |
| README.md — "Roadmap" | 3 | 2 |
| CLAUDE.md — "Pending work" | 2 | 1 |
| docs/features/spec.md | 2 | 1 |
| Code TODOs (src/) | 3 | — |
| **Total** | **12 (2 code TODOs untracked)** | **5** |

No task carries an `added:` date, so staleness cannot be assessed. Suggest baselining all with `added: 2026-07-18` during centralization.

---

## Part 1: Code TODOs — 3 found (1 already tracked)

### Untracked (should be added to TASK_TODO.md)
| File | Line | Comment |
|------|------|---------|
| src/auth.ts | 2 | `TODO: add rate limiting to login endpoint` |
| src/auth.ts | 5 | `FIXME: token refresh fails silently when offline` |

### Already tracked
| File | Line | Matches |
|------|------|---------|
| src/chart.tsx | 1 | `TODO(UI-2)` → `UI-2: Fix chart resize on window change` in TODO.md |

---

## Part 2: Scattered task files — 1 found

### TODO.md (root) ⚠️
- 3 items: 2 pending, 1 completed (`[x] Setup CI pipeline`)
- Non-standard name and location. Recommendation: migrate content to `docs/TASK_TODO.md`, archive the completed CI item, remove file.
- Note: `[x] Setup CI pipeline` duplicates CLAUDE.md's `[x] Set up CI` and is already recorded in the archive (`2026_05.md: Setup GitHub Actions`) — archive once, drop the duplicates.

(`REFACTOR_PLAN.md` and `UI_ANALYSIS.md` at root contain no task checklists — not task files. They are planning/analysis docs; no action from this skill, though the Zustand migration plan relates to CLAUDE.md's pending migration task — worth linking from the task when centralized.)

---

## Part 3: Markdown contamination — 4 files with checkboxes, 3 flagged

### README.md ⛔ (protected zone)
- "Roadmap" section: 3 pending (`Add user authentication`, `Dark mode support`, `Implement OAuth flow with Google`), 2 completed (`Basic chart rendering`, `CSV export`)
- Action: extract pending → TASK_TODO.md, completed → archive; remove section; add `> Task tracking: see docs/TASK_TODO.md`

### CLAUDE.md ⛔ (protected zone — highest priority)
- "Pending work" section: 2 pending (`Migrate legacy Redux slices to the new store`, `Add e2e tests with Playwright`), 1 completed (`Set up CI`)
- This file loads into every agent session — a stale task list here misleads every future session
- Side observation: CLAUDE.md states "State management: Redux" but package.json already depends on `zustand` (no redux dep listed) — the instructions may be stale beyond the task list
- Action: extract tasks, remove section, add reference line

### docs/features/spec.md ⚠️ (feature spec)
- 2 pending (`Implement session storage`, `Add password reset flow`), 1 completed (`Define user roles`)
- These are actionable tasks disguised as requirements
- Action: extract to TASK_TODO.md / archive; replace with reference note

### docs/setup-guide.md ✅ (legitimate)
- 3 checkboxes — all installation steps (`Install Node.js 18+`, etc.), not tasks
- Action: none

---

## Duplicate / mergeable tasks — 2 groups

### Group 1: CI setup (3 mentions of the same completed work)
- TODO.md: `[x] Setup CI pipeline`
- CLAUDE.md: `[x] Set up CI`
- docs/tasks_completed/2026_05.md: `Setup GitHub Actions` (already archived)
> Already archived once. Just delete the two stray `[x]` entries during cleanup — no re-archiving needed.

### Group 2: Authentication (4 tasks → suggest merge into one AUTH task)
- README.md: `Add user authentication`
- README.md: `Implement OAuth flow with Google`
- spec.md: `Implement session storage`
- spec.md: `Add password reset flow`
> All one feature. Suggest a single task, e.g. **AUTH-001: User authentication** with sub-items (OAuth flow, session storage, password reset), linking to `docs/features/spec.md` for requirements. The untracked `src/auth.ts` TODOs (rate limiting, offline token refresh) are auth-adjacent — could join as sub-items or a sibling AUTH-002 hardening task.

---

## Structural issues

1. ⚠️ No `docs/TASK_TODO.md` — the actual task file is `TODO.md` at root (wrong name + location)
2. ⚠️ Archive folder is lowercase `docs/tasks_completed/` — rename to `docs/TASK_COMPLETED/`
3. ⚠️ Archive file `2026_05.md` uses non-standard naming — rename to `2605.md`
4. ⚠️ Archive file contains a YAML code block — violates "no code blocks in archives"; replace with a file reference (e.g., "Added `.github/workflows/ci.yml`")
5. ⚠️ No `README.md` in the archive folder (format rules reference)
6. ⚠️ Protected-zone contamination in README.md and CLAUDE.md (detailed above)
7. ⚠️ No task has an `added:` date — staleness tracking impossible
8. ⚠️ No cross-reference between TODO file and archive

---

## Proposed centralization plan (nothing executed yet)

1. **Create** `docs/TASK_TODO.md` as single source of truth, consolidating:
   - From TODO.md: `UI-2: Fix chart resize` (already keyed, code-linked), `Add error boundary to dashboard`
   - From README.md: `Dark mode support` + auth items (merged, see below)
   - From CLAUDE.md: `Migrate legacy Redux slices to Zustand` (link REFACTOR_PLAN.md), `Add e2e tests with Playwright`
   - From spec.md + README.md: merged **AUTH-001: User authentication** (OAuth, session storage, password reset)
   - From code: `src/auth.ts` rate limiting + offline token-refresh FIXME
   - Tag everything `added: 2026-07-18` as baseline
2. **Standardize archive**: `git mv docs/tasks_completed docs/TASK_COMPLETED`, rename `2026_05.md` → `2605.md`, strip the YAML block, add `TASK_COMPLETED/README.md`
3. **Archive completed strays**: `Basic chart rendering`, `CSV export`, `Define user roles` → `2607.md` (completion month unknown; note as backfilled). Drop duplicate CI entries (already in 2605).
4. **Clean protected zones**: remove Roadmap checklist from README.md and Pending-work section from CLAUDE.md; add `> Task tracking: see docs/TASK_TODO.md` to each
5. **Clean spec.md**: replace checklist with a reference to AUTH-001
6. **Delete** root TODO.md after migration
7. Leave `docs/setup-guide.md` untouched (legitimate guide steps)

Adopting module-keyed format (UI-, AUTH-, INFRA-, TEST-) is suggested since `UI-2` already exists, but optional.

**Nothing was modified.** Run `/pm-tasks init` + `/pm-tasks archive` (or confirm this plan) to execute.
