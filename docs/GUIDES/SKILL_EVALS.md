# Skill evals

Every skill except social-posts ships eval cases in `evals/`, run with Claude Code's native
`claude plugin eval`. Each case runs twice: with the plugin and without it. The score that
matters is the **delta**: what Claude does with the skill that it would not do alone.

## Run

```bash
# iterate on one case: one run, no baseline arm (cheap)
claude plugin eval . --case kickoff-resume-light --runs 1 --ablation none \
  --model sonnet --trust-plugin --scaffold --allow-tools Bash Write Edit --no-publish

# one skill, both arms
claude plugin eval . --tag doctos --runs 2 -j 3 \
  --model sonnet --trust-plugin --scaffold --allow-tools Bash Write Edit --no-publish \
  --json evals/results/doctos.json
```

`--scaffold` runs the fixture scripts in `evals/_fixtures/` (ours, so trusted). Results land in
`evals/results/` (git-ignored). Two runs per arm across the whole suite cost about $6 with Sonnet
as the agent and Haiku as the judge.

## Layout

```
evals/
  _fixtures/<repo>.sh          # builds a small repo with planted traps (shared)
  <case>/case.yaml             # name, tags: [<skill>], scaffold_script: fixture.sh
  <case>/fixture.sh            # symlink to ../_fixtures/<repo>.sh
  <case>/prompt.md             # informal prompt, the way the user really types it
  <case>/graders/*.md          # one check per file
  _graders/*.md                # shared checks (skill fired or silent, no edits/moves), symlinked in
```

Tags are a flow list (`tags: [doctos]`, negatives `tags: [doctos, negative]`).

`scripts/tests/15-skills-meta.sh` fails when a skill lacks a behavior case or a negative-trigger
case tagged with its name.

## Designing a case

One case tests one **signature behavior**: something the skill promises that a capable model
might not do on its own. Three kinds per skill:

| Kind | Grader | Note |
|---|---|---|
| Behavior | `llm` rubric, `regex`, `file_exists` | the case that produces a delta |
| Discipline | `tool_used` with `min: 0, max: 0, arm: both` | "never writes / moves / commits / kills" |
| Negative trigger | `tool_used: Skill` with `max: 0, arm: both` | a sibling's phrase must not fire it; delta is 0 by design |

`no-skill-on-bugfix` guards the whole set: a plain code bug must fire none of the skills.
Descriptions compete for the same prompts, so over-triggering is a suite-level risk, not a
per-skill one.

The positive `tool_used: Skill` grader is an indicator, not part of the score: it tells you
whether the description matched the prompt.

## Grader lessons (each one cost a wrong verdict)

1. **Read the replies before trusting a 0 or a 1.** In the first pass, 3 of 9 failures were
   grader bugs, not skill bugs.
2. **Split content from format.** One rubric that checks "covers X and is short" lets the
   judge trade one for the other. Content goes to an `llm` grader, length to a `regex`.
3. **Scope regex to the output, not the explanation.** An editor's "What changed" section
   quotes what it removed. Anchor the pattern before that heading, in both languages
   (`What changed|Qué cambié`).
4. **Grant the tools the skill needs.** A journal case without `Write` measures the harness.

## Skill-writing lessons (apply to every new skill)

1. **Numeric limits in prose do not hold.** "Report in ≤10 lines" produced 24 lines in every
   run. A fixed template with a cap per slot produced 5. Any "report in N lines" rule should
   be a template.
2. **Spell out what a stop means, and name the tempting wrong move.** "HARD STOP, never
   commit" was read as "unstage the secret and commit the rest" in 2 of 2 runs. Adding "do
   not unstage and commit the rest" made it 3 of 3.
3. **Every phrase in the mode table belongs in the description.** "busca los TODO" was in the
   body's mode table but not in the description, so the skill did not fire.
4. **"Never invent" needs its reverse.** The editor never added claims, but it narrowed a
   vague one with an assumption ("revisión" into "revisión de código").
5. **A delta of 0 on a behavior case is a finding.** Skills earn their keep in discipline
   under temptation (no writes before a confirmation, hard stops, the journal) and house
   conventions. Detection a modern model does anyway (stale docs, a stale backlog) shows no
   delta: the skill's value there is format and routing, or the fixture is too easy.

Dated results live in the journal (`docs/JOURNAL/STANDUP_261125.md` has the first full run);
regenerate with `--json evals/results/<name>.json`.
