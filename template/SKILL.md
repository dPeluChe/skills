---
name: my-skill-name
description: One paragraph saying WHAT this does and WHEN to use it. Include the exact trigger phrases a user would say ("clean up X", "organize Y", "que tareas faltan"). The agent decides whether to load this skill from the description alone — make it earn the trigger.
---

# My Skill Name

One-line summary of the skill's job.

## The standard / convention it enforces

Describe the opinionated structure or process this skill encodes. Show it,
don't describe it — file trees, tables, exact naming rules.

## Modes

| Command | Mode | What it does |
|---------|------|-------------|
| `/my-skill` | Default | ... |
| `/my-skill clean` | Execute | ... |

## Mode: DEFAULT

1. Numbered steps the agent can follow mechanically.
2. Include the exact output format expected (report layout, tables).
3. State when to stop and ask the user vs proceed.

## Boundaries

- What this skill NEVER does (other skills' territory, destructive actions).
- Handoffs: "after X, suggest running /other-skill".

## General principles

- Ask before destructive actions.
- Prefer `git mv` / reversible operations.
- Match the project's language (don't translate content).
