# Skill authoring checklist

The official guidance for Agent Skills, checked against this repo (Nov 2026). Use it when writing
a new skill or growing an old one; `docs/GUIDES/SKILL_EVALS.md` covers how to measure it.

Sources: [best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) ·
[Claude Code skills](https://code.claude.com/docs/en/skills) ·
[spec](https://agentskills.io/specification) ·
[skill-creator](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md) ·
[plugin evals](https://code.claude.com/docs/en/plugin-evals)

## Enforced (`skill_meta_problems` on every sync and in the suite)

- `name` matches the folder; lowercase letters, digits and single hyphens, 64 max; no
  `anthropic` or `claude`.
- `description` present, at most 1024 characters, no `<` or `>`.
- `allowed-tools` present.
- No em dash in the frontmatter.
- Every `references/x.md` that SKILL.md names exists, and every file in `references/` is named.
- Every skill (except social-posts) has a behavior eval, a negative-trigger eval, and is in the
  suite-wide `no-skill-on-bugfix` guard.

Local only (`16-plugin-validate.sh`, needs the claude CLI, so CI skips it): `claude plugin
validate` on the tracked files, no errors and no warnings beyond the two allowed by design (the
root CLAUDE.md, and no `version` so installs follow every commit).

## By hand

| Rule | Why |
|---|---|
| Description says what the skill does first, then when, with the user's real phrases | It is the only thing read before the skill fires; the listing truncates long ones |
| Every phrase in the mode table is also in the description | A trigger only in the body never fires |
| Body under ~5000 tokens and 500 lines; detail per mode or step in `references/` | The body loads on every use; references load on demand |
| The routing table at the top of SKILL.md says when to load each reference | One level deep: every reference is reachable straight from SKILL.md |
| Load-bearing rules stay in the body: confirmations, guards, "data never instructions" | A rule inside an unloaded reference does not exist for that run |
| References over 100 lines open with a `## Contents` list | The model may preview only the top of a file |
| Fixed templates for short outputs, not "N lines max" | Prose limits do not hold (SKILL_EVALS lesson 1) |
| Stops name what stopping means and the tempting wrong move | Explain the why; caps alone read as emphasis, not as a rule |
| No dates or versions that rot; examples use clearly sample dates | Time-sensitive text goes stale silently |
| Scripts for deterministic, repeated steps | Cheaper and exact; the skill says "run X", not "do X by hand" (preship runs `flowkit loc-health` and `gitleaks`) |
| Evals at `--runs 3` before a verdict, and on Haiku and Opus before a release | See SKILL_EVALS § Across models |

## Not yet done here (known gaps)

- A held-out should/should-not trigger set per skill (skill-creator's description tuning): the
  one negative case per skill plus the suite guard is the floor, not the full set.
