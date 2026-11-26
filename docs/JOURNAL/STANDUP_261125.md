# Standup 25 nov 2026

## Skill evals: first full run

Every skill except social-posts got eval cases (`evals/`, `claude plugin eval`, with and
without the plugin). Sonnet as agent, Haiku as judge, 2 to 3 runs per arm, about $11 in total
including the reruns. Method and lessons: `docs/GUIDES/SKILL_EVALS.md`.

| Case | With | Without | Δ |
|---|---|---|---|
| preship-env-secret | 1.00 | 0.00 | +1.00 |
| kickoff-resume-light | 1.00 | 0.25 | +0.75 |
| doctos-audit-messy | 1.00 | 0.33 | +0.67 |
| writer-deslop-es | 1.00 | 0.50 | +0.50 |
| standup-micro-journal | 1.00 | 0.50 | +0.50 |
| pm-tasks-audit-protected | 1.00 | 0.67 | +0.33 |
| deploy-doctor-stuck | 1.00 | 0.67 | +0.33 |
| doctos-published-site | 1.00 | 0.88 | +0.13 |
| 6 more behavior cases | 1.00 | 1.00 | 0 |
| 4 negative-trigger cases | 1.00 | 1.00 | 0 by design |

Skill fixes the runs drove:
- kickoff: resume mode ignored "≤10 lines" (24 lines every run); a fixed template gives 5.
- preship: read HARD STOP as "unstage the secret and commit the rest"; now 3 of 3 stop.
- preship and pm-tasks: "haz commit y pr" and "busca los TODO" did not always fire them.
- writer: narrowed a vague claim with an assumption; folded into "never invent".

The 0-delta cases (kickoff cold analysis, pm-tasks archive check, standup weekly, preship lint
gate, writer detect) are things Sonnet already does alone on small fixtures.

## Negative cases for every skill

Added `pm-tasks-not-on-docs`, `writer-not-on-config` ("revisa" on a config file is not prose),
`deploy-doctor-not-on-preship` ("valida lint y build" is preship, not runtime) and
`no-skill-on-bugfix` (a plain bug fires none of the skills). 2 runs each, all 1.00, about $1.
The suite now requires a negative case per skill, not only a behavior case.

## doctos and pm-tasks split into references, official checklist

doctos (445 to 296 lines, ~7.1k to ~5.5k tokens) and pm-tasks (457 to 341, ~7.1k to ~5.6k) moved
per-mode detail into references/; load-bearing rules stayed in the body. Their 7 eval cases pass
after the split (2 runs, then 1 after simplify). skill_meta_problems now fails on a dangling or
orphan reference. The official best practices, checked against the repo, live in
docs/GUIDES/SKILL_AUTHORING.md with the known gaps.

## Across models (Haiku full suite, Opus on the 8 high-delta cases)

| Case | Haiku Δ | Sonnet Δ | Opus Δ |
|---|---|---|---|
| preship-env-secret | +1.00 | +1.00 | 0 (Opus stops alone) |
| pm-tasks-archive-evidence | +1.00 | 0 | not run |
| kickoff-resume-light | +0.50 | +0.75 | +0.50 |
| doctos-audit-messy | +0.67 | +0.67 | +0.33 (rubric widened, see SKILL_EVALS grader lesson 5) |
| writer-deslop-es | +0.17 | +0.50 | +0.67 |
| standup-micro-journal | +0.50 | +0.50 | +0.50 |
| pm-tasks-audit-protected | +0.17 | +0.33 | +0.33 |
| deploy-doctor-stuck | 0 | +0.33 | 0 |
| doctos-published-site | +0.25 | +0.13 | 0 |

Haiku 2 runs per arm, Opus 1: the Opus column is a direction, not a verdict. The discipline
skills (journal, protected zones, the writer's rules) hold on all three. The hard stops matter
most on smaller models: Opus already refuses to commit a secret without preship. On Haiku,
pm-tasks did not fire on "que hay pendiente en este proyecto?" in 1 of 2 runs, which is input for
a held-out trigger set. Remaining Haiku misses were split judge votes on replies that met the
rubric. Cost: Haiku $0.47, Opus about $2.90, preship re-run after the gitleaks/loc-health
change $0.52 (3/3 cases pass).
