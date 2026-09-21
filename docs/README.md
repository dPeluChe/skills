# skills: Documentation

> Documentation index and writing rules for this repo.

## Structure

> Derived from [`.doctos.yml`](../.doctos.yml) at the repo root. Edit that file, not this table.

| Folder | Contents |
|--------|----------|
| [`GUIDES/`](./GUIDES/) | How the tooling works and why, for a human reading it on purpose (flowkit, hooks, doctrine) |
| [`FEATURES/`](./FEATURES/) | Design notes on one mechanism, written while it was decided |
| [`JOURNAL/`](./JOURNAL/) | Dated logbook, append-only, born historical (kickoff and standup write it) |
| [`ARCHIVED/`](./ARCHIVED/) | Docs that stopped being current, each with an archival note |
| [`TASK_COMPLETED/`](./TASK_COMPLETED/) | Monthly archive of finished work (managed by pm-tasks) |
| [`TASK_TODO.md`](./TASK_TODO.md) | Pending tasks (managed by pm-tasks) |

## Start here

| If you want | Read |
|---|---|
| To know what each skill does | the [README](../README.md) |
| To use the CLI | [`GUIDES/FLOWKIT.md`](./GUIDES/FLOWKIT.md) |
| To understand what `flowkit hooks` wires into a repo | [`GUIDES/HOOKS.md`](./GUIDES/HOOKS.md) |
| To know why the prose rules are what they are | [`GUIDES/DESLOP_AND_HYGIENE_DOCTRINE.md`](./GUIDES/DESLOP_AND_HYGIENE_DOCTRINE.md) |

## Root-level files

`README.md`, `CLAUDE.md`, `LICENSE`, and `FLOW_CLAUDE.md`. The last one is not documentation
about the repo: it is a payload the installer links into every wired repo's `CLAUDE.md`, which
is why `.doctos.yml` declares it in `root_allowed` instead of moving it here.

## Writing rules

1. **No `.md` at the repo root** beyond the list above
2. **UPPERCASE_SNAKE_CASE** for file names, **UPPERCASE** for folders, `README.md` excepted
3. **No em dashes**, here or anywhere else in the repo. The only files that carry them are
   `writer`'s own, where they are the subject, and the journal, which is a closed record
4. **No task tracking outside `TASK_TODO.md`**: use `/pm-tasks`
5. **No pasted code in docs**: reference file paths and function names
6. **Archive, don't delete**: a doc that stopped being current goes to `ARCHIVED/` with a note
7. **The README is a landing page**, not a manual. Reference belongs in `GUIDES/`
