# Subfolder purposes

Loaded from SKILL.md before classifying stray files (AUDIT) or archiving (CLEAN).

Understanding what goes where prevents misclassification:

## ARCHITECTURE/
Technical architecture, system design, data flow, schema docs, ADRs (Architecture Decision Records), technical decisions, stack choices.

**Examples:** `ARCHITECTURE.md`, `DATABASE_SCHEMA.md`, `API_DESIGN.md`, `DECISIONS.md`, `STACK.md`, `DESIGN_PATTERNS.md`

## FEATURES/
Active feature specs for current or upcoming work. These describe *how something will be built* before it's built. Once the feature ships, the spec moves to `ARCHIVED/` (the implementation is now the source of truth, not the spec).

**Examples:** `26_APRIL_AGENTS.md`, `VOICE_INTEGRATION_SPEC.md`, `PRD_PHASE_2.md`

## GUIDES/
How-to documentation for humans, but only the NON-OBVIOUS kind (see the value-to-reread bar). Setup/deployment/onboarding/conventions that differ from just running the standard commands. A deployment guide earns its place when the deploy has real steps beyond `npm run deploy`; a "how to register a user" guide does not: that is a README line at most. Cut the generic, keep the surprising.

**Examples:** `DEPLOYMENT_GUIDE.md` (when non-trivial), `CODING_RULES.md`, `TESTING.md`, `CSS_CONVENTIONS.md`, each only if it says something the code/commands don't already show.

## RESEARCH/
Investigation, analysis, benchmarks, competitor research, technology evaluations. Content that informed decisions but isn't prescriptive.

**Examples:** `KNOWLEDGE_TOOLS.md`, `COMPETITOR_ANALYSIS.md`, `MODEL_BENCHMARKS.md`, `TECH_EVALUATION.md`

## JOURNAL/
The project's dated logbook: state-in-time reports, append-only, never edited after the fact. `KICKOFF_<YYMMDD>.md` (how the project was found when resuming, written by /kickoff) and `STANDUP_<YYMMDD>.md` (what happened, written by /standup, which may append several timestamped sections to the same day's file as work sessions close). One file per day per type; past days are closed records. Unlike RESEARCH/ (timeless investigations) or ARCHIVED/ (obsolete docs), JOURNAL/ entries are *born historical*: they describe a moment and stay valid as a record of it. Doctos never archives JOURNAL/ files by age; their age is the point.

**Examples:** `KICKOFF_260718.md`, `STANDUP_260725.md`

## ARCHIVED/
Documents that are no longer current but worth keeping for historical context. Every archived file must have an archival note at the top explaining why it was archived and what replaced it.

**Archival note format:**
```markdown
> **ARCHIVED**: 2026-04-05
> This document is no longer current. [Reason: replaced by X / feature shipped / approach changed / no longer relevant].
> Current reference: [link to replacement if any]

---

[original content below unchanged]
```

## TASK_COMPLETED/
Managed exclusively by pm-tasks. Doctos only renames the folder if it uses a non-standard name (`tasks_completed/`, `COMPLETED_TASK/`, etc.) but never touches the content inside.
