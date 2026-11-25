# CLEAN mode

Loaded from SKILL.md when running `/doctos clean` (or INIT standardizing an existing setup).

Executes all fixes identified in the audit.

### Steps

1. **Run audit first**: build the full list of issues
1b. **Freshness verdict per file being moved.** Structure and content rot together: a file worth relocating is a file worth 30 seconds of scrutiny, and moving a stale doc to a tidy folder just gives the lie a better address. For every file in the move plan, check `git log -1 --format=%as -- <file>` and spot-check its boldest claim against the codebase. Attach a verdict to each plan line: ✅ vigente · 🟡 revisar (old but spot-check passed: add a review task) · 🔴 deprecated (contradicts reality: goes to ARCHIVED/ with note instead of its planned destination, plus a task to replace it). Real case that motivated this: a `project_definition.md` moved during a cleanup turned out to describe a *different project entirely* (copied from another repo, never adapted). Structure-only cleaning would have promoted it to ARCHITECTURE/.
2. **Show the execution plan** to the user and ask for confirmation, using the **CLEAN plan format** in `references/report-templates.md` (grouped into Will move / Will rename / Will rename task-related / Will create / Will archive, ending in "Proceed? (y/n)").

3. **After confirmation, execute:**
   - Use `git mv` where possible to preserve history
   - Create missing folders
   - Rename files/folders to standard convention
   - Add archival notes to files moved to ARCHIVED/ (format in `references/subfolders.md`)
   - Convert .txt files to .md
   - Rename hyphens to underscores in file names (`DEV-WORKFLOW.md` → `DEV_WORKFLOW.md`)
   - **Repair inbound references**: after every move or rename, search the whole project for the old path/filename (other docs, CLAUDE.md pointers, code comments) and update each reference to the new location. Moving a file without fixing its inbound links converts organization into breakage: this step is what makes the clean safe
   - Create docs/README.md with documentation index and writing rules
   - If task-related files were renamed, remind user: "Task folders renamed. Run `/pm-tasks` to audit task content."

4. **Post-clean report:** use the **CLEAN post-clean report format** in `references/report-templates.md` (counts of moved / renamed / created / archived, plus the pm-tasks reminder).

### Handling edge cases

**File name conflicts:** If moving `ARCHITECTURE.md` from root to `docs/ARCHITECTURE/` but `docs/ARCHITECTURE/ARCHITECTURE.md` already exists: ask the user whether to merge, rename, or skip.

**Published docs sites:** the guard is defined once, in SKILL.md AUDIT step 1a; when it fired, no move or rename under `docs/`.

**Non-markdown files in docs/:** Shell scripts (`.sh`), config files, images: these are fine. Only audit `.md` and `.txt` files.

**Nested project structures:** For workspaces with sub-projects (e.g., a monorepo with `backend_api/` and `browser_extension/`), audit each sub-project independently. Don't move sub-project docs to the workspace root.
