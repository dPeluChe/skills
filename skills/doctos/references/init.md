# INIT mode

Loaded from SKILL.md when running `/doctos init`.

Creates the standard docs structure. Like pm-tasks init, this both creates from scratch and standardizes existing setups.

### Steps

1. **Scan what exists** (same as audit detection)
2. **Branch:**

#### A) Nothing exists: fresh setup

Create the full structure:
```
docs/
├── README.md
├── ARCHITECTURE/
├── FEATURES/
├── GUIDES/
├── RESEARCH/
└── ARCHIVED/
```

Only create subfolders that the project likely needs. A small utility doesn't need `RESEARCH/`. Detect project size/type from:
- Number of source files
- package.json / Cargo.toml dependencies
- Existing documentation volume

Minimum for any project: `docs/README.md` + `docs/GUIDES/`

#### B) Existing non-standard setup: standardize

Same as CLEAN mode but more aggressive:
- Run the full audit
- Show the migration plan
- Execute after confirmation
- Create any missing standard folders

3. **Write `.doctos.yml`** with the default values (or the structure agreed for this repo), so the layout is declared, versioned and visible in diffs instead of living only inside this skill.

3b. **Add the Documentation block to the root `README.md`** (two lines pointing at `.doctos.yml`
and `docs/README.md`, see `references/doctos-yml.md`), so a contributor finds the convention
without knowing the skill exists. Skip it if an equivalent pointer is already there.

4. **Write docs/README.md** with documentation index and writing rules, using the **INIT docs/README.md template** in `references/report-templates.md` (structure table, root-level files, and the seven writing rules). For a content repo, adapt it per the note there.

5. **If task structure is missing**, suggest: "No task tracking found. Run `/pm-tasks init` to set up TASK_TODO.md and TASK_COMPLETED/."
