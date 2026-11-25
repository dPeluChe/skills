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
