# External trackers: keeping the doc and the tracker honest

Load this when the project ALSO tracks work outside `TASK_TODO.md`: a SaaS tracker, a
self-hosted one, or GitHub Issues. Most repos have none, and then `TASK_TODO.md` is simply the
source of truth and nothing here applies.

## Detecting one

Do not assume. A tracker is in play when one of these is true:

- Tracker tools are exposed to the session (an MCP server, a CLI on PATH, `gh` with issues enabled)
- The repo references one (a link in the README, issue templates under `.github/`, a config file)
- The user says so

If the signals are ambiguous, **ask once** and remember the answer for the session. Guessing
wrong in either direction is expensive: inventing a sync that nobody wanted, or silently
letting two backlogs drift.

## The rule: one source of truth, two surfaces

The doc stays the source of truth for **project tasks**; the tracker is where the rest of the
team, the client or the issue reporter sees them. Neither is allowed to quietly disagree with
the other.

- **AUDIT cross-check.** Pull the project's open items from the tracker and compare against
  `TASK_TODO.md` **both ways**. Report "in the tracker but not in the doc" and "in the doc but
  not in the tracker" as findings. **Never auto-create on either side without confirmation**:
  the two lists differ for real reasons (a task that is not the team's, an issue filed by a
  stranger), and mass-syncing them is how a backlog becomes noise.
- **Duplicate detection on create.** In any mode that writes a new task, check for
  near-duplicates by title and topic in BOTH places before adding. If a likely match exists,
  show it and ask merge or create. This is the one rule worth applying even when the tracker
  itself does not enforce it.

## What this looks like per tracker

The duties above do not change; only the command does.

| Tracker | Listing open items |
|---|---|
| GitHub Issues | `gh issue list --state open --json number,title` |
| An MCP-exposed tracker (Tasky, Linear, Jira, and the like) | its own list tool, scoped to the project |
| A CLI-exposed tracker | its list command, scoped to the project |

When a tracker is exposed through MCP tools, prefer them over scraping a web UI. When several
are available, ask which one governs this repo rather than syncing against all of them.

## What does NOT belong here

- **Process activities** (see the skill body): an errand is not an issue, and pushing one into
  a tracker turns the team's board into a personal to-do list.
- **Completed work.** The archive lives in `TASK_COMPLETED/YYMM.md`. Closing the tracker item
  is the tracker's business; the monthly file answers "what was built", and it is written from
  the doc, not from the tracker's closed list.
