# Task State Report — Acme Dashboard

Scanned: all files under `project/` (5 root .md, 4 docs .md, 2 source files). Read-only audit; nothing changed.

## 1. Code TODOs (2 files, 3 items)

| Location | Marker | Item | Tracked in TODO.md? |
|---|---|---|---|
| `src/auth.ts:2` | TODO | Add rate limiting to login endpoint | No |
| `src/auth.ts:5` | FIXME | Token refresh fails silently when offline | No |
| `src/chart.tsx:1` | TODO(UI-2) | Chart doesn't resize on window change | Yes (UI-2) |

## 2. TODO.md status (stale in 1 place)

- `[x] Setup CI pipeline` — **done and already archived** in `docs/tasks_completed/2026_05.md` (2026-05-10). Should be removed from TODO.md; this is the staleness.
- `[ ] UI-2: Fix chart resize` — open, correctly matches `src/chart.tsx`. Healthy pattern.
- `[ ] Add error boundary to dashboard` — open, no code marker (fine).

## 3. Tasks scattered in markdown files

**README.md → Roadmap** (open items not in TODO.md):
- Add user authentication
- Dark mode support
- Implement OAuth flow with Google

**docs/features/spec.md** (auth spec, open items not in TODO.md):
- Implement session storage
- Add password reset flow
- (`[x] Define user roles` — done)

Note: README's "user authentication" and the auth spec overlap — likely one epic with sub-tasks.

**docs/setup-guide.md** — has checkboxes, but they are install instructions, not tasks. Do NOT centralize.

**docs/archived/OLD_API.md** — deprecated doc, no tasks. Correctly archived.

**docs/tasks_completed/2026_05.md** — archive of completed work. Working as intended.

## 4. Untracked planning docs at root

- `REFACTOR_PLAN.md` — Redux → Zustand migration. Real planned work with **zero presence in TODO.md**.
- `UI_ANALYSIS.md` — benchmark/research doc; recommendations may imply tasks but none captured.

Both are also root-level clutter; candidates for `docs/` (e.g. `docs/features/` or `docs/research/`).

## 5. What I'd centralize (proposed, no changes made)

Single source of truth: **TODO.md**. Proposed consolidated backlog:

- [ ] UI-2: Fix chart resize on window change (`src/chart.tsx:1`)
- [ ] Add error boundary to dashboard
- [ ] Add rate limiting to login endpoint (`src/auth.ts:2`)
- [ ] FIX: Token refresh fails silently when offline (`src/auth.ts:5`)
- [ ] Auth epic: user authentication (from README)
  - [ ] Implement session storage (spec.md)
  - [ ] Add password reset flow (spec.md)
  - [ ] OAuth flow with Google (README)
- [ ] Dark mode support (from README)
- [ ] Migrate Redux → Zustand (from REFACTOR_PLAN.md)

Cleanup actions to go with it:
1. Drop `[x] Setup CI pipeline` from TODO.md (already archived in `docs/tasks_completed/2026_05.md`).
2. Replace README Roadmap open items with a pointer to TODO.md (keep or archive the `[x]` shipped items).
3. Keep spec.md as the auth spec but mirror its open items in TODO.md, or link them by ID like UI-2.
4. Move `REFACTOR_PLAN.md` and `UI_ANALYSIS.md` into `docs/`.
5. Leave code TODOs in place but give each a TODO.md entry/ID — the UI-2 pattern is the good example; extend it.
