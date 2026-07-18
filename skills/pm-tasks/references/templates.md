# pm-tasks — Templates

Copy-paste templates used by INIT and ARCHIVE modes. Adapt project name and language to the project.

## TASK_TODO.md (fresh setup)

```markdown
# [Project Name] — Task Backlog

> Active task tracking for [project name].
> Completed tasks are archived in [TASK_COMPLETED/](./TASK_COMPLETED/) by month.

---

## Priority 1 — Current Sprint

### EXAMPLE-001: Task title `added: 2026-04-05`
- [ ] Sub-task description

## Priority 2 — Next Up

## Backlog

## Research & Ideas
```

## TASK_COMPLETED/README.md

```markdown
# Task Completed Archive

## Structure
- One file per month: `YYMM.md` (e.g., `2604.md` = April 2026)
- Tasks grouped by completion date

## Rules
1. **One file per month** — All tasks completed in that month go in a single file
2. **Date each section** — Group by completion date: `## YYYY-MM-DD: Description`
3. **Use task keys** — Reference the key from TASK_TODO.md
4. **Detail what was done** — Completed items as `- [x]` checkboxes
5. **Include context** — Brief notes on decisions and changes made
6. **No code blocks** — Reference file paths and function names, not code
7. **Move, don't copy** — Remove completed tasks from TASK_TODO.md when archiving here
8. **Preserve the `added:` date** — When archiving, keep the original creation date so the archive shows how long the task lived in the backlog
```

## Rich session-based archive format (optional)

For architectural changes or multi-day work, this format preserves the "why" behind decisions and the alternatives that were discarded. For small tasks, the simple format in SKILL.md is enough.

```markdown
## YYYY-MM-DD: Session title

### Context
Why this work was done. What problem triggered it.

### Completed
### TASK-KEY: Task Title
- [x] Items completed

### Decisions
What was decided and why. Include discarded alternatives if they matter.

### Files Changed
- `file.rs` — one-line description of change
- `new_file.rs` — NEW: what it does
```
