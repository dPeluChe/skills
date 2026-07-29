# CI backstop — planned

The one layer of the 4 (harness / git hooks / ship / **CI**) flowkit does not
wire yet. Status: designed, not built. Deferred by decision, not oversight.

## The invariant it must preserve

Generated FROM the repo's `## ship config` block — the same source the git
hooks read — never hand-written in a separate `ci.yml`. A field report
(29 jul 2026) showed why: a repo whose gate list was duplicated across
`pre-commit` and `ci.yml` drifted, and a `prettier --write` fixer that exits 0
without converging shipped a file CI then rejected. One source both hooks and
CI consume is the only structure that cannot diverge.

## Shape (when it lands)

- `flowkit ci` (or an install-time stamp) emits a workflow file for the repo's
  forge (GitHub Actions first) that runs the SAME `lint:` / `typecheck:` /
  `test:` / `build:` declared in `## ship config`, at FULL tree scope.
- Plus gitleaks as the org-wide secret backstop for team repos — the layer the
  local hooks cannot provide (they only protect installers).
- Regenerated, never edited: editing the ci.yml by hand reintroduces the drift.

## Why it matters most for team repos

Local hooks protect only whoever installed them. In henri/skysset the
contributors who never ran `flowkit hooks` are unprotected client-side; CI is
the only gate that applies to everyone who pushes. Priority when Antonio wires
those repos with `--team`.
