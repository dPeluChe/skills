---
name: standup
description: >
  Generate a progress report for a project over a recent time window (last week by default):
  what shipped, what's in progress, new pendings, and what's next — in human language, not raw
  commit messages. Use this skill whenever the user wants to review or communicate recent progress:
  "qué avanzamos esta semana", "standup", "resumen de cambios", "reporta avances", "what changed
  since Monday", "update de los últimos días", "genera el update para el cliente", "qué se hizo
  en este proyecto últimamente". Also trigger when the user needs a status update to send to a
  client, team, or stakeholder, even if they don't say "standup".
---

# Standup — Recent Progress Report

Answers "what happened here lately?" for one project: shipped work, work in flight, new pendings, and next steps — written for a human reader, not as a git log dump. Read-only.

## Why this exists

Progress lives scattered across commits, merged PRs, task archives, and memory. Assembling it by hand takes long enough that reports don't get written — and unwritten progress is invisible to clients, teammates, and future-you. Standup makes the report cheap.

## Step 1: Determine the window

- Default: **last 7 days** (`--since="7 days ago"`)
- User can say "since Monday", "last 2 weeks", "since v2.1", "desde el último standup" — translate to a git date or ref
- If the project has `docs/TASK_COMPLETED/`, the current month's file helps anchor what counted as "done"

## Step 2: Gather the evidence

```bash
git log --since="<window>" --oneline --stat=120,90 # commits + touched areas
gh pr list --state merged --search "merged:><date>" # merged PRs (if gh available)
gh pr list --state open                             # in-flight work
git branch --no-merged                              # unfinished branches
```

Also check within the window:
- `docs/TASK_COMPLETED/YYMM.md` — tasks archived (the curated "done" list)
- `docs/TASK_TODO.md` — tasks added (new pendings) via `git log -p --since`
- `CHANGELOG.md` — released versions

**If [trs](https://usetrs.dev) is installed**, `trs ingest --since <ref>` produces a digest of exactly the files that changed — the fastest way to understand *what the commits actually did* beyond their messages. With trs ≥0.7, `trs ingest --since-last` diffs against the stored HEAD from the previous ingest — the natural "since the last standup" window when the user doesn't specify one. Recommend `npm install -g @dpeluche/trs` once if absent, then proceed without it.

## Step 3: Translate commits into outcomes

The core editorial move: group commits by **outcome**, not chronology, and write them as results a non-author understands.

- `feat(decks): add Puck editor` + `fix(decks): save flow` + `refactor(decks): share config` → **"Decks editor: shipped the slide editor with working save and share"**
- Don't list every commit — a reader wants the 3-7 things that MATTER
- Distinguish shipped (merged/deployed) from in-progress (open PR, unmerged branch)
- If commit messages are cryptic and trs is available, use the `--since` digest to see what actually changed

## Step 4: The Standup Report

ALWAYS use this structure:

```markdown
# Standup — [Project] · [window]

**TL;DR**: 2-3 lines max. What a busy reader needs to know.

## Shipped
- Outcome-level bullets (grouped by feature/area, not by commit)

## In progress
- Open PRs, active branches, half-done work — with a one-line status each

## New pendings
- Tasks added to the backlog this window (or found as new TODOs)

## Risks / blockers
- Only if evidence supports them (failing CI, stale PR waiting on review, dependency issues)

## Next
- Top 2-3 items from TASK_TODO.md priorities, or the natural continuation of in-progress work
```

## Audience variants

Ask (or infer from the request) who the report is for:

- **Internal** (default): technical vocabulary fine, file/PR references welcome
- **Client-facing** ("para el cliente", "for the stakeholder update"): outcomes and value only — no file paths, no jargon, no internal task keys. Write it ready to paste into an email or chat. Match the client's language.

## Boundaries

- **Read-only.** Standup reports; it never archives tasks or edits the backlog. If it finds completed tasks sitting unarchived in TASK_TODO.md, it notes: "run `/pm-tasks archive` to file these".
- **One project per report.** For a multi-project digest, run it per project and combine.
- **Pairs with kickoff.** Kickoff = full state when starting; standup = delta over a window. Don't duplicate kickoff's reality-check — if docs look stale, one pointer to `/kickoff` or `/doctos` is enough.

## General principles

- **Outcomes over activity.** "Shipped the decks editor" beats 9 commit messages. The report's value is the translation.
- **Evidence-based.** Every claim traces to a commit, PR, or archive entry. No padding, no invented progress — if the window was quiet, say so plainly; a honest "maintenance week" builds more trust than inflated bullets.
- **Cheap enough to be weekly.** Keep the report short enough that generating and reading it stays a 2-minute habit.
- **Match the language** of the user (and the client, for client-facing variants).
