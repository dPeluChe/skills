# Documentation Structure Audit

Project: `.../doctos-audit/without_skill/project`
Date: 2026-07-18 — audit only, no changes made.

## Inventory (8 markdown files)

| File | Location | Verdict |
|---|---|---|
| README.md | root | OK at root; content issues (see below) |
| TODO.md | root | Misplaced — move to `docs/` |
| REFACTOR_PLAN.md | root | Misplaced — planning doc, belongs in `docs/` |
| UI_ANALYSIS.md | root | Misplaced — research doc, belongs in `docs/` |
| docs/setup-guide.md | docs/ | Naming inconsistent; overlaps README Setup |
| docs/features/spec.md | docs/features/ | Name too generic (it is the Auth spec) |
| docs/archived/OLD_API.md | docs/archived/ | Correctly archived; naming inconsistent with folder |
| docs/tasks_completed/2026_05.md | docs/tasks_completed/ | OK concept; naming inconsistent |

## Findings

### 1. Root clutter
Only project-standard files (README, CHANGELOG, CONTRIBUTING, LICENSE, CLAUDE/AGENTS) should live at root. Three working docs are scattered there:
- `TODO.md` → suggested: `docs/TODO.md` (or a tasks folder alongside `tasks_completed/`)
- `REFACTOR_PLAN.md` → suggested: `docs/architecture/` or `docs/plans/`
- `UI_ANALYSIS.md` → suggested: `docs/research/`

### 2. Inconsistent naming conventions
Three styles coexist — pick one and apply everywhere:
- lowercase-kebab: `setup-guide.md`
- lowercase_snake: `tasks_completed/`, `2026_05.md`
- UPPERCASE_SNAKE: `TODO.md`, `REFACTOR_PLAN.md`, `UI_ANALYSIS.md`, `OLD_API.md`

Also: folders are lowercase (`archived/`, `features/`, `tasks_completed/`) while some files inside are uppercase (`archived/OLD_API.md`). Recommendation: one convention (e.g. UPPERCASE_SNAKE for files with UPPERCASE folders, or all-lowercase; consistency matters more than the choice).

### 3. Generic / unclear filenames
- `docs/features/spec.md` is specifically the **auth** feature spec → rename to `AUTH_SPEC.md` (or `auth-spec.md`). "spec.md" won't scale once a second feature spec exists.

### 4. Content duplication and drift
- **Roadmap in README vs TODO.md**: README has its own roadmap checklist ("Add user authentication", "Dark mode", "OAuth flow") that overlaps TODO.md and `docs/features/spec.md`. Two task lists will drift — keep tasks in one place, link from README.
- **Completed task still listed in TODO.md**: `[x] Setup CI pipeline` is already archived in `docs/tasks_completed/2026_05.md`. Completed items should be removed from TODO.md once archived.
- **Setup instructions duplicated**: README "Setup" section and `docs/setup-guide.md` cover the same ground (npm install / env). Consolidate: full guide in docs, one-liner + link in README.

### 5. Untracked code TODOs
`TODO.md` tracks `UI-2` (matches `src/chart.tsx:1`) but two code TODOs have no tracking entry:
- `src/auth.ts:2` — "add rate limiting to login endpoint"
- `src/auth.ts:5` — FIXME: "token refresh fails silently when offline"

Add these to TODO.md so they aren't lost.

### 6. Minor / structural gaps
- No `CHANGELOG.md` despite versioned package (`0.3.0`) — optional but useful.
- `docs/archived/OLD_API.md` says "replaced by v2" but no v2 API doc exists — the current API design is undocumented.
- No cross-links between docs (README doesn't link to `docs/`). No file references another, so renames/moves are currently zero-risk.

## Suggested target structure

```
README.md                      (setup one-liner + links to docs/)
CHANGELOG.md                   (optional, new)
docs/
  TODO.md                      (from root; add auth.ts TODOs; drop done items)
  ARCHITECTURE/REFACTOR_PLAN.md
  RESEARCH/UI_ANALYSIS.md
  FEATURES/AUTH_SPEC.md        (renamed from features/spec.md)
  GUIDES/SETUP_GUIDE.md        (renamed; absorbs README setup detail)
  TASKS_COMPLETED/2026_05.md
  ARCHIVED/OLD_API.md
```

## Fix checklist (ordered, low-risk first)
1. Choose the naming convention (one only, applied everywhere).
2. Move `TODO.md`, `REFACTOR_PLAN.md`, `UI_ANALYSIS.md` into `docs/` subfolders.
3. Rename `spec.md` → auth-specific name; normalize `setup-guide.md` and folder names.
4. Deduplicate: drop README roadmap in favor of TODO.md; slim README setup, link to guide.
5. Clean TODO.md: remove archived CI item; add the two untracked `src/auth.ts` items.
6. Optionally add CHANGELOG.md and a v2 API doc (or note where it lives).
