# CI backstop: built (MVP)

The fourth layer (harness / git hooks / preship / **CI**). Built after Claude Code's
`/ship` watch started pushing with git hooks off: from then on, a required CI check is
the only gate that holds for every push.

**What exists**: `.github/workflows/gate.yml` in this repo is a reusable workflow
(`workflow_call`) that checks out the caller and this repo, installs gitleaks, runs an
optional `setup:` command and then `scripts/gate.sh`, the same script behind
`flowkit gate`. `flowkit ci` stamps the 3-line caller (`.github/workflows/flowkit-gate.yml`)
with a setup command detected from the lockfile. This repo's own `ci.yml` calls it too,
so every PR here exercises it on Linux.

**Still open**: the commands still live only in `## preship config` (good, that is the
invariant below), but nothing yet makes the check required automatically; that is a
per-repo setting (Settings -> Rules).

## The invariant it must preserve

Generated FROM the repo's `## preship config` block, the same source the git
hooks read, never hand-written in a separate `ci.yml`. A field report
(29 jul 2026) showed why: a repo whose gate list was duplicated across
`pre-commit` and `ci.yml` drifted, and a `prettier --write` fixer that exits 0
without converging shipped a file CI then rejected. One source both hooks and
CI consume is the only structure that cannot diverge.

## Shape (as designed)

- `flowkit ci` (or an install-time stamp) emits a workflow file for the repo's
  forge (GitHub Actions first) that runs the SAME `lint:` / `typecheck:` /
  `test:` / `build:` declared in `## preship config`, at FULL tree scope.
- Plus gitleaks as the org-wide secret backstop for team repos, the layer the
  local hooks cannot provide (they only protect installers).
- Regenerated, never edited: editing the ci.yml by hand reintroduces the drift.

## Why it matters most for team repos

Local hooks protect only whoever installed them. In henri/skysset the
contributors who never ran `flowkit hooks` are unprotected client-side; CI is
the only gate that applies to everyone who pushes. Priority when Antonio wires
those repos with `--team`.

## Nuance from the same field report: scope which gates by cost AND value

Not every gate belongs at every layer. The reporter measured `format:check`
at 20.5s and correctly withdrew the instinct to add it to pre-commit, but
the sharp version of the lesson is: the cost was dominated by formatting
*generated data* (a 4.5 MB research JSON payload), not source. So the rule
for the generated CI is not "format checks are expensive" but "checking the
format of generated/versioned data payloads is expensive and low-value,
scope those gates to source, let the data pass". Any repo that versions large
data catalogs (research dumps, fixtures, seed JSON) will hit this; the
generated workflow should let `## preship config` express a path scope, not run
every gate over every byte.

## Structural gap this backstop does NOT close on its own

The staged-vs-full-scope asymmetry (documented in README) is real: a local
lint that only sees staged files misses a warning that *propagates* into an
untouched file. CI full-scope catches it, that is the backstop's job. But if
someone wants it caught LOCALLY, the only honest place is a full-tree lint at
**pre-push**, never pre-commit (too slow per commit). The backstop reduces the
blast radius of the asymmetry; it does not erase it.
