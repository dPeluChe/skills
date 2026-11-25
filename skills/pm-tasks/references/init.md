# INIT mode

Loaded from SKILL.md when running `/pm-tasks init`.

## Steps

1. **Scan the project** for existing task infrastructure (same detection as Step 0)
2. **Branch based on what's found**:

### A) Nothing exists: fresh setup

- Create `docs/` directory
- Create `docs/TASK_TODO.md` from template (detect project name from package.json, Cargo.toml, or directory)
- Create `docs/TASK_COMPLETED/` with `README.md`
- Report what was created

### B) Non-standard setup found: standardize

Show the user a migration plan before doing anything, grouped into Files to move/rename, Files to create, Files to consolidate, and Content updates, ending in "Proceed? (y/n)". Full example: `references/report-formats.md` § Standardization plan example.

After confirmation:
- Use `git mv` where possible to preserve history
- Rename monthly files to `YYMM.md` format
- Consolidate scattered task files
- Add README.md to TASK_COMPLETED/ if missing
- Update cross-references in TASK_TODO.md header
- Clean up code blocks in existing archive files (replace with file/function references)

### C) Already standard: validate

- Confirm structure is correct
- Check for minor issues (missing README.md, stale completed tasks)
- Report "all good" or list minor fixes
