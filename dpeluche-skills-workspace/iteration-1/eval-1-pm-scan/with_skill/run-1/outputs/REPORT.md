# Task Audit & Scan — Acme Dashboard

**Date**: 2026-07-18 · **Mode**: read-only report (no changes made)

**Task file**: `TODO.md` at root (non-standard — should be `docs/TASK_TODO.md`)
**Archive**: `docs/tasks_completed/` (non-standard — should be `docs/TASK_COMPLETED/`)
**Task keys**: mixed — one keyed task (`UI-2`), rest are plain checkboxes
**Language**: English

---

## Task counts (in TODO.md)

- Pending: 2 (`UI-2: Fix chart resize on window change`, `Add error boundary to dashboard`)
- Completed, still sitting in TODO.md: 1 (`Setup CI pipeline`)
- No task carries an `added:` date — staleness tracking is impossible right now

### Stale completed task

`- [x] Setup CI pipeline` is already recorded in the archive (`docs/tasks_completed/2026_05.md`, entry "2026-05-10: CI pipeline") but was never removed from TODO.md. It just needs deletion from TODO.md — no re-archiving.

---

## Part 1: Code TODOs — 3 found (1 already tracked)

### Untracked (should be added to TASK_TODO.md)

| File | Line | Comment |
|------|------|---------|
| `src/auth.ts` | 2 | `TODO: add rate limiting to login endpoint` |
| `src/auth.ts` | 5 | `FIXME: token refresh fails silently when offline` |

### Already tracked

| File | Line | Matches |
|------|------|---------|
| `src/chart.tsx` | 1 | `TODO(UI-2)` → `UI-2` in TODO.md ✅ |

---

## Part 2: Scattered task files — 1 found

### `TODO.md` (root)

- 3 items: 2 pending, 1 completed (already archived, see above)
- This IS the current backlog, just misnamed and misplaced
- Recommendation: migrate to `docs/TASK_TODO.md` (git mv to keep history), drop the archived CI item

`REFACTOR_PLAN.md` and `UI_ANALYSIS.md` at root contain no task checklists — they are planning/analysis docs, not shadow backlogs. No task action needed (their root location is a docs-organization matter, out of scope here).

---

## Part 3: Markdown contamination — 4 files with checkboxes

### `README.md` ⛔ protected zone

- "## Roadmap" section: 3 pending, 2 completed
  - Pending: Add user authentication · Dark mode support · Implement OAuth flow with Google
  - Completed: Basic chart rendering · CSV export
- Action: extract pending → TASK_TODO.md, completed → archive, remove the Roadmap section, leave `> Task tracking: see [docs/TASK_TODO.md](./docs/TASK_TODO.md)`

### `docs/features/spec.md` — flagged

- 2 pending (Implement session storage, Add password reset flow), 1 completed (Define user roles)
- These are actionable tasks, not requirements prose
- Action: extract to TASK_TODO.md / archive, replace with a dated reference line pointing to the task keys

### `docs/setup-guide.md` ✅ legitimate

- 3 checkboxes, all installation steps ("Install Node.js 18+", etc.) — guide steps, not tasks. Skip.

### `docs/tasks_completed/2026_05.md` — archive itself

- Legitimate location for `[x]` items, but see structural issues below (naming + code block).

---

## Duplicate / Mergeable tasks — 1 group

**Auth cluster (4 tasks across 2 files → suggest 1 unified task):**
- README.md: "Add user authentication"
- README.md: "Implement OAuth flow with Google"
- docs/features/spec.md: "Implement session storage"
- docs/features/spec.md: "Add password reset flow"

> All belong to the same authentication feature (`src/auth.ts`). Suggest merging into one keyed task, e.g. **AUTH-001: Authentication system** with sub-items (OAuth flow, session storage, password reset, rate limiting from the code TODO). The two `src/auth.ts` code TODOs naturally fold into it too.

---

## Structural issues

1. ⚠️ **Location/naming**: `TODO.md` at root → should be `docs/TASK_TODO.md`
2. ⚠️ **Archive folder lowercase**: `docs/tasks_completed/` → `docs/TASK_COMPLETED/`
3. ⚠️ **Archive file naming**: `2026_05.md` → `2605.md` (YYMM format)
4. ⚠️ **Code block in archive**: `2026_05.md` contains a yaml code fence — replace with a reference ("Added `.github/workflows/ci.yml` with push trigger")
5. ⚠️ **Missing archive README**: no `docs/TASK_COMPLETED/README.md` with format rules
6. ⚠️ **Stale completed task** in TODO.md (already archived — just remove)
7. ⚠️ **No cross-reference**: TODO.md doesn't link to the archive
8. ⚠️ **Missing dates**: 0 of 2 pending tasks have `added:` tags — suggest baselining with today's date
9. ⛔ **README contamination**: Roadmap task list in protected zone
10. ⚠️ **Markdown contamination**: `docs/features/spec.md` carries a live task list

---

## Proposed centralization plan (pending your OK — nothing changed yet)

1. `git mv TODO.md docs/TASK_TODO.md`; remove the archived CI item; add archive cross-reference header
2. `git mv docs/tasks_completed docs/TASK_COMPLETED`; rename `2026_05.md` → `2605.md`; strip the yaml code block; add `README.md` with format rules
3. Extract README.md Roadmap: 3 pending → TASK_TODO.md, 2 completed → `2605.md` (or a new dated entry); replace section with a one-line reference
4. Extract `docs/features/spec.md` tasks the same way; leave a dated reference to the new task keys
5. Add the 2 untracked `src/auth.ts` TODOs to TASK_TODO.md with `added: 2026-07-18`
6. Merge the 4 auth-related tasks + 2 auth code TODOs into a single **AUTH-001: Authentication system** task with sub-items
7. Tag all pending tasks with `added: 2026-07-18` as a staleness baseline

Resulting backlog after centralization: ~4 well-scoped pending tasks (AUTH-001, UI-2, error boundary, dark mode) in one file, one clean monthly archive.
