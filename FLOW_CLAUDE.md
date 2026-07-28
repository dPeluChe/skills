# Flow — session & PR rituals (dPeluChe repos)

- Resuming work → `/kickoff` (resume mode: lightweight delta, not the full audit).
- Closing a session → `/standup` micro (journal entry in `docs/JOURNAL/`).
- Closing a PR cycle → `/ship` (gates + evidence table; merge per repo policy).
- Agents NEVER use `--no-verify` or `LEFTHOOK=0`. If a hook gets in the way,
  report it — bypassing is not an option.
- This repo's commands (lint/typecheck/build/test) live in its own
  `## ship config` block in CLAUDE.md — hooks and `/ship` read them from there.
- Code comments: WHY only, max ~3 lines; logic explanations go to docs/ with a one-line pointer.
