# pm-tasks — Report Format Examples

Full example reports for AUDIT and SCAN modes. Match this structure and level of detail; adapt language and task keys to the project.

## AUDIT report example

```
## Task Audit — [Project Name]

**Location**: docs/TASK_TODO.md
**Archive**: docs/TASK_COMPLETED/ (3 files: 2602, 2603, 2604)
**Task keys**: DOMAIN-NNN format
**Language**: Spanish

### Task counts
- Pending: 12 tasks (3 without dates)
- Completed (ready to archive): 4 tasks

### Ready to archive:
- [x] KB-004: Cross-domain search implementation
- [x] PERF-002: SQL index optimization

### Stale tasks:
- ⚠️ UI-003: Change login button style `added: 2026-02-15` — 49 days old
- 🔴 SYNC-001: Implement real-time sync `added: 2025-12-20` — 106 days, dormant

### Duplicate / Mergeable:
- Group 1: UI-003 + UI-007 + UI-012 → all touch LoginForm.tsx, suggest merge

### Structural issues:
1. ⚠️ MIGRATION_TASKS.md found at packages/api/ — consolidate
2. ⚠️ Archive file 2026_04.md uses non-standard naming — rename to 2604.md
3. ⚠️ 3 tasks missing `added:` date — suggest adding today's date as baseline

### Recommendations:
- Run `/pm-tasks archive` to move 4 completed tasks
- Review 2 stale/dormant tasks
- Consider merging 1 task group
- Run `/pm-tasks init` to fix structural issues

**Status: DONE**
```

## SCAN report example

```
## Scan Results — [Project Name]

### Part 1: Code TODOs — 7 found (2 already tracked)

#### Untracked:
| File | Line | Comment |
|------|------|---------|
| src/auth/service.rs | 45 | TODO: Add rate limiting to token refresh |
| src/ui/Dashboard.tsx | 23 | FIXME: Chart doesn't resize on window change |

#### Already in TASK_TODO.md:
| File | Line | Matches |
|------|------|---------|
| src/sync/engine.rs | 89 | TODO(SYNC-2) → SYNC-2 in backlog |

### Part 2: Scattered task files — 2 found

#### packages/api/MIGRATION_TASKS.md
- 8 tasks total: 6 completed, 2 pending
- Recommendation: archive 6 → 2604.md, merge 2 pending → TASK_TODO.md

#### old_TODO.md (root)
- 3 tasks, all completed
- Recommendation: archive all → 2603.md, delete file

### Part 3: Markdown contamination — 3 files flagged

#### README.md ⛔ (protected zone)
- Found: 5 pending tasks, 8 completed tasks in "## Roadmap" section
- Action: extract all → TASK_TODO.md / TASK_COMPLETED, remove section, add reference

#### docs/features/26_april_agents_tasks.md
- Found: 12 pending, 4 completed
- Action: extract tasks → TASK_TODO.md / TASK_COMPLETED, replace with reference

#### docs/SETUP.md ✅ (legitimate)
- Found: 6 checkboxes — all are installation steps, not tasks
- Action: none (guide steps, not task tracking)

---

> Want me to centralize everything? I'll:
> 1. Add 5 code TODOs to TASK_TODO.md
> 2. Consolidate 2 scattered task files
> 3. Clean 2 contaminated markdown files (extract tasks + add references)

**Status: DONE_WITH_CONCERNS** — SETUP.md checkboxes kept (guide steps)
```
