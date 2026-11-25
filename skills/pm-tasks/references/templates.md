# pm-tasks: Templates

Copy-paste templates used by INIT and ARCHIVE modes. Adapt project name and language to the project.

## TASK_TODO.md (fresh setup)

```markdown
# [Project Name]: Task Backlog

> Active task tracking for [project name].
> Completed tasks are archived in [TASK_COMPLETED/](./TASK_COMPLETED/) by month.

---

## Priority 1: Current Sprint

### EXAMPLE-001: Task title `added: 2026-04-05`
- [ ] Sub-task description

## Priority 2: Next Up

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
1. **One file per month**: all tasks completed in that month go in a single file
2. **Date each section**: group by completion date: `## YYYY-MM-DD: Description`
3. **Use task keys**: reference the key from TASK_TODO.md
4. **Detail what was done**: completed items as `- [x]` checkboxes
5. **Include context**: brief notes on decisions and changes made
6. **No code blocks**: reference file paths and function names, not code
7. **Move, don't copy**: remove completed tasks from TASK_TODO.md when archiving here
8. **Preserve the `added:` date**: when archiving, keep the original creation date so the archive shows how long the task lived in the backlog
```

## Rich session-based archive format (optional)

For architectural changes or multi-day work, this format preserves the "why" behind decisions and the alternatives that were discarded. For small tasks, the Archive entry format below is enough.

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
- `file.rs`: one-line description of change
- `new_file.rs`: NEW: what it does
```

## Archive entry format (ARCHIVE writes this to YYMM.md)

```markdown
## YYYY-MM-DD: Brief description of what was completed

### TASK-KEY: Task Title
- [x] Specific completed item
- [x] Another completed item
- [x] Modified `path/to/file.rs`, added `function_name()` for feature X

Notes: Brief context about why this was done, key decisions, dependencies resolved. Reference commit hashes if relevant (commit abc1234).
```

## Task date format

Every task should carry its creation date using the `added:` tag. This enables staleness detection and helps prioritize the backlog.

**For tasks with headers (module-keyed or numbered):**
```markdown
### KB-004: Knowledge Base Improvements `added: 2026-03-18`
- [ ] Implement cross-domain search
- [ ] Add brief versioning
```

**For simple checkbox tasks without headers:**
```markdown
- [ ] Fix login timeout on mobile `added: 2026-04-01`
```

The `added:` tag goes at the end of the task title line, in backticks so it renders as inline code and is visually distinct from the task description. When creating new tasks (via SCAN or manually), always include the date. When running INIT on a project with existing tasks that lack dates, suggest adding `added: YYYY-MM-DD` using today's date as a baseline (the real creation date is unknown, but at least future staleness tracking starts now).

## Archive entry rules

### Enriching entries

The Notes section wants context: why the work was done, what was decided. Two sources, in order:

1. **The journal first**: if `docs/JOURNAL/` has `STANDUP_*` entries covering when these tasks were completed, the context is already written there (delta, decisions, impact). Pull it instead of reconstructing.
2. **Git as fallback**: skim `git log --oneline -20` for related commits and add commit references.

This connects the archive to the project's own memory without duplicating code.

### What does NOT belong in archive entries

- **Code blocks**: code belongs in git. Pasting it creates stale duplicates. Instead: "Modified `auth_service.rs` lines 45-60, added rate limiting to `validate_token()`"
- **Validation scripts or test commands**: those belong in the test suite
- **Full file listings**: keep "Files Changed" to 3-5 paths max with one-line descriptions
